clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[3 5 13 15 19 30];
D=30;
population=50;
maxEvaluations=10000*D;
repeatIDs=1:3;
seedBase=20271004;
searchSeedOffset=100000;
lb=-100*ones(1,D);
ub=100*ones(1,D);
variants={'V4.1-Q-NoRecovery','V4.1-Q-IntervalRecovery'};
recoveryEnabled=[false true];

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_v41_q_compare_' stamp]);
historyDir=fullfile(resultDir,'histories');
mkdir(resultDir); mkdir(historyDir);

jobs=struct('FunctionID',{},'Run',{},'Variant',{},'RecoveryEnabled',{}, ...
    'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        initialPopulation=lb+rand(population,D).*(ub-lb);
        for k=1:numel(variants)
            count=count+1;
            jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
                'Variant',variants{k},'RecoveryEnabled',recoveryEnabled(k), ...
                'InitSeed',initSeed,'SearchSeed',initSeed+searchSeedOffset, ...
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
batchSize=8;
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        f=@(x)CEC2017Function(x,job.FunctionID);
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation, ...
            'actionMode','qlearning','rlMode','modeAwareV41', ...
            'recoveryEnabled',job.RecoveryEnabled,'recoveryInterval',20, ...
            'ablation',struct('useCatScreen',true,'useCandidateScreen',true,'useRL',true));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population),population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && all(isfinite(T)))
        assert(mean(info.BudgetFillRate)>0.999)
        assert(max(abs(info.ModeAllocationError),[],'all')==0)
        greedy=info.GreedyActionHistory(~isnan(info.GreedyActionHistory));
        record=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm',job.Variant,'Run',job.Run, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-100*job.FunctionID),'Seconds',info.Seconds, ...
            'TracingFEShare',info.TracingEvaluations/(maxEvaluations-population), ...
            'TargetTracingFEShare',mean(info.TargetTracingEvaluations)/5, ...
            'RecoveryFEShare',info.RecoveryEvaluations/(maxEvaluations-population), ...
            'RecoveryRoundRate',mean(info.RecoveryEvaluationsPerRound>0), ...
            'RecoveryImprovementRate',mean(info.RecoveryImprovementPerRound), ...
            'TraceFreeRoundRate',mean(info.TracingEvaluationsPerRound==0), ...
            'BalancedModeRate',mean(info.ModeStateHistory==2), ...
            'ExplorationRate',mean(info.WasExploration), ...
            'GreedyAvailableRate',mean(~isnan(info.GreedyActionHistory)), ...
            'GreedyA1Share',mean(greedy==1),'GreedyA2Share',mean(greedy==2), ...
            'GreedyA3Share',mean(greedy==3), ...
            'Action1Share',info.ActionCounts(1)/sum(info.ActionCounts), ...
            'Action2Share',info.ActionCounts(2)/sum(info.ActionCounts), ...
            'Action3Share',info.ActionCounts(3)/sum(info.ActionCounts));
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
summaryRecords=cell(numel(functionIDs)*numel(variants),1);
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
            'TargetTracingFEShare',mean(rows.TargetTracingFEShare), ...
            'RecoveryFEShare',mean(rows.RecoveryFEShare), ...
            'RecoveryRoundRate',mean(rows.RecoveryRoundRate), ...
            'RecoveryImprovementRate',mean(rows.RecoveryImprovementRate), ...
            'TraceFreeRoundRate',mean(rows.TraceFreeRoundRate), ...
            'BalancedModeRate',mean(rows.BalancedModeRate), ...
            'ExplorationRate',mean(rows.ExplorationRate), ...
            'Action1Share',mean(rows.Action1Share), ...
            'Action2Share',mean(rows.Action2Share), ...
            'Action3Share',mean(rows.Action3Share));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
save(fullfile(resultDir,'v41_q_results.mat'),'rawRuns','summary');
delete(gcp('nocreate'))
fprintf('Saved V4.1 Q comparison to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
