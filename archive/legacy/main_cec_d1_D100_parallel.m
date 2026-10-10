clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[1 3:30];
repeatIDs=101:103;
D=100;
population=50;
maxEvaluations=60000;
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
workerCount=4;
batchSize=4;
d3ResultDir=fullfile(root,'results','cec', ...
    'cec2017_d3_vs_clpso_D100_20261009_214003');
assert(isfile(fullfile(d3ResultDir,'raw_runs.csv')))

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec', ...
    ['cec2017_d1_D100_' stamp]);
mkdir(resultDir);

jobs=struct('FunctionID',{},'Run',{},'InitSeed',{},'SearchSeed',{}, ...
    'InitialPopulation',{});
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
curves=cell(numel(jobs),1);
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
            'seekSelection','globalCap2','searchCore','elite','eliteGuidance',true, ...
            'seekingEliteGuidance',true,'tracingElitistAcceptance',true, ...
            'tracingDecay',true,'virtualTracing',false,'SMP',5, ...
            'evaluationQuota',2,'recoveryEnabled',false, ...
            'useModePreserving',true,'feedbackLogging',true, ...
            'ablation',struct('useCatScreen',true,'useCandidateScreen',true, ...
                'useRL',false));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
        assert(all(isfinite(T)) && all(diff(T)<=0))
        assert(all(info.EvaluationsPerRound==5))
        assert(all(info.ActualTracingEvaluations==2))
        assert(all(info.ActualSeekingEvaluations==3))
        assert(all(info.BudgetFillRate==1))
        assert(max(abs(info.ModeAllocationError),[],'all')==0)
        assert(max(info.SeekingMaxParentEvaluations)<=2)
        functionValue=100*job.FunctionID;
        batchResults{j}=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm','D1-TracingDecay', ...
            'Run',job.Run,'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Dimension',D,'Population',population,'MaxEvaluations',maxEvaluations, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-functionValue),'Seconds',info.Seconds);
        nodes=(3000:3000:maxEvaluations)';
        curves{j}=table(repmat(job.FunctionID,numel(nodes),1), ...
            repmat({'D1-TracingDecay'},numel(nodes),1),repmat(job.Run,numel(nodes),1), ...
            nodes,max(0,T(nodes)-functionValue), ...
            'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j};
    end
    writetable(struct2table([records{1:last}]), ...
        fullfile(resultDir,'raw_runs_checkpoint.csv'));
    writetable(vertcat(curves{1:last}), ...
        fullfile(resultDir,'convergence_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
writetable(vertcat(curves{:}),fullfile(resultDir,'convergence.csv'));

d3=readtable(fullfile(d3ResultDir,'raw_runs.csv'));
comparisonRecords=cell(numel(functionIDs),1);
summaryRecords=cell(numel(functionIDs),1);
for q=1:numel(functionIDs)
    functionID=functionIDs(q);
    d1=sortrows(rawRuns(rawRuns.FunctionID==functionID,:),'Run');
    d3Rows=sortrows(d3(d3.FunctionID==functionID & ...
        strcmp(d3.Algorithm,'D3-Both'),:),'Run');
    assert(isequal(d1.Run,d3Rows.Run) && isequal(d1.InitSeed,d3Rows.InitSeed))
    comparisonRecords{q}=struct('Function',sprintf('F%02d',functionID), ...
        'FunctionID',functionID,'D3MeanError',mean(d3Rows.BestError), ...
        'D1MeanError',mean(d1.BestError),'D3StdError',std(d3Rows.BestError), ...
        'D1StdError',std(d1.BestError),'D3MedianError',median(d3Rows.BestError), ...
        'D1MedianError',median(d1.BestError),'D3Wins',sum(d3Rows.BestError<d1.BestError), ...
        'D1Wins',sum(d3Rows.BestError>d1.BestError),'Ties',sum(d3Rows.BestError==d1.BestError), ...
        'D3MeanSeconds',mean(d3Rows.Seconds),'D1MeanSeconds',mean(d1.Seconds));
    summaryRecords{q}=struct('Function',sprintf('F%02d',functionID), ...
        'FunctionID',functionID,'Algorithm','D1-TracingDecay','Runs',height(d1), ...
        'MeanError',mean(d1.BestError),'StdError',std(d1.BestError), ...
        'MedianError',median(d1.BestError),'MeanSeconds',mean(d1.Seconds));
end
comparison=struct2table([comparisonRecords{:}]);
writetable(comparison,fullfile(resultDir,'comparison.csv'));
writetable(struct2table([summaryRecords{:}]),fullfile(resultDir,'summary.csv'));
readme={ ...
    '# D1 versus D3 at D100, 60k FE', ...
    '', ...
    '- D1 is D3 with virtual tracing disabled; tracing decay, elite guidance, Range Seeking, Global-Cap2, MR=0.4, SMP=5 and all FE controls are unchanged.', ...
    '- Functions: F1, F3-F30 (29 functions); dimension: 100; population: 50; budget: 60,000 FE.', ...
    '- Repeats: 101:103. Initial populations and search seeds are regenerated identically to the D3-vs-CLPSO experiment.', ...
    '- `comparison.csv` pairs the new D1 runs with the existing D3 runs from `cec2017_d3_vs_clpso_D100_20261009_214003`.', ...
    '- This is a mechanism ablation, not a new parameter search.', ...
    ''};
fid=fopen(fullfile(resultDir,'README.md'),'w');
fprintf(fid,'%s\n',readme{:});
fclose(fid);
delete(gcp('nocreate'))
fprintf('D3 versus D1 comparison saved to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
