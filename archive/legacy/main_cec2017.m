clc
clear
close all

root=fileparts(mfilename('fullpath'));
cecRoot=fullfile(root,'data','cec2017');
addpath(root)
addpath(cecRoot)
cd(cecRoot)

% 正式比较算法；DSS-RLCSO 的模式感知 Q-learning 已冻结。
algorithms={'PSO_CEC','CSO_CEC','CLPSO_CEC','GWO_CEC','SCSO_CEC','DSS_RLCSO_CEC'};
algorithmNames={'PSO','CSO','CLPSO','GWO','SCSO','DSS-RLCSO'};
populationSizes=[50 50 50 50 50 50];
functionIDs=[1 3:30];
D=30;
maxEvaluations=10000*D;
developmentMode=true;
if developmentMode
    repeatIDs=1:3;
else
    repeatIDs=101:130;
end
seedBase=20271004;
searchSeedOffset=100000;
lowerBound=-100*ones(1,D);
upperBound=100*ones(1,D);

if exist('cec17_func','file')~=3
    error('Compile data/cec2017/cec17_func.cpp with mex before running.');
end

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_' stamp]);
historyDir=fullfile(resultDir,'histories');
if ~exist(resultDir,'dir'),mkdir(resultDir);end
if ~exist(historyDir,'dir'),mkdir(historyDir);end
checkpointFile=fullfile(resultDir,'cec2017_checkpoint.mat');
checkpointCsv=fullfile(resultDir,'raw_runs_checkpoint.csv');

records=cell(numel(functionIDs)*numel(repeatIDs)*numel(algorithms),1);
count=0;
for functionID=functionIDs
    functionName=sprintf('F%02d',functionID);
    f=@(x)CEC2017Function(x,functionID);
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        searchSeed=initSeed+searchSeedOffset;
        maxPopulation=max(populationSizes);
        rng(initSeed)
        initialPool=lowerBound+rand(maxPopulation,D).*(upperBound-lowerBound);
        for k=1:numel(algorithms)
            state=struct('lowerBound',lowerBound,'upperBound',upperBound, ...
                'maxEvaluations',maxEvaluations,'rlMode','modeAware', ...
                'initialPopulation',initialPool(1:populationSizes(k),:));
            [Best,T,info]=feval(algorithms{k},f,state, ...
                ceil(maxEvaluations/populationSizes(k)),populationSizes(k),searchSeed);
            assert(info.Evaluations==maxEvaluations)
            assert(numel(T)==maxEvaluations && all(isfinite(T)))
            assert(isequal(info.InitialPopulation,state.initialPopulation))
            assert(isfinite(Best.Cost) && all(Best.Vector>=lowerBound) && ...
                all(Best.Vector<=upperBound))
            count=count+1;
            runRecord=struct('Function',functionName,'FunctionID',functionID, ...
                'Dimension',D,'Algorithm',algorithmNames{k},'Run',repeat, ...
                'InitSeed',initSeed,'SearchSeed',searchSeed, ...
                'Population',populationSizes(k),'Evaluations',info.Evaluations, ...
                'BestCost',Best.Cost,'BestError',max(0,Best.Cost-100*functionID), ...
                'Seconds',info.Seconds,'FirstImprovementFE', ...
                info.FirstImprovementEvaluation);
            records{count}=runRecord;
            historyFile=fullfile(historyDir,sprintf('%s_%s_r%03d.mat', ...
                functionName,algorithmNames{k},repeat));
            save(historyFile,'T','Best','info','runRecord','-v7.3');
            fprintf('%s %s r%02d cost=%.6g time=%.3fs\n', ...
                functionName,algorithmNames{k},repeat,Best.Cost,info.Seconds);
            rawRuns=struct2table([records{1:count}]);
            writetable(rawRuns,checkpointCsv);
            completedRuns=count;
            save(checkpointFile,'rawRuns','completedRuns','D', ...
                'populationSizes','maxEvaluations','repeatIDs','functionIDs', ...
                'seedBase','searchSeedOffset','developmentMode','algorithmNames');
        end
    end
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));

summaryRecords={};
count=0;
for functionID=functionIDs
    functionName=sprintf('F%02d',functionID);
    for k=1:numel(algorithmNames)
        rows=rawRuns(strcmp(rawRuns.Function,functionName) & ...
            strcmp(rawRuns.Algorithm,algorithmNames{k}),:);
        count=count+1;
        summaryRecords{count}=struct('Function',functionName, ...
            'FunctionID',functionID,'Algorithm',algorithmNames{k}, ...
            'Runs',height(rows),'MeanBestCost',mean(rows.BestCost), ...
            'MeanBestError',mean(rows.BestError),'StdBestError',std(rows.BestError), ...
            'StdBestCost',std(rows.BestCost),'MeanSeconds',mean(rows.Seconds), ...
            'MeanFirstImprovementFE',mean(rows.FirstImprovementFE,'omitnan'));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
save(fullfile(resultDir,'cec2017_results.mat'),'rawRuns','summary','D', ...
    'populationSizes','maxEvaluations','repeatIDs','functionIDs','seedBase', ...
    'searchSeedOffset','developmentMode','algorithmNames');
fprintf('Saved CEC2017 results to %s\n',resultDir);

