clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root)
algorithms={'PSO_CEC','CSO_CEC','DSS_RLCSO'};
functionIDs=1:6;
D=30;
population=50;
maxEvaluations=10000;
repeatIDs=1:3;
seedBase=20271004;
searchSeedOffset=100000;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['development_' stamp]);
if ~exist(resultDir,'dir'),mkdir(resultDir);end

records=cell(numel(functionIDs)*numel(repeatIDs)*numel(algorithms),1);
count=0;
for functionID=functionIDs
    [f,lb,ub,functionName]=CECFunctions(functionID,D);
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        searchSeed=initSeed+searchSeedOffset;
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations);
        rng(initSeed)
        state.initialPopulation=lb+rand(population,D).*(ub-lb);
        for k=1:numel(algorithms)
            [Best,T,info]=feval(algorithms{k},f,state, ...
                ceil(maxEvaluations/population),population,searchSeed);
            assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
            assert(isequal(info.InitialPopulation,state.initialPopulation));
            assert(isfinite(Best.Cost));
            count=count+1;
            records{count}=struct('Function',functionName,'Dimension',D, ...
                'Algorithm',algorithms{k},'Run',repeat,'InitSeed',initSeed, ...
                'SearchSeed',searchSeed,'Evaluations',info.Evaluations, ...
                'BestCost',Best.Cost,'Seconds',info.Seconds, ...
                'FirstImprovementFE',info.FirstImprovementEvaluation);
            fprintf('%s %s r%d cost=%.6g time=%.3fs\n', ...
                functionName,algorithms{k},repeat,Best.Cost,info.Seconds);
        end
    end
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
save(fullfile(resultDir,'cec_development.mat'),'rawRuns','D','population', ...
    'maxEvaluations','repeatIDs','functionIDs','seedBase','searchSeedOffset');
fprintf('Saved CEC results to %s\n',resultDir);
