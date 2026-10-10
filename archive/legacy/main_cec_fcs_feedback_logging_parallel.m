function main_cec_fcs_feedback_logging_parallel
% Logging-only pilot for feedback-conditioned Seeking.
% The D3 trajectory and evaluation plan are unchanged; this records whether
% a parent's second sampled candidate yields a marginal improvement over the
% first accepted real feedback in the same round.
clc; clear; close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'));
cd(fullfile(root,'data','cec2017'))

functionIDs=[3 6 9 12 13 20 28 30];
repeatIDs=161:163;
D=30; population=50; maxEvaluations=60000;
seedBase=20271004; workerCount=4; batchSize=4;
lb=-100*ones(1,D); ub=100*ones(1,D);

% A short paired audit proves that enabling the new logging fields consumes
% no random numbers and does not change the D3 trajectory.
rng(seedBase+repeatIDs(1),'twister');
auditInitial=lb+rand(population,D).*(ub-lb);
f=@(x)CEC2017Function(x,3);
auditState=BaseState(lb,ub,6000,auditInitial,false);
[bestOff,tOff,~]=DSS_RLCSO(f,auditState,ceil(6000/population),population,20371051);
auditState.feedbackLogging=true;
[bestOn,tOn,infoAudit]=DSS_RLCSO(f,auditState,ceil(6000/population),population,20371051);
assert(bestOff.Cost==bestOn.Cost && isequal(tOff,tOn));
assert(numel(infoAudit.FeedbackSeekingOrdinal)>0);
fprintf('FCS logging audit passed: trajectory unchanged.\n');

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_fcs_feedback_logging_' stamp]);
mkdir(resultDir);

jobs=struct('FunctionID',{},'Run',{},'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister');
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
    delete(pool); parpool('local',workerCount);
end

