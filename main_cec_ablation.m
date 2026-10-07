clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root)
variantNames={'CSO','SS-CSO','DSS-CSO','DSS-RLCSO'};
functionIDs=1:6;
D=30;
population=50;
maxEvaluations=10000;
repeatIDs=1:10;
seedBase=20271004;
searchSeedOffset=100000;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['ablation_' stamp]);
if ~exist(resultDir,'dir'),mkdir(resultDir);end

records=cell(numel(functionIDs)*numel(repeatIDs)*numel(variantNames),1);
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
        for k=1:numel(variantNames)
            if k==1
                algorithm='CSO_CEC';
            else
                algorithm='DSS_RLCSO';
                state.ablation=struct('useCatScreen',k>1, ...
                    'useCandidateScreen',k>2,'useRL',k>3);
            end
            [Best,T,info]=feval(algorithm,f,state, ...
                ceil(maxEvaluations/population),population,searchSeed);
            assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
            assert(isequal(info.InitialPopulation,state.initialPopulation));
            assert(isfinite(Best.Cost));
            count=count+1;
            if isfield(info,'ActionCounts')
                actions=info.ActionCounts;
                meanSelected=mean(info.SelectedCatCounts);
                seekEvaluations=info.SeekingEvaluations;
                traceEvaluations=info.TracingEvaluations;
            else
                actions=nan(1,4);
                meanSelected=NaN;
                seekEvaluations=NaN;
                traceEvaluations=NaN;
            end
            records{count}=struct('Function',functionName,'Dimension',D, ...
                'Algorithm',variantNames{k},'Run',repeat,'InitSeed',initSeed, ...
                'SearchSeed',searchSeed,'Evaluations',info.Evaluations, ...
                'BestCost',Best.Cost,'Seconds',info.Seconds, ...
                'FirstImprovementFE',info.FirstImprovementEvaluation, ...
                'Action1',actions(1),'Action2',actions(2), ...
                'Action3',actions(3),'Action4',actions(4), ...
                'MeanSelectedCats',meanSelected,'SeekingEvaluations',seekEvaluations, ...
                'TracingEvaluations',traceEvaluations);
            fprintf('%s %s r%02d cost=%.6g time=%.3fs\n', ...
                functionName,variantNames{k},repeat,Best.Cost,info.Seconds);
        end
    end
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));

summaryRecords={};
count=0;
for functionID=functionIDs
    [~,~,~,functionName]=CECFunctions(functionID,D);
    for k=1:numel(variantNames)
        rows=rawRuns(strcmp(rawRuns.Function,functionName) & ...
            strcmp(rawRuns.Algorithm,variantNames{k}),:);
        count=count+1;
        summaryRecords{count}=struct('Function',functionName, ...
            'Algorithm',variantNames{k},'Runs',height(rows), ...
            'MeanBestCost',mean(rows.BestCost),'StdBestCost',std(rows.BestCost), ...
            'MeanSeconds',mean(rows.Seconds), ...
            'MeanFirstImprovementFE',mean(rows.FirstImprovementFE,'omitnan'));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
save(fullfile(resultDir,'ablation_results.mat'),'rawRuns','summary','D', ...
    'population','maxEvaluations','repeatIDs','functionIDs','seedBase', ...
    'searchSeedOffset');
fprintf('Saved CEC ablation results to %s\n',resultDir);
