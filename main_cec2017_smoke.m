clc
clear
close all

root=fileparts(mfilename('fullpath'));
cecRoot=fullfile(root,'data','cec2017');
addpath(root)
addpath(cecRoot)
cd(cecRoot)

algorithms={'PSO_CEC','CSO_CEC','CLPSO_CEC','LSHADE_CEC','DSS_RLCSO_CEC'};
algorithmNames={'PSO','CSO','CLPSO','L-SHADE','DSS-RLCSO'};
populationSizes=[50 50 50 18*30 50];
functionIDs=[3 13 30];
D=30;
maxEvaluations=30000;
repeatIDs=1:5;
seedBase=20271004;
searchSeedOffset=100000;
lowerBound=-100*ones(1,D);
upperBound=100*ones(1,D);
if exist('cec17_func','file')~=3
    error('Compile data/cec2017/cec17_func.cpp with mex before running.');
end

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_smoke_' stamp]);
historyDir=fullfile(resultDir,'histories');
mkdir(resultDir); mkdir(historyDir);
records=cell(numel(functionIDs)*numel(repeatIDs)*numel(algorithms),1);
count=0;
for functionID=functionIDs
    f=@(x)CEC2017Function(x,functionID);
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        searchSeed=initSeed+searchSeedOffset;
        rng(initSeed)
        initialPool=lowerBound+rand(max(populationSizes),D).*(upperBound-lowerBound);
        for k=1:numel(algorithms)
            state=struct('lowerBound',lowerBound,'upperBound',upperBound, ...
                'maxEvaluations',maxEvaluations,'rlMode','modeAware', ...
                'initialPopulation',initialPool(1:populationSizes(k),:));
            [Best,T,info]=feval(algorithms{k},f,state, ...
                ceil(maxEvaluations/populationSizes(k)),populationSizes(k),searchSeed);
            assert(info.Evaluations==maxEvaluations)
            assert(numel(T)==maxEvaluations && all(isfinite(T)))
            assert(isequal(info.InitialPopulation,state.initialPopulation))
            assert(all(Best.Vector>=lowerBound) && all(Best.Vector<=upperBound))
            count=count+1;
            records{count}=struct('Function',sprintf('F%02d',functionID), ...
                'FunctionID',functionID,'Algorithm',algorithmNames{k}, ...
                'Run',repeat,'Population',populationSizes(k), ...
                'BestCost',Best.Cost,'BestError',max(0,Best.Cost-100*functionID), ...
                'Evaluations',info.Evaluations,'Seconds',info.Seconds);
            save(fullfile(historyDir,sprintf('F%02d_%s_r%03d.mat', ...
                functionID,algorithmNames{k},repeat)),'T','Best','info','-v7.3');
            fprintf('F%02d %s r%02d cost=%.6g FE=%d\n',functionID, ...
                algorithmNames{k},repeat,Best.Cost,info.Evaluations);
        end
    end
end
rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
save(fullfile(resultDir,'smoke_results.mat'),'rawRuns','functionIDs','repeatIDs', ...
    'populationSizes','maxEvaluations','algorithmNames');
fprintf('Saved smoke results to %s\n',resultDir);
