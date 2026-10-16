function rec=run_asc_sc_job(job,cfg,outDir)
%RUN_ASC_SC_JOB  One counted seeking-candidate run.
%
% Every assertion below is evaluated inside the counted run, so a run only
% reaches the result table after the budget, the returned solution, the
% best-so-far trace, the search-framework parameters and the candidate-type
% counters have been checked on that very run.  Post-run rechecks are counted
% separately and are never mixed into the optimisation budget.
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=cfg.Population;D=cfg.Dimension;budget=cfg.Budget;
lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub, ...
    'maxEvaluations',budget,'seekVariant',job.SeekVariant, ...
    'seekRefineCount',job.SeekRefineCount,'eliteGuideGain',cfg.EliteGuideGain);
calls=0;outside=0;postCalls=0;observedBest=inf;capturedT=nan(budget,1);
B=[];T=[];I=[];status='ok';message='';bestDiff=NaN;traceDiff=NaN;clock=tic;
try
    [B,T,I]=ASC_NoFarness_SeekingCandidates(@objective,state,[],N,job.SearchSeed);
    seconds=toc(clock);
    assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget, ...
        'SCRun:Budget','Unexpected evaluation count.');
    assert(all(isfinite(T))&&all(diff(T)<=0)&&outside==0,'SCRun:Trace','Invalid trace.');
    assert(isequal(capturedT,T));traceDiff=max(abs(capturedT-T));
    assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
    bestDiff=abs(recheck(B.Vector)-B.Cost);
    assert(bestDiff<=1e-10*max(1,abs(B.Cost)),'SCRun:Best','Best value did not recheck.');
    % --- the search framework must be the frozen ASC-NoFarness one --------
    P=I.Parameters;
    assert(strcmp(I.SeekVariant,job.SeekVariant)&&strcmp(I.Variant,['ASC-NoFarness-' job.SeekVariant]));
    assert(P.seekRefineCount==job.SeekRefineCount&&P.eliteGuideGain==cfg.EliteGuideGain);
    assert(P.seekEliteGain==0&&P.traceBoostGain==0,'SCRun:Params','The Tracing model changed.');
    assert(P.useJump&&P.jumpFraction==0.50&&P.jumpGens==20&&strcmp(P.jumpUnit,'generation'));
    assert(~P.useGroup&&~P.useOBL&&~P.useGaussBest&&~strcmp(P.seekNoise,'gaussian'));
    assert(P.useAdaptiveRadius&&P.useAdaptiveProb&&P.slownessInvert&&P.logRounds==false);
    assert(P.evaluationsPerRound==10&&P.perOwnerCap==2&&P.seekProbMin==0.20&&P.seekProbMax==0.90);
    assert(P.inertiaStart==0.90&&P.inertiaEnd==0.40&&P.radiusMin==0.020&&P.radiusMax==0.200);
    assert(P.eliteFraction==0.20&&P.seekCandidateCount==4&&P.seekDimFraction==0.20);
    % --- candidate-type counters ------------------------------------------
    dg=I.CandidateDiagnostics;
    assert(sum(dg.SeekEval)+dg.TraceEval+dg.OtherEval==budget-N, ...
        'SCRun:Diag','Candidate-type evaluation counts do not add up to the budget.');
    assert(dg.TraceEval>0,'SCRun:Diag','The Tracing branch never earned an evaluation.');
    assert(all(dg.SeekEval>=0)&&all(dg.SeekImpPbest<=dg.SeekEval));
    assert(all(dg.SeekImpGlobal<=dg.SeekEval));
    assert(all(dg.SeekEval==0|dg.SeekDistSum>0),'SCRun:Diag','Missing candidate distances.');
    initDrops=sum(diff(T(1:N))<0);
    assert(dg.TraceImpGlobal+sum(dg.SeekImpGlobal)+dg.OtherImpGlobal ...
        ==sum(diff(T)<0)-initDrops,'SCRun:Diag','Global improvements do not match the trace.');
    % --- the variant must actually use the candidate type it claims -------
    if strcmp(job.SeekVariant,'A0')||job.SeekRefineCount==0
        assert(all(dg.SeekEval(2:4)==0),'SCRun:Mode','A baseline run used a refined candidate.');
    else
        % candidate type 1 is the original rule, so A1/A2/A3 map to 2/3/4
        expectType=double(job.SeekVariant(end))-47;
        assert(dg.SeekEval(expectType)>0,'SCRun:Mode','The refined candidate never got evaluated.');
        assert(all(dg.SeekEval(setdiff(2:4,expectType))==0),'SCRun:Mode', ...
            'An unexpected candidate type was evaluated.');
        assert(dg.SeekEval(1)>0,'SCRun:Mode','The original candidates disappeared.');
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
rec.SeekVariantUsed=getfieldor(I,'SeekVariant','');
rec.RefineCountUsed=getfieldor(I,'SeekRefineCount',NaN);
rec.EliteGuideGain=getfieldor(I,'EliteGuideGain',NaN);
di=struct('SeekEval1',0,'SeekEval2',0,'SeekEval3',0,'SeekEval4',0, ...
    'SeekImpPbest1',0,'SeekImpPbest2',0,'SeekImpPbest3',0,'SeekImpPbest4',0, ...
    'SeekImpGlobal1',0,'SeekImpGlobal2',0,'SeekImpGlobal3',0,'SeekImpGlobal4',0, ...
    'SeekDistSum1',0,'SeekDistSum2',0,'SeekDistSum3',0,'SeekDistSum4',0, ...
    'TraceEval',0,'TraceImpPbest',0,'TraceImpGlobal',0, ...
    'OtherEval',0,'OtherImpPbest',0,'OtherImpGlobal',0);
dg=getfieldor(I,'CandidateDiagnostics',struct());
for t=1:4
    rec.(sprintf('SeekEval%d',t))=vecget(dg,'SeekEval',t);
    rec.(sprintf('SeekImpPbest%d',t))=vecget(dg,'SeekImpPbest',t);
    rec.(sprintf('SeekImpGlobal%d',t))=vecget(dg,'SeekImpGlobal',t);
    rec.(sprintf('SeekDistSum%d',t))=vecget(dg,'SeekDistSum',t);
end
for f={'TraceEval','TraceImpPbest','TraceImpGlobal','OtherEval','OtherImpPbest','OtherImpGlobal'}
    rec.(f{1})=getfieldor(dg,f{1},0);
end
rec.Artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Method);
save(fullfile(outDir,'runs',rec.Artifact),'job','rec','B','T','I','state','p0','-v7');

    function v=objective(x)
        calls=calls+1;assert(calls<=budget,'SCRun:OverBudget','Objective call beyond budget.');
        if any(~isfinite(x))||any(x<lb|x>ub)
            outside=outside+1;error('SCRun:Bounds','Nonfinite or outside point');
        end
        v=CEC2017Function(x,job.FunctionID);assert(isscalar(v)&&isfinite(v));
        observedBest=min(observedBest,v);capturedT(calls)=observedBest;
    end

    function v=recheck(x)
        postCalls=postCalls+1;v=CEC2017Function(x,job.FunctionID);
    end
end

function out=vecget(s,key,idx)
out=0;
if isstruct(s)&&isfield(s,key)
    v=s.(key);
    if numel(v)>=idx,out=v(idx);end
end
end

function v=getfieldor(s,key,default)
if isstruct(s)&&isfield(s,key),v=s.(key);else,v=default;end
end
