function rec=run_asc_vl_job(job,cfg,outDir)
%RUN_ASC_VL_JOB  One counted verified-exemplar learning run.
%
% Every assertion below is evaluated inside the counted run, so a run only
% reaches the result table after the budget, the returned solution, the
% best-so-far trace and the new evaluation-branch diagnostics have been
% checked on that very run.  Post-run rechecks are counted separately and are
% never mixed into the optimisation budget.
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=cfg.Population;D=cfg.Dimension;budget=cfg.Budget;
lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub, ...
    'maxEvaluations',budget,'learnMode',job.Method, ...
    'cognitiveShare',cfg.CognitiveShare,'exploreFraction',cfg.ExploreFraction);
calls=0;outside=0;postCalls=0;observedBest=inf;capturedT=nan(budget,1);
B=[];T=[];I=[];status='ok';message='';bestDiff=NaN;traceDiff=NaN;clock=tic;
try
    [B,T,I]=ASC_NoFarness_VerifiedLearning(@objective,state,[],N,job.SearchSeed);
    seconds=toc(clock);
    assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget, ...
        'VLRun:Budget','Unexpected evaluation count.');
    assert(all(isfinite(T))&&all(diff(T)<=0)&&outside==0,'VLRun:Trace','Invalid trace.');
    assert(isequal(capturedT,T));traceDiff=max(abs(capturedT-T));
    assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
    bestDiff=abs(recheck(B.Vector)-B.Cost);
    assert(bestDiff<=1e-10*max(1,abs(B.Cost)),'VLRun:Best','Best value did not recheck.');
    % --- the search framework must be the frozen ASC-NoFarness one --------
    P=I.Parameters;
    assert(strcmp(I.LearnMode,job.Method)&&strcmp(I.Variant,['ASC-NoFarness-' job.Method]));
    assert(P.cognitiveShare==cfg.CognitiveShare&&P.exploreFraction==cfg.ExploreFraction);
    assert(P.traceBoostGain==0&&P.seekEliteGain==0,'VLRun:Params','Search model changed.');
    assert(P.useJump&&P.jumpFraction==0.50&&P.jumpGens==20&&strcmp(P.jumpUnit,'generation'));
    assert(~P.useGroup&&~P.useOBL&&~P.useGaussBest&&~strcmp(P.seekNoise,'gaussian'), ...
        'VLRun:Params','A disabled enhancer was switched on.');
    assert(P.useAdaptiveRadius&&P.useAdaptiveProb&&P.slownessInvert&&P.logRounds==false);
    assert(P.evaluationsPerRound==10&&P.perOwnerCap==2&&P.seekProbMin==0.20&&P.seekProbMax==0.90);
    assert(P.inertiaStart==0.90&&P.inertiaEnd==0.40&&P.radiusMin==0.020&&P.radiusMax==0.200);
    assert(P.eliteFraction==0.20&&P.seekCandidateCount==4&&P.seekDimFraction==0.20);
    % --- the new diagnostics must be internally consistent ---------------
    dg=I.Diagnostics;
    assert(dg.EvalTrace+dg.EvalSeek==budget-N,'VLRun:Diag','Branch counts do not add up.');
    assert(dg.EvalNear+dg.EvalFar==budget-N,'VLRun:Diag','Phase counts do not add up.');
    initDrops=sum(diff(T(1:N))<0);
    assert(dg.ImpGlobalTrace+dg.ImpGlobalSeek==sum(diff(T)<0)-initDrops, ...
        'VLRun:Diag','Global improvements do not match the trace.');
    assert(dg.ImpGlobalNear+dg.ImpGlobalFar==dg.ImpGlobalTrace+dg.ImpGlobalSeek);
    assert(dg.ImpPbestNear+dg.ImpPbestFar==dg.ImpPbestTrace+dg.ImpPbestSeek);
    assert(dg.GapN==budget-N&&dg.GapMax>=1,'VLRun:Diag','Evaluation gaps were not recorded.');
    assert(dg.JumpVictims==sum(dg.JumpVictimPending)+dg.JumpVictimRecovered, ...
        'VLRun:Diag','Jump victim accounting is inconsistent.');
    assert(size(I.DiagLog,1)==I.Rounds&&size(I.DiagLog,2)==12);
    assert(abs(sum(I.DiagLog(:,1))-dg.EvalTrace)<=1e-9);
    assert(abs(sum(I.DiagLog(:,2))-dg.EvalSeek)<=1e-9);
    assert(abs(sum(I.DiagLog(:,4))-dg.EvalFar)<=1e-9);
    assert(abs(sum(I.DiagLog(:,9))-dg.ImpGlobalTrace)<=1e-9);
    % --- mode-specific expectations --------------------------------------
    if strcmp(job.Method,'B0')||strcmp(job.Method,'B1')
        assert(I.ExploreParticles==0,'VLRun:Mode','Learning roles leaked into a non-dual mode.');
    else
        expectedExplore=sum(mod((0:N-1)',10)<round(10*cfg.ExploreFraction));
        assert(I.ExploreParticles==expectedExplore,'VLRun:Mode','Unexpected explore share.');
    end
catch e
    seconds=toc(clock);status='error';
    message=getReport(e,'extended','hyperlinks','off');
end
rec=job;rec.Status=status;rec.ErrorMessage=message;rec.Dimension=D;rec.Population=N;
rec.Budget=budget;rec.FinalCost=getfieldor(B,'Cost',NaN);
rec.FinalError=rec.FinalCost-100*job.FunctionID;rec.Seconds=seconds;
rec.ObjectiveCalls=calls;rec.Evaluations=getfieldor(I,'Evaluations',NaN);
rec.OutsideCalls=outside;rec.PostRunRecheckCalls=postCalls;
rec.BestDiff=bestDiff;rec.ObservedTraceMaxDiff=traceDiff;
rec.Rounds=getfieldor(I,'Rounds',NaN);rec.Jumps=getfieldor(I,'Jumps',NaN);
rec.ExploreParticles=getfieldor(I,'ExploreParticles',NaN);
rec.CognitiveShare=getfieldor(I,'CognitiveShare',NaN);
rec.ExploreFraction=getfieldor(I,'ExploreFraction',NaN);
di=struct('EvalTrace',0,'EvalSeek',0,'EvalNear',0,'EvalFar',0, ...
    'ImpPbestTrace',0,'ImpPbestSeek',0,'ImpPbestNear',0,'ImpPbestFar',0, ...
    'ImpGlobalTrace',0,'ImpGlobalSeek',0,'ImpGlobalNear',0,'ImpGlobalFar',0, ...
    'GapSum',0,'GapN',0,'GapMax',0,'JumpEvents',0,'JumpStallSum',0, ...
    'JumpVictims',0,'JumpVictimRecovered',0);
dg=getfieldor(I,'Diagnostics',di);
fn=fieldnames(di);
for k=1:numel(fn),rec.(fn{k})=getfieldor(dg,fn{k},0);end
rec.MeanEvalGap=rec.GapSum/max(1,rec.GapN);
rec.Artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Method);
save(fullfile(outDir,'runs',rec.Artifact),'job','rec','B','T','I','state','p0','-v7');

    function v=objective(x)
        calls=calls+1;assert(calls<=budget,'VLRun:OverBudget','Objective call beyond budget.');
        if any(~isfinite(x))||any(x<lb|x>ub)
            outside=outside+1;error('VLRun:Bounds','Nonfinite or outside point');
        end
        v=CEC2017Function(x,job.FunctionID);assert(isscalar(v)&&isfinite(v));
        observedBest=min(observedBest,v);capturedT(calls)=observedBest;
    end

    function v=recheck(x)
        postCalls=postCalls+1;v=CEC2017Function(x,job.FunctionID);
    end
end

function v=getfieldor(s,key,default)
if isstruct(s)&&isfield(s,key),v=s.(key);else,v=default;end
end
