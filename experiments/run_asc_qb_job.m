function rec=run_asc_qb_job(job,cfg,outDir)
%RUN_ASC_QB_JOB  One counted quota-balance run.
%
% The only thing this variant changes is how the fixed round quota is split
% between the two geometry screening phases.  Everything else - candidate
% generation, Tracing, Jump, the adaptive control and the budget - is the frozen
% ASC-NoFarness code, and nearShare = 0.5 reproduces it exactly.
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=cfg.Population;D=cfg.Dimension;budget=cfg.Budget;
lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub, ...
    'maxEvaluations',budget,'nearShare',job.NearShare);
calls=0;outside=0;postCalls=0;observedBest=inf;capturedT=nan(budget,1);
B=[];T=[];I=[];status='ok';message='';bestDiff=NaN;traceDiff=NaN;clock=tic;
try
    [B,T,I]=ASC_NoFarness_QuotaBalance(@objective,state,[],N,job.SearchSeed);
    seconds=toc(clock);
    assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget, ...
        'QBRun:Budget','Unexpected evaluation count.');
    assert(all(isfinite(T))&&all(diff(T)<=0)&&outside==0,'QBRun:Trace','Invalid trace.');
    assert(isequal(capturedT,T));traceDiff=max(abs(capturedT-T));
    assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
    bestDiff=abs(recheck(B.Vector)-B.Cost);
    assert(bestDiff<=1e-10*max(1,abs(B.Cost)),'QBRun:Best','Best value did not recheck.');
    P=I.Parameters;
    assert(P.nearShare==job.NearShare&&I.NearShare==job.NearShare, ...
        'QBRun:Params','The quota split was not applied.');
    assert(P.traceBoostGain==0&&P.seekEliteGain==0,'QBRun:Params','A search term changed.');
    assert(P.useJump&&P.jumpFraction==0.50&&P.jumpGens==20&&strcmp(P.jumpUnit,'generation'));
    assert(~P.useGroup&&~P.useOBL&&~P.useGaussBest&&~strcmp(P.seekNoise,'gaussian'));
    assert(P.useAdaptiveRadius&&P.useAdaptiveProb&&P.slownessInvert&&P.logRounds==false);
    assert(P.evaluationsPerRound==10&&P.perOwnerCap==2&&P.seekCandidateCount==4);
    assert(P.inertiaStart==0.90&&P.inertiaEnd==0.40&&P.radiusMin==0.020&&P.radiusMax==0.200);
    assert(P.eliteFraction==0.20&&P.seekDimFraction==0.20&&P.convWindowRounds==100);
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
rec.NearShareUsed=getfieldor(I,'NearShare',NaN);
rec.Artifact=sprintf('run_%04d_F%02d_seed%d_Q%d.mat',job.JobID,job.FunctionID, ...
    job.Seed,round(job.NearShare*100));
save(fullfile(outDir,'runs',rec.Artifact),'job','rec','B','T','I','state','p0','-v7');

    function v=objective(x)
        calls=calls+1;assert(calls<=budget,'QBRun:OverBudget','Objective call beyond budget.');
        if any(~isfinite(x))||any(x<lb|x>ub)
            outside=outside+1;error('QBRun:Bounds','Nonfinite or outside point');
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
