clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[1 3 6 9 10 12 15 19 22 26];
D=30;
population=50;
maxEvaluations=10000*D;
repeatIDs=21:23;                     % 与V1-SMP5相同seed，便于配对
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
SMP=3;
algorithm='V1-Elite-SMP3';

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_smp3_' stamp]);
mkdir(resultDir);

jobs=struct('FunctionID',{},'Run',{},'InitSeed',{},'SearchSeed',{}, ...
    'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        count=count+1;
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
            'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
            'InitialPopulation',lb+rand(population,D).*(ub-lb));
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
curves=cell(numel(jobs),1);
batchSize=4;
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        f=@(x)CEC2017Function(x,job.FunctionID);
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation, ...
            'actionMode','fixed2','rlMode','modeAwareV41','seekingMode','range', ...
            'seekSelection','globalCap2','searchCore','elite','SMP',SMP, ...
            'recoveryEnabled',false,'useModePreserving',true, ...
            'ablation',struct('useCatScreen',true,'useCandidateScreen',true, ...
            'useRL',false));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations && all(isfinite(T)))
        assert(all(info.EvaluationsPerRound==5))
        assert(all(info.ActualTracingEvaluations==2))
        assert(all(info.ActualSeekingEvaluations==3))
        assert(all(info.BudgetFillRate==1))
        assert(max(abs(info.ModeAllocationError),[],'all')==0)
        assert(max(info.SeekingMaxParentEvaluations)<=2)
        record=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm',algorithm,'Run',job.Run, ...
            'SMP',SMP,'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-100*job.FunctionID),'Seconds',info.Seconds, ...
            'Error30FE',max(0,T(round(0.3*maxEvaluations))-100*job.FunctionID), ...
            'Error60FE',max(0,T(round(0.6*maxEvaluations))-100*job.FunctionID), ...
            'Error80FE',max(0,T(round(0.8*maxEvaluations))-100*job.FunctionID), ...
            'SeekingParentCoverage',mean(info.SeekingParentCoverage), ...
            'SeekingConcentration',mean(info.SeekingConcentration), ...
            'SeekingSuccessRate',sum(info.SeekingSuccessHistory.* ...
                info.SeekingEvaluationsPerRound)/info.SeekingEvaluations, ...
            'SeekingGlobalImprovements',sum(info.SeekingGlobalImprovementCounts), ...
            'MeanDiversity',mean(info.DiversityHistory), ...
            'BudgetFillRate',mean(info.BudgetFillRate));
        nodes=(3000:3000:maxEvaluations)';
        curve=table(repmat(job.FunctionID,numel(nodes),1), ...
            repmat({algorithm},numel(nodes),1),repmat(job.Run,numel(nodes),1), ...
            nodes,max(0,T(nodes)-100*job.FunctionID), ...
            'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
        batchResults{j}=struct('record',record,'curve',curve);
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j}.record;
        curves{first+j-1}=batchResults{j}.curve;
    end
    writetable(struct2table([records{1:last}]),fullfile(resultDir,'raw_runs_checkpoint.csv'));
    writetable(vertcat(curves{1:last}),fullfile(resultDir,'convergence_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
writetable(vertcat(curves{:}),fullfile(resultDir,'convergence.csv'));
summaryRecords=cell(numel(functionIDs),1);
for k=1:numel(functionIDs)
    rows=rawRuns(rawRuns.FunctionID==functionIDs(k),:);
    summaryRecords{k}=struct('Function',sprintf('F%02d',functionIDs(k)), ...
        'Algorithm',algorithm,'SMP',SMP,'Runs',height(rows), ...
        'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
        'MedianError',median(rows.BestError),'MinError',min(rows.BestError), ...
        'MeanSeconds',mean(rows.Seconds),'MeanError30FE',mean(rows.Error30FE), ...
        'MeanError60FE',mean(rows.Error60FE),'MeanError80FE',mean(rows.Error80FE), ...
        'MeanParentCoverage',mean(rows.SeekingParentCoverage), ...
        'MeanConcentration',mean(rows.SeekingConcentration), ...
        'SeekingSuccessRate',mean(rows.SeekingSuccessRate), ...
        'MeanSeekingGlobalImprovements',mean(rows.SeekingGlobalImprovements), ...
        'MeanDiversity',mean(rows.MeanDiversity));
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
delete(gcp('nocreate'))
fprintf('Saved SMP3 experiment to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
