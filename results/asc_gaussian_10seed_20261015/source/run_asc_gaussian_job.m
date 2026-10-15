function rec=run_asc_gaussian_job(job,cfg,outDir)
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=cfg.Population;D=cfg.Dimension;budget=cfg.Budget;lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,...
 'probeVariant',job.Method,'probeEveryRounds',5,'probeDims',5,'probeSigmaStart',.05,'probeSigmaEnd',.005,'probeSeed',job.ProbeSeed);
calls=0;outside=0;postCalls=0;observedBest=inf;capturedT=nan(budget,1);B=[];T=[];I=[];
status='ok';message='';bestDiff=NaN;probeDiff=NaN;traceDiff=NaN;clock=tic;
try
 [B,T,I]=ASC_NoFarness_EliteGaussian(@objective,state,[],N,job.SearchSeed);seconds=toc(clock);
 assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0)&&outside==0);
 assert(isequal(capturedT,T));traceDiff=max(abs(capturedT-T));
 assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
 bestDiff=abs(recheck(B.Vector)-B.Cost);assert(bestDiff<=1e-10*max(1,abs(B.Cost)));
 P=I.Parameters;R=I.RoundLog;L=I.ProbeLog;
 assert(isequal(I.InitialPopulation,p0)&&P.traceBoostGain==0&&~P.useGroup&&~P.useOBL&&~P.useGaussBest);
 assert(P.useJump&&P.jumpFraction==.50&&P.jumpGens==20&&strcmp(P.jumpUnit,'generation'));
 assert(strcmp(I.ProbeVariant,job.Method)&&P.probeEveryRounds==5&&P.probeDims==5&&P.probeSigmaStart==.05&&P.probeSigmaEnd==.005);
 expected=0;if ~strcmp(job.Method,'A0'),expected=floor(I.Rounds/5);end
 assert(I.ProbeEvaluations==expected&&size(L,1)==expected&&sum(R(:,16))==expected);
 assert(sum(R(:,3))+N==budget&&all(R(:,2)-R(:,1)==R(:,3))&&all(R(:,17)+R(:,16)==R(:,3)));
 assert(all(R(:,13)==R(:,17))&&all(I.ProbeAnchorEligible));probeDiff=0;
 for j=1:expected
  probeDelta=abs(recheck(I.ProbePoints(j,:))-L(j,7));probeDiff=max(probeDiff,probeDelta);
  assert(probeDelta<=1e-10*max(1,abs(L(j,7))));dims=I.ProbeDimensions(j,:);other=setdiff(1:D,dims);
  assert(numel(unique(dims))==5&&isequal(I.ProbeAnchors(j,other),I.ProbePoints(j,other)));
  assert(mod(L(j,2),5)==0&&L(j,13)+1==R(L(j,2),3));
  assert((L(j,7)<L(j,6))==logical(L(j,10))&&(L(j,7)<L(j,8))==logical(L(j,11)));
  if L(j,10),assert(isequal(I.ProbePostPositions(j,:),I.ProbePoints(j,:))&&all(I.ProbePostVelocity(j,:)==0)&&L(j,14)==L(j,7));
  else,assert(isequal(I.ProbePrePositions(j,:),I.ProbePostPositions(j,:))&&L(j,14)==L(j,6));end
 end
catch e
 seconds=toc(clock);status='error';message=getReport(e,'extended','hyperlinks','off');
end
rec=job;rec.Status=status;rec.ErrorMessage=message;rec.Dimension=D;rec.Population=N;rec.Budget=budget;
rec.FinalCost=getfieldor(B,'Cost',NaN);rec.FinalError=rec.FinalCost-100*job.FunctionID;rec.Seconds=seconds;
rec.ObjectiveCalls=calls;rec.Evaluations=getfieldor(I,'Evaluations',NaN);rec.OutsideCalls=outside;rec.PostRunRecheckCalls=postCalls;
rec.BestDiff=bestDiff;rec.ProbeRecheckMaxDiff=probeDiff;rec.ObservedTraceMaxDiff=traceDiff;
rec.Rounds=getfieldor(I,'Rounds',NaN);rec.Jumps=getfieldor(I,'Jumps',NaN);rec.ProbeEvaluations=getfieldor(I,'ProbeEvaluations',NaN);
rec.ProbeParentSuccesses=getfieldor(I,'ProbeParentSuccesses',NaN);rec.ProbeGlobalSuccesses=getfieldor(I,'ProbeGlobalSuccesses',NaN);
rec.Artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Method);
save(fullfile(outDir,'runs',rec.Artifact),'job','rec','B','T','I','state','p0','-v7');
 function v=objective(x)
  calls=calls+1;assert(calls<=budget);
  if any(~isfinite(x))||any(x<lb|x>ub),outside=outside+1;error('Objective:Bounds','Nonfinite or outside point');end
  v=CEC2017Function(x,job.FunctionID);assert(isscalar(v)&&isfinite(v));observedBest=min(observedBest,v);capturedT(calls)=observedBest;
 end
 function v=recheck(x)
  postCalls=postCalls+1;v=CEC2017Function(x,job.FunctionID);
 end
end
function v=getfieldor(s,key,default)
if isstruct(s)&&isfield(s,key),v=s.(key);else,v=default;end
end