records=cell(numel(jobs),1); events=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last);
    batchRecords=cell(numel(batch),1); batchEvents=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j); f=@(x)CEC2017Function(x,job.FunctionID);
        state=BaseState(lb,ub,maxEvaluations,job.InitialPopulation,true);
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
        assert(all(isfinite(T)) && all(diff(T)<=1e-10));
        assert(all(info.EvaluationsPerRound==5));
        assert(all(info.ActualTracingEvaluations==2));
        assert(all(info.ActualSeekingEvaluations==3));
        assert(all(info.BudgetFillRate==1));
        assert(max(abs(info.ModeAllocationError),[],'all')==0);
        assert(max(info.SeekingMaxParentEvaluations)<=2);
        assert(numel(info.FeedbackSeekingRound)==numel(info.FeedbackSeekingOrdinal));
        assert(numel(info.FeedbackSeekingOrdinal)==numel(info.FeedbackSeekingMarginalGain));

        functionValue=100*job.FunctionID;
        ord=info.FeedbackSeekingOrdinal(:);
        second=ord==2;
        events=table(repmat(job.FunctionID,numel(ord),1), ...
            repmat(job.Run,numel(ord),1),info.FeedbackSeekingRound(:), ...
            info.FeedbackSeekingParent(:),ord,info.FeedbackSeekingValue(:), ...
            info.FeedbackSeekingAnchorCost(:),info.FeedbackSeekingSuccess(:), ...
            info.FeedbackSeekingMarginalImprovement(:),info.FeedbackSeekingMarginalGain(:), ...
            info.FeedbackSeekingGlobalImprovement(:), ...
            'VariableNames',{'FunctionID','Run','Round','Parent','Ordinal', ...
            'Value','AnchorCost','ParentSuccess','MarginalImprovement', ...
            'MarginalGain','GlobalImprovement'});
        batchEvents{j}=events;
        batchRecords{j}=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Run',job.Run,'InitSeed',job.InitSeed, ...
            'SearchSeed',job.SearchSeed,'Evaluations',info.Evaluations, ...
            'BestError',max(0,Best.Cost-functionValue),'Seconds',info.Seconds, ...
            'FeedbackRows',numel(ord),'FirstRows',nnz(ord==1), ...
            'SecondRows',nnz(second), ...
            'FirstSuccessRate',SafeMean(info.FeedbackSeekingSuccess(ord==1)), ...
            'SecondMarginalImprovementRate',SafeMean(info.FeedbackSeekingMarginalImprovement(second)), ...
            'SecondMarginalGainMean',SafeMean(info.FeedbackSeekingMarginalGain(second)), ...
            'SecondGlobalImprovementRate',SafeMean(info.FeedbackSeekingGlobalImprovement(second)), ...
            'MeanParentCoverage',mean(info.SeekingParentCoverage), ...
            'MeanConcentration',mean(info.SeekingConcentration));
    end
    for j=1:numel(batch)
        records{first+j-1}=batchRecords{j}; events{first+j-1}=batchEvents{j};
    end
    writetable(struct2table([records{1:last}]),fullfile(resultDir,'raw_runs_checkpoint.csv'));
    writetable(vertcat(events{1:last}),fullfile(resultDir,'feedback_events_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
feedbackEvents=vertcat(events{:});
writetable(feedbackEvents,fullfile(resultDir,'feedback_events.csv'));

summaryRows={}; k=0;
for functionID=functionIDs
    rows=rawRuns(rawRuns.FunctionID==functionID,:); k=k+1;
    summaryRows{k}=struct('Function',sprintf('F%02d',functionID), ...
        'FunctionID',functionID,'Runs',height(rows), ...
        'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
        'MeanFirstSuccessRate',mean(rows.FirstSuccessRate), ...
        'MeanSecondMarginalImprovementRate',mean(rows.SecondMarginalImprovementRate), ...
        'MeanSecondMarginalGain',mean(rows.SecondMarginalGainMean), ...
        'MeanSecondGlobalImprovementRate',mean(rows.SecondGlobalImprovementRate), ...
        'MeanSeconds',mean(rows.Seconds));
end
writetable(struct2table([summaryRows{:}]),fullfile(resultDir,'summary.csv'));

readme={ ...
    '# FCS feedback logging pilot', '', ...
    '- D=30, 60,000 FE, eight diagnostic functions, seeds 161:163, four workers.', ...
    '- Frozen D3 kernel: Range Seeking, Global-Cap2, tracing decay, virtual tracing and rollback; no RL or Recovery.', ...
    '- Logging only: no candidate-selection rule, random stream, FE allocation or trajectory is changed.', ...
    '- Each event records the parent, within-round ordinal, trusted anchor cost, parent-relative success and marginal gain.', ...
    '- Ordinal 2 is the observed same-parent second evaluation under the static D3 plan; this is diagnostic evidence, not a causal Continue/Switch comparison.', ...
    '- The paired 6,000-FE audit passed with identical Best and T trajectories with logging disabled/enabled.', ''};
fid=fopen(fullfile(resultDir,'README.md'),'w'); fprintf(fid,'%s\n',readme{:}); fclose(fid);
delete(gcp('nocreate'));
fprintf('Saved FCS feedback logging pilot to %s\n',resultDir);
end

function state=BaseState(lb,ub,maxEvaluations,initialPopulation,feedbackLogging)
state=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',maxEvaluations, ...
    'initialPopulation',initialPopulation,'actionMode','fixed2', ...
    'rlMode','modeAwareV41','seekingMode','range','seekSelection','globalCap2', ...
    'searchCore','elite','eliteGuidance',true,'tracingElitistAcceptance',true, ...
    'tracingDecay',true,'virtualTracing',true,'SMP',5,'recoveryEnabled',false, ...
    'useModePreserving',true,'feedbackLogging',feedbackLogging, ...
    'ablation',struct('useCatScreen',true,'useCandidateScreen',true,'useRL',false));
end

function value=SafeMean(x)
if isempty(x), value=NaN; else, value=mean(x); end
end

function value=CEC2017Function(x,functionID)
value=cec17_func(x',functionID); value=value(1);
end
