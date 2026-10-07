clc
clear
close all

root=fileparts(mfilename('fullpath'));
cecRoot=fullfile(root,'data','cec2017');
addpath(root)
addpath(cecRoot)
cd(cecRoot)

algorithms={'PSO_CEC','CSO_CEC','DSS_MAQLCSO'};
algorithmNames={'PSO','CSO','DSS-RLCSO'};
functionIDs=[1 3:30];
D=30;
population=50;
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
if ~exist(resultDir,'dir'),mkdir(resultDir);end
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
        state=struct('lowerBound',lowerBound,'upperBound',upperBound, ...
            'maxEvaluations',maxEvaluations,'rlMode','modeAware');
        rng(initSeed)
        state.initialPopulation=lowerBound+rand(population,D).* ...
            (upperBound-lowerBound);
        for k=1:numel(algorithms)
            [Best,T,info]=feval(algorithms{k},f,state, ...
                ceil(maxEvaluations/population),population,searchSeed);
            assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
            assert(isequal(info.InitialPopulation,state.initialPopulation));
            assert(isfinite(Best.Cost));
            count=count+1;
            records{count}=struct('Function',functionName,'FunctionID',functionID, ...
                'Dimension',D,'Algorithm',algorithmNames{k},'Run',repeat, ...
                'InitSeed',initSeed,'SearchSeed',searchSeed, ...
                'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
                'BestError',max(0,Best.Cost-100*functionID), ...
                'Seconds',info.Seconds,'FirstImprovementFE', ...
                info.FirstImprovementEvaluation);
            fprintf('%s %s r%02d cost=%.6g time=%.3fs\n', ...
                functionName,algorithmNames{k},repeat,Best.Cost,info.Seconds);
            rawRuns=struct2table([records{1:count}]);
            writetable(rawRuns,checkpointCsv);
            completedRuns=count;
            save(checkpointFile,'rawRuns','completedRuns','D','population', ...
                'maxEvaluations','repeatIDs','functionIDs','seedBase', ...
                'searchSeedOffset','developmentMode');
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
    'population','maxEvaluations','repeatIDs','functionIDs','seedBase', ...
    'searchSeedOffset','developmentMode');
fprintf('Saved CEC2017 results to %s\n',resultDir);
