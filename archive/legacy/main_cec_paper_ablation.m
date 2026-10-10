clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root)
variantNames={'Legacy-RLCSO','Paper-RLCSO','Paper-Random-CSO','Paper-Fixed-A3'};
actionModes={'qlearning','qlearning','random','fixed3'};
rlModes={'legacy','paper','paper','paper'};
useRL=[true true false false];
functionIDs=1:6;
D=30;
population=50;
maxEvaluations=10000;
repeatIDs=1:10;
seedBase=20271004;
searchSeedOffset=100000;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['paper_ablation_' stamp]);
if ~exist(resultDir,'dir'),mkdir(resultDir);end

records=cell(numel(functionIDs)*numel(repeatIDs)*numel(variantNames),1);
count=0;
for functionID=functionIDs
    [f,lb,ub,functionName]=CECFunctions(functionID,D);
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        searchSeed=initSeed+searchSeedOffset;
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'actionMode','qlearning', ...
            'rlMode','legacy','ablation',struct('useCatScreen',true, ...
            'useCandidateScreen',true,'useRL',true));
        rng(initSeed)
        state.initialPopulation=lb+rand(population,D).*(ub-lb);
        for k=1:numel(variantNames)
            state.actionMode=actionModes{k};
            state.rlMode=rlModes{k};
            state.ablation.useRL=useRL(k);
            [Best,T,info]=DSS_RLCSO(f,state, ...
                ceil(maxEvaluations/population),population,searchSeed);
            assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
            assert(isequal(info.InitialPopulation,state.initialPopulation));
            assert(isfinite(Best.Cost));
            count=count+1;
            records{count}=struct('Function',functionName,'Dimension',D, ...
                'Algorithm',variantNames{k},'ActionMode',actionModes{k}, ...
                'RLMode',rlModes{k},'Run',repeat,'InitSeed',initSeed, ...
                'SearchSeed',searchSeed,'Evaluations',info.Evaluations, ...
                'BestCost',Best.Cost,'Seconds',info.Seconds, ...
                'FirstImprovementFE',info.FirstImprovementEvaluation, ...
                'Action1',info.ActionCounts(1),'Action2',info.ActionCounts(2), ...
                'Action3',info.ActionCounts(3),'Action4',info.ActionCounts(4), ...
                'MeanReward',mean(info.RewardHistory), ...
                'QStateCount',info.QStateCount);
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
        totalActions=rows.Action1+rows.Action2+rows.Action3+rows.Action4;
        count=count+1;
        summaryRecords{count}=struct('Function',functionName, ...
            'Algorithm',variantNames{k},'Runs',height(rows), ...
            'MeanBestCost',mean(rows.BestCost),'StdBestCost',std(rows.BestCost), ...
            'MeanSeconds',mean(rows.Seconds), ...
            'MeanFirstImprovementFE',mean(rows.FirstImprovementFE,'omitnan'), ...
            'MeanAction1Share',mean(rows.Action1./totalActions), ...
            'MeanAction2Share',mean(rows.Action2./totalActions), ...
            'MeanAction3Share',mean(rows.Action3./totalActions), ...
            'MeanAction4Share',mean(rows.Action4./totalActions), ...
            'MeanReward',mean(rows.MeanReward));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
save(fullfile(resultDir,'paper_ablation_results.mat'),'rawRuns','summary','D', ...
    'population','maxEvaluations','repeatIDs','functionIDs','seedBase', ...
    'searchSeedOffset');
fprintf('Saved CEC paper-style ablation results to %s\n',resultDir);
