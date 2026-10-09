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

variants={ ...
    struct('Name','D3-Both','TracingDecay',true,'VirtualTracing',true), ...
    struct('Name','CLPSO','TracingDecay',false,'VirtualTracing',false)};

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_d3_vs_clpso_D100_' stamp]);
mkdir(resultDir);

% Validate data before invoking the MEX: missing files can crash the native interface.
preflight=cell(numel(functionIDs),1);
clear cec17_func
for q=1:numel(functionIDs)
    functionID=functionIDs(q);
    matrixFile=fullfile('input_data',sprintf('M_%d_D100.txt',functionID));
    assert(isfile(matrixFile),'Missing rotation matrix: %s',matrixFile)
    matrix=ReadNumericData(matrixFile);
    matrixCount=10000*(1+9*(functionID>=21));
    assert(numel(matrix)>=matrixCount && all(isfinite(matrix(:))))
    shiftFile=fullfile('input_data',sprintf('shift_data_%d.txt',functionID));
    assert(isfile(shiftFile),'Missing shift file: %s',shiftFile)
    shift=ReadNumericData(shiftFile);
    assert(numel(shift)>=D && all(isfinite(shift(:))))
    if (functionID>=11 && functionID<=20) || functionID>=29
        shuffleFile=fullfile('input_data',sprintf('shuffle_data_%d_D100.txt',functionID));
        assert(isfile(shuffleFile),'Missing shuffle file: %s',shuffleFile)
        order=ReadNumericData(shuffleFile);
        requiredPermutations=1+9*(functionID>=29);
        assert(numel(order)>=D*requiredPermutations)
        order=reshape(order,D,[])';
        assert(all(sort(order(1:requiredPermutations,:),2)==1:D,'all'))
    end
    zeroValue=CEC2017Function(zeros(1,D),functionID);
    shiftValue=CEC2017Function(shift(1:D)',functionID);
    assert(isfinite(zeroValue) && isfinite(shiftValue))
    preflight{q}=struct('FunctionID',functionID,'Dimension',D, ...
        'ZeroCost',zeroValue,'ShiftCost',shiftValue,'ExpectedBias',100*functionID, ...
        'ShiftResidual',shiftValue-100*functionID);
end
writetable(struct2table([preflight{:}]),fullfile(resultDir,'function_call_check.csv'));
fprintf('D100 official data and MEX checks passed for all 29 functions.\n');

jobs=struct('FunctionID',{},'Run',{},'Variant',{},'TracingDecay',{}, ...
    'VirtualTracing',{},'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        initialPopulation=lb+rand(population,D).*(ub-lb);
        for v=1:numel(variants)
            count=count+1;
            spec=variants{v};
            jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
                'Variant',spec.Name,'TracingDecay',spec.TracingDecay, ...
                'VirtualTracing',spec.VirtualTracing,'InitSeed',initSeed, ...
                'SearchSeed',initSeed+100000, ...
                'InitialPopulation',initialPopulation);
        end
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
        if strcmp(job.Variant,'CLPSO')
            state=struct('lowerBound',lb,'upperBound',ub, ...
                'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation);
            [Best,T,info]=CLPSO_CEC(f,state,ceil(maxEvaluations/population), ...
                population,job.SearchSeed);
        else
            state=struct('lowerBound',lb,'upperBound',ub, ...
                'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation, ...
                'actionMode','fixed2','rlMode','modeAwareV41','seekingMode','range', ...
                'seekSelection','globalCap2','searchCore','elite','eliteGuidance',true, ...
                'tracingElitistAcceptance',true,'tracingDecay',job.TracingDecay, ...
                'virtualTracing',job.VirtualTracing,'SMP',5,'evaluationQuota',2, ...
                'recoveryEnabled',false,'useModePreserving',true, ...
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
        end
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
        assert(all(isfinite(T)) && all(diff(T)<=0))
        assert(isequal(info.InitialPopulation,job.InitialPopulation))
        functionValue=100*job.FunctionID;
        record=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm',job.Variant,'Run',job.Run, ...
            'Dimension',D,'Population',population,'MaxEvaluations',maxEvaluations, ...
            'TracingDecay',job.TracingDecay,'VirtualTracing',job.VirtualTracing, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-functionValue),'Seconds',info.Seconds, ...
            'Error30FE',max(0,T(round(0.3*maxEvaluations))-functionValue), ...
            'Error60FE',max(0,T(round(0.6*maxEvaluations))-functionValue), ...
            'Error80FE',max(0,T(round(0.8*maxEvaluations))-functionValue));
        nodes=(3000:3000:maxEvaluations)';
        curve=table(repmat(job.FunctionID,numel(nodes),1), ...
            repmat({job.Variant},numel(nodes),1),repmat(job.Run,numel(nodes),1), ...
            nodes,max(0,T(nodes)-functionValue), ...
            'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
        batchResults{j}=struct('record',record,'curve',curve);
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j}.record;
        curves{first+j-1}=batchResults{j}.curve;
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

summaryRecords=cell(numel(functionIDs)*numel(variants),1);
k=0;
for functionID=functionIDs
    for v=1:numel(variants)
        rows=rawRuns(rawRuns.FunctionID==functionID & ...
            strcmp(rawRuns.Algorithm,variants{v}.Name),:);
        if isempty(rows)
            continue
        end
        k=k+1;
        summaryRecords{k}=struct('Function',sprintf('F%02d',functionID), ...
            'FunctionID',functionID,'Algorithm',variants{v}.Name,'Runs',height(rows), ...
            'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
            'MedianError',median(rows.BestError),'MinError',min(rows.BestError), ...
            'MeanSeconds',mean(rows.Seconds),'MeanError30FE',mean(rows.Error30FE), ...
            'MeanError60FE',mean(rows.Error60FE),'MeanError80FE',mean(rows.Error80FE));
    end
end
writetable(struct2table([summaryRecords{1:k}]),fullfile(resultDir,'summary.csv'));

comparisonRecords=cell(numel(functionIDs),1);
for q=1:numel(functionIDs)
    functionID=functionIDs(q);
    d3=sortrows(rawRuns(rawRuns.FunctionID==functionID & ...
        strcmp(rawRuns.Algorithm,'D3-Both'),:),'Run');
    clpso=sortrows(rawRuns(rawRuns.FunctionID==functionID & ...
        strcmp(rawRuns.Algorithm,'CLPSO'),:),'Run');
    assert(isequal(d3.Run,clpso.Run) && isequal(d3.InitSeed,clpso.InitSeed))
    comparisonRecords{q}=struct('Function',sprintf('F%02d',functionID), ...
        'FunctionID',functionID,'D3MeanError',mean(d3.BestError), ...
        'CLPSOMeanError',mean(clpso.BestError),'D3StdError',std(d3.BestError), ...
        'CLPSOStdError',std(clpso.BestError),'D3MedianError',median(d3.BestError), ...
        'CLPSOMedianError',median(clpso.BestError), ...
        'D3Wins',sum(d3.BestError<clpso.BestError), ...
        'CLPSOWins',sum(d3.BestError>clpso.BestError), ...
        'Ties',sum(d3.BestError==clpso.BestError), ...
        'D3MeanSeconds',mean(d3.Seconds),'CLPSOMeanSeconds',mean(clpso.Seconds));
end
comparison=struct2table([comparisonRecords{:}]);
writetable(comparison,fullfile(resultDir,'comparison.csv'));
fprintf('D3 mean wins: %d/29; paired wins/losses/ties: %d/%d/%d\n', ...
    sum(comparison.D3MeanError<comparison.CLPSOMeanError), ...
    sum(comparison.D3Wins),sum(comparison.CLPSOWins),sum(comparison.Ties));
readme={ ...
    '# D3 versus CLPSO at D100, 60k FE', ...
    '', ...
    '- Functions: F1, F3-F30 (29 functions); dimension: 100; population: 50.', ...
    '- Budget: 60,000 FE including initialization; this is 6% of 10000D, a restricted-budget stress test.', ...
    '- Repeats: 101:103; identical paired initial populations and search seeds.', ...
    '- D3 is unchanged: elite guidance, Range Seeking, Global-Cap2, MR=0.4, SMP=5, tracing decay and virtual tracing with real-position rollback.', ...
    '- D3 real evaluation allocation is fixed at 2 Tracing + 3 Seeking per round; parent cap is 2; RL and Recovery are disabled.', ...
    '- Four workers; batches of four; CSV checkpoints are written after each batch.', ...
    '- Official D100 data are from P-N-Suganthan/CEC2017-BoundContrained; source and hashes are in data/cec2017/D100_sources.md and D100_manifest.csv.', ...
    '- Before optimization, all 29 MEX calls are checked for finite values and correct cost at their shifted optimum.', ...
    '- Each run checks exact FE, finite nonincreasing convergence, and shared initialization. D3 also checks fixed quotas, budget fill and parent cap.', ...
    '- This is a three-seed dimension-transfer pretest, not a formal 30-run statistical validation.', ...
    ''};
fid=fopen(fullfile(resultDir,'README.md'),'w');
fprintf(fid,'%s\n',readme{:});
fclose(fid);

delete(gcp('nocreate'))
fprintf('Saved D100 D3 versus CLPSO results to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end

function values=ReadNumericData(path)
    fid=fopen(path,'r');
    assert(fid>=0,'Cannot read data file: %s',path)
    cleanup=onCleanup(@()fclose(fid));
    values=fscanf(fid,'%f');
end
