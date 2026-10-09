clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[1 3 9 12 22];
budgets=[60000 150000 300000];
repeatIDs=21:23;
D=30;
population=50;
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
workerCount=4;
batchSize=4;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_budget_screen_' stamp]);
mkdir(resultDir);

% V1只补跑60k/150k；300k复用同协议的V1-Elite历史结果。
jobs=struct('FunctionID',{},'Run',{},'Algorithm',{},'Budget',{}, ...
    'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        initialPopulation=lb+rand(population,D).*(ub-lb);
        for budget=budgets(1:2)
            count=count+1;
            jobs(count)=makeJob(functionID,repeat,'V1-Elite',budget, ...
                initSeed,initialPopulation);
        end
        for budget=budgets
            count=count+1;
            jobs(count)=makeJob(functionID,repeat,'CLPSO',budget, ...
                initSeed,initialPopulation);
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
        [record,curve]=runJob(job,lb,ub,population,D);
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

summaryRecords=cell(numel(functionIDs)*numel(budgets)*2,1);
k=0;
for functionID=functionIDs
    for budget=budgets
        for algorithm={'V1-Elite','CLPSO'}
            rows=rawRuns(rawRuns.FunctionID==functionID & ...
                rawRuns.Budget==budget & strcmp(rawRuns.Algorithm,algorithm{1}),:);
            if isempty(rows)
                continue
            end
            k=k+1;
            summaryRecords{k}=struct('Function',sprintf('F%02d',functionID), ...
                'FunctionID',functionID,'Algorithm',algorithm{1},'Budget',budget, ...
                'Runs',height(rows),'MeanError',mean(rows.BestError), ...
                'StdError',std(rows.BestError),'MedianError',median(rows.BestError), ...
                'MinError',min(rows.BestError),'MeanSeconds',mean(rows.Seconds), ...
                'MeanErrorHalfFE',mean(rows.ErrorHalfFE));
        end
    end
end
summary=struct2table([summaryRecords{1:k}]);
writetable(summary,fullfile(resultDir,'summary.csv'));

readme={ ...
    '# CEC2017 budget screen', ...
    '', ...
    '- Functions: F1, F3, F9, F12, F22.', ...
    '- Dimension: D=30; population: 50.', ...
    '- Budgets: 60,000, 150,000, and 300,000 FE.', ...
    '- Repeats: 21:23, paired initial populations.', ...
    '- V1-Elite uses Global-Cap2, Range Seeking, MR=0.4, SMP=5, and no recovery/RL.', ...
    '- V1-Elite is newly run at 60k and 150k. The 300k V1 reference is retained in the previous search-core experiment.', ...
    '- CLPSO is run at all three budgets.', ...
    '- Every run checks exact FE accounting; DSS checks the 2 Tracing + 3 Seeking allocation.', ...
    '', ...
    'A shorter budget is an independent run: the Range step scale uses the run-specific progress value, so a 60k run is not treated as the first 60k evaluations of a 300k run.', ...
    ''};
fid=fopen(fullfile(resultDir,'README.md'),'w');
fprintf(fid,'%s\n',readme{:});
fclose(fid);

delete(gcp('nocreate'))
fprintf('Saved budget screen to %s\n',resultDir);

function job=makeJob(functionID,run,algorithm,budget,initSeed,initialPopulation)
    job=struct('FunctionID',functionID,'Run',run,'Algorithm',algorithm, ...
        'Budget',budget,'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
        'InitialPopulation',initialPopulation);
end

function [record,curve]=runJob(job,lb,ub,population,D)
    f=@(x)CEC2017Function(x,job.FunctionID);
    if strcmp(job.Algorithm,'V1-Elite')
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',job.Budget,'initialPopulation',job.InitialPopulation, ...
            'actionMode','fixed2','rlMode','modeAwareV41','seekingMode','range', ...
            'seekSelection','globalCap2','searchCore','elite','SMP',5, ...
            'recoveryEnabled',false,'useModePreserving',true, ...
            'ablation',struct('useCatScreen',true,'useCandidateScreen',true, ...
                'useRL',false));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(job.Budget/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==job.Budget && numel(T)==job.Budget)
        assert(all(isfinite(T)) && all(info.EvaluationsPerRound==5))
        assert(all(info.ActualTracingEvaluations==2))
        assert(all(info.ActualSeekingEvaluations==3))
        assert(all(info.BudgetFillRate==1))
        assert(max(abs(info.ModeAllocationError),[],'all')==0)
        assert(max(info.SeekingMaxParentEvaluations)<=2)
        seekingSuccess=sum(info.SeekingSuccessHistory.*info.SeekingEvaluationsPerRound)/ ...
            info.SeekingEvaluations;
        coverage=mean(info.SeekingParentCoverage);
        concentration=mean(info.SeekingConcentration);
        globalImprovements=sum(info.SeekingGlobalImprovementCounts);
    else
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',job.Budget,'initialPopulation',job.InitialPopulation);
        [Best,T,info]=CLPSO_CEC(f,state,ceil(job.Budget/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==job.Budget && numel(T)==job.Budget)
        assert(all(isfinite(T)))
        seekingSuccess=NaN;
        coverage=NaN;
        concentration=NaN;
        globalImprovements=NaN;
    end
    functionValue=100*job.FunctionID;
    record=struct('Function',sprintf('F%02d',job.FunctionID), ...
        'FunctionID',job.FunctionID,'Algorithm',job.Algorithm,'Run',job.Run, ...
        'Budget',job.Budget,'SMP',5,'InitSeed',job.InitSeed, ...
        'SearchSeed',job.SearchSeed,'Evaluations',info.Evaluations, ...
        'BestCost',Best.Cost,'BestError',max(0,Best.Cost-functionValue), ...
        'Seconds',info.Seconds, ...
        'ErrorHalfFE',max(0,T(round(job.Budget/2))-functionValue), ...
        'SeekingParentCoverage',coverage,'SeekingConcentration',concentration, ...
        'SeekingSuccessRate',seekingSuccess, ...
        'SeekingGlobalImprovements',globalImprovements);
    nodes=(3000:3000:job.Budget)';
    curve=table(repmat(job.FunctionID,numel(nodes),1), ...
        repmat({job.Algorithm},numel(nodes),1),repmat(job.Run,numel(nodes),1), ...
        repmat(job.Budget,numel(nodes),1),nodes, ...
        max(0,T(nodes)-functionValue), ...
        'VariableNames',{'FunctionID','Algorithm','Run','Budget','FE','BestError'});
end

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
