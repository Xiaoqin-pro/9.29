function rec=run_asc_dt_job(job,cfg,outDir)
%RUN_ASC_DT_JOB  深开发 / 速度重置单因素运行
%
%   只改两个与"开发强度"有关的开关，其余（配额 9:1、候选生成、Jump、自适应半径、
%   精英池、父代名额上限、总预算）与配额实现完全一致：
%     UseAdaptiveProb = 0 时，Seeking 概率固定为 SeekProbFixed（即 Tracing 比例
%     固定为 1-SeekProbFixed）；= 1 时沿用 ASC 的自适应律。
%     ResetVelOnSeek = 0 时，Seeking 轮不再清零速度，用于分离"Tracing 比例"与
%     "速度重置"两个效应。
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=cfg.Population;D=cfg.Dimension;budget=cfg.Budget;
lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub, ...
    'maxEvaluations',budget,'nearShare',job.NearShare, ...
    'useAdaptiveProb',logical(job.UseAdaptiveProb), ...
    'resetVelOnSeek',logical(job.ResetVelOnSeek));
if ~job.UseAdaptiveProb, state.seekProbFixed=job.SeekProbFixed; end
calls=0;outside=0;postCalls=0;observedBest=inf;capturedT=nan(budget,1);
B=[];T=[];I=[];status='ok';message='';bestDiff=NaN;traceDiff=NaN;clock=tic;
try
    [B,T,I]=ASC_NoFarness_DeepTracing(@objective,state,[],N,job.SearchSeed);
    seconds=toc(clock);
    assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget, ...
        'DTRun:Budget','Unexpected evaluation count.');
    assert(all(isfinite(T))&&all(diff(T)<=0)&&outside==0,'DTRun:Trace','Invalid trace.');
    assert(isequal(capturedT,T));traceDiff=max(abs(capturedT-T));
    assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
    bestDiff=abs(recheck(B.Vector)-B.Cost);
    assert(bestDiff<=1e-10*max(1,abs(B.Cost)),'DTRun:Best','Best value did not recheck.');
    P=I.Parameters;RL=I.RoundLog;
    assert(P.nearShare==job.NearShare&&I.NearShare==job.NearShare);
    assert(P.useAdaptiveProb==logical(job.UseAdaptiveProb));
    assert(P.resetVelOnSeek==logical(job.ResetVelOnSeek));
    if ~job.UseAdaptiveProb
        assert(abs(P.seekProbFixed-job.SeekProbFixed)<1e-12, ...
            'DTRun:Params','The fixed seeking probability was not applied.');
        assert(all(abs(RL(:,4)-job.SeekProbFixed)<1e-12), ...
            'DTRun:Params','Round-log seeking probability deviates from the fixed value.');
    end
    assert(P.useJump&&P.jumpFraction==0.50&&P.jumpGens==20&&strcmp(P.jumpUnit,'generation'));
    assert(~P.useGroup&&~P.useOBL&&~P.useGaussBest&&P.useAdaptiveRadius);
    assert(P.evaluationsPerRound==10&&P.perOwnerCap==2&&P.seekCandidateCount==4);
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
if isstruct(I)&&isfield(I,'RoundLog')
    RL=I.RoundLog;
    rec.MeanSeekProb=mean(RL(:,4));
    rec.MeanTracingFrac=1-rec.MeanSeekProb;
    rec.MeanRadius=mean(RL(:,5));
    rec.EarlySeekProb=mean(RL(1:min(500,end),4));
    rec.LateSeekProb=mean(RL(max(1,end-499):end,4));
end
rec.Artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Tag);
save(fullfile(outDir,'runs',rec.Artifact),'job','rec','B','T','I','state','p0','-v7');

    function v=objective(x)
        calls=calls+1;assert(calls<=budget,'DTRun:OverBudget','Objective call beyond budget.');
        if any(~isfinite(x))||any(x<lb|x>ub)
            outside=outside+1;error('DTRun:Bounds','Nonfinite or outside point');
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
