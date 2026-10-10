clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[3 6 9 12 13 20 28 30];
repeatIDs=41:45;
D=30;
population=50;
maxEvaluations=60000;
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
workerCount=4;
batchSize=4;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_d3_random_screen_' stamp]);
mkdir(resultDir);

jobs=struct('FunctionID',{},'Run',{},'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        count=count+1;
        jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
            'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
            'InitialPopulation',lb+rand(population,D).*(ub-lb));
    end
end

pool=gcp('nocreate');
if isempty(pool)
    parpool('local',workerCount);
elseif pool.NumWorkers~=workerCount
    delete(pool);
    parpool('local',workerCount);
end

records=cell(numel(jobs),1);
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
            'seekSelection','randomCap2','searchCore','elite','eliteGuidance',true, ...
            'tracingElitistAcceptance',true,'tracingDecay',true, ...
            'virtualTracing',true,'SMP',5,'recoveryEnabled',false, ...
            'useModePreserving',true, ...
            'ablation',struct('useCatScreen',true,'useCandidateScreen',true, ...
                'useRL',false));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
        assert(all(isfinite(T)) && all(info.EvaluationsPerRound==5))
        assert(all(info.ActualTracingEvaluations==2))
        assert(all(info.ActualSeekingEvaluations==3))
        assert(all(info.BudgetFillRate==1))
        assert(max(abs(info.ModeAllocationError),[],'all')==0)
        assert(max(info.SeekingMaxParentEvaluations)<=2)
        functionValue=100*job.FunctionID;
        batchResults{j}=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm','D3-RandomCap2','Run',job.Run, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-functionValue),'Seconds',info.Seconds, ...
            'Error30FE',max(0,T(round(0.3*maxEvaluations))-functionValue), ...
            'Error60FE',max(0,T(round(0.6*maxEvaluations))-functionValue), ...
            'Error80FE',max(0,T(round(0.8*maxEvaluations))-functionValue));
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j};
    end
    writetable(struct2table([records{1:last}]),fullfile(resultDir,'raw_runs_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
summaryRecords=cell(numel(functionIDs),1);
for k=1:numel(functionIDs)
    rows=rawRuns(rawRuns.FunctionID==functionIDs(k),:);
    summaryRecords{k}=struct('Function',sprintf('F%02d',functionIDs(k)), ...
        'FunctionID',functionIDs(k),'Algorithm','D3-RandomCap2','Runs',height(rows), ...
        'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
        'MedianError',median(rows.BestError),'MinError',min(rows.BestError), ...
        'MeanSeconds',mean(rows.Seconds));
end
writetable(struct2table([summaryRecords{:}]),fullfile(resultDir,'summary.csv'));
readme={ ...
    '# D3 random opportunity screen at 60k FE', ...
    '', ...
    '- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.', ...
    '- Repeats: 41:45; D=30; population=50; 60,000 FE.', ...
    '- D3 search dynamics are unchanged: tracing decay plus virtual tracing with rollback.', ...
    '- Only Seeking candidate selection changes from Global-Cap2 to random sampling with the same 2-candidate parent cap.', ...
    '- The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation.', ...
    ''};
fid=fopen(fullfile(resultDir,'README.md'),'w');
fprintf(fid,'%s\n',readme{:});
fclose(fid);
delete(gcp('nocreate'))
fprintf('Saved random opportunity screen to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
