clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[3 5 10 13 15 19 25 28 30];
D=30;
population=50;
maxEvaluations=10000*D;
repeatIDs=1:3;
seedBase=20271004;
searchSeedOffset=100000;
lb=-100*ones(1,D);
ub=100*ones(1,D);
variants={'Q-learning','Random','Fixed-A1','Fixed-A2','Fixed-A3','Fixed-A4'};
actionModes={'qlearning','random','fixed1','fixed2','fixed3','fixed4'};
useRL=[true false false false false false];

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_action_parallel_' stamp]);
historyDir=fullfile(resultDir,'histories');
mkdir(resultDir); mkdir(historyDir);

jobs=struct('FunctionID',{},'Run',{},'Variant',{},'ActionMode',{}, ...
    'UseRL',{},'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed)
        initialPopulation=lb+rand(population,D).*(ub-lb);
        for k=1:numel(variants)
            count=count+1;
            jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
                'Variant',variants{k},'ActionMode',actionModes{k}, ...
                'UseRL',useRL(k),'InitSeed',initSeed, ...
                'SearchSeed',initSeed+searchSeedOffset, ...
                'InitialPopulation',initialPopulation);
        end
    end
end

workerCount=4;
pool=gcp('nocreate');
if isempty(pool)
    parpool('local',workerCount);
elseif pool.NumWorkers~=workerCount
    delete(pool);
    parpool('local',workerCount);
end

records=cell(numel(jobs),1);
batchSize=18;
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        f=@(x)CEC2017Function(x,job.FunctionID);
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations, ...
            'initialPopulation',job.InitialPopulation, ...
            'actionMode',job.ActionMode,'rlMode','modeAwareV3', ...
            'modeSampleV3',true,'opportunityScreen',true, ...
            'ablation',struct('useCatScreen',true, ...
            'useCandidateScreen',true,'useRL',job.UseRL));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations)
        generated=mean(info.GeneratedTracingCatShare);
        selected=mean(info.SelectedTracingCatShare);
        record=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm',job.Variant, ...
            'Run',job.Run,'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-100*job.FunctionID), ...
            'Seconds',info.Seconds,'GeneratedTracingCatShare',generated, ...
            'SelectedTracingCatShare',selected,'TracingSelectionRatio', ...
            selected/max(generated,eps),'TracingFEShare', ...
            info.TracingEvaluations/max(1,info.Evaluations-population), ...
            'TraceFreeRoundRate',mean(info.TracingEvaluationsPerRound==0), ...
            'BalancedModeRate',mean(info.ModeStateHistory==2), ...
            'Action1Share',info.ActionCounts(1)/sum(info.ActionCounts), ...
            'Action2Share',info.ActionCounts(2)/sum(info.ActionCounts), ...
            'Action3Share',info.ActionCounts(3)/sum(info.ActionCounts), ...
            'Action4Share',info.ActionCounts(4)/sum(info.ActionCounts));
        batchResults{j}=struct('Best',Best,'T',T,'info',info,'record',record);
    end
    batchRecords=cell(numel(batch),1);
    for j=1:numel(batch)
        job=batch(j);
        result=batchResults{j};
        batchRecords{j}=result.record;
        save(fullfile(historyDir,sprintf('F%02d_%s_r%03d.mat', ...
            job.FunctionID,job.Variant,job.Run)),'-struct','result');
    end
    records(first:last)=batchRecords;
    rawRuns=struct2table([records{1:last}]);
    writetable(rawRuns,fullfile(resultDir,'raw_runs_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
summaryRecords={};
count=0;
for functionID=functionIDs
    for k=1:numel(variants)
        rows=rawRuns(rawRuns.FunctionID==functionID & ...
            strcmp(rawRuns.Algorithm,variants{k}),:);
        count=count+1;
        summaryRecords{count}=struct('Function',sprintf('F%02d',functionID), ...
            'Algorithm',variants{k},'Runs',height(rows), ...
            'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
            'MedianError',median(rows.BestError),'MeanSeconds',mean(rows.Seconds), ...
            'TracingFEShare',mean(rows.TracingFEShare), ...
            'TraceFreeRoundRate',mean(rows.TraceFreeRoundRate), ...
            'BalancedModeRate',mean(rows.BalancedModeRate), ...
            'Action1Share',mean(rows.Action1Share),'Action2Share',mean(rows.Action2Share), ...
            'Action3Share',mean(rows.Action3Share),'Action4Share',mean(rows.Action4Share));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
save(fullfile(resultDir,'action_ablation_results.mat'),'rawRuns','summary');
delete(gcp('nocreate'))
fprintf('Saved parallel action ablation to %s\n',resultDir);

