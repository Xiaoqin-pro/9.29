function rec=run_asc_jump_job(job,cfg,outDir)
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=50;D=cfg.Dimension;budget=cfg.Budget;lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
 'useJump',logical(job.UseJump),'jumpFraction',job.JumpFraction);
calls=0;outside=0;postCalls=0;observedBest=inf;capturedT=nan(budget,1);
B=[];T=[];I=[];rec=job;status='ok';message='';bestDiff=NaN;traceDiff=NaN;start=tic;
try
 [B,T,I]=ASC_NoFarness(@objective,state,[],N,job.SearchSeed);seconds=toc(start);
 assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0)&&outside==0);
 assert(isequal(capturedT,T));traceDiff=max(abs(capturedT-T));
 assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
 val=CEC2017Function(B.Vector,job.FunctionID);postCalls=postCalls+1;bestDiff=abs(val-B.Cost);assert(bestDiff<=1e-10*max(1,abs(val)));
 assert(isequal(I.InitialPopulation,p0)&&I.Parameters.useJump==job.UseJump&&I.Parameters.jumpFraction==job.JumpFraction);
 assert(I.Parameters.traceBoostGain==0&&~I.Parameters.useGroup&&~I.Parameters.useOBL&&~I.Parameters.useGaussBest);
 R=I.RoundLog;assert(sum(R(:,3))+N==budget&&all(R(:,2)-R(:,1)==R(:,3)));
 assert(I.Jumps==sum(R(:,10))&&numel(I.JumpRounds)==I.Jumps);
 assert(isequal(find(R(:,10)>0),I.JumpRounds(:)));
 if ~job.UseJump,assert(I.Jumps==0);end
catch e
 seconds=toc(start);status='error';message=getReport(e,'extended','hyperlinks','off');
end
rec.Status=status;rec.ErrorMessage=message;rec.Dimension=D;rec.Population=N;rec.Budget=budget;
rec.FinalCost=field(B,'Cost',NaN);rec.FinalError=rec.FinalCost-100*job.FunctionID;rec.Seconds=seconds;
rec.ObjectiveCalls=calls;rec.Evaluations=field(I,'Evaluations',NaN);rec.OutsideCalls=outside;rec.PostRunRecheckCalls=postCalls;rec.BestDiff=bestDiff;rec.ObservedTraceMaxDiff=traceDiff;
rec.Jumps=field(I,'Jumps',NaN);rec.Rounds=field(I,'Rounds',NaN);
rec.Artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Method);
save(fullfile(outDir,'runs',rec.Artifact),'job','rec','B','T','I','state','p0','-v7');
 function v=objective(x)
  calls=calls+1;assert(calls<=budget);
  if any(~isfinite(x))||any(x<lb|x>ub),outside=outside+1;error('Objective:Bounds','Nonfinite or outside point');end
  v=CEC2017Function(x,job.FunctionID);assert(isscalar(v)&&isfinite(v));observedBest=min(observedBest,v);capturedT(calls)=observedBest;
 end
end
function v=field(s,key,default)
if isstruct(s)&&isfield(s,key),v=s.(key);else,v=default;end
end
