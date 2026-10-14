function record=run_saq_teacher_reward_job(job,cfg,outDir)
% Each run independently counts optimization calls; rechecks are separate.
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=cfg.Population;D=cfg.Dimension;budget=cfg.Budget;
lb=cfg.LowerBound*ones(1,D);ub=cfg.UpperBound*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,...
 'rewardScheme',cfg.RewardScheme,'policy',job.Policy,'acceptance',job.Acceptance,'progressWindowFE',cfg.ProgressWindowFE,...
 'progressThreshold',cfg.ProgressThreshold,'policySeed',job.PolicySeed,'probeSeed',job.ProbeSeed);
objectiveCalls=0;outsideCalls=0;postCalls=0;t0=tic;Best=[];T=[];info=struct();
status='ok';errorID='';errorMessage='';finalCost=NaN;evals=NaN;bestDiff=NaN;realDiff=NaN;pbDiff=NaN;probeDiff=NaN;
error20=NaN;error60=NaN;error80=NaN;finiteTrace=false;monotoneTrace=false;
try
 [Best,T,info]=SAQ_CSO_EliteProbeTeacherReward(@countedObjective,state,[],N,job.SearchSeed);
 secs=toc(t0);finalCost=Best.Cost;evals=info.Evaluations;
 verifyTeacherRewards(info);
 assert(info.TracingEvaluations+info.SeekingEvaluations+N==budget);
 assert(objectiveCalls==budget && evals==budget && numel(T)==budget,'FE:Mismatch');
 finiteTrace=all(isfinite(T));monotoneTrace=all(diff(T)<=0);assert(finiteTrace && monotoneTrace,'Trace:Invalid');
 bestDiff=abs(recheck(Best.Vector)-Best.Cost);actualReal=zeros(N,1);actualPB=zeros(N,1);
 for i=1:N,actualReal(i)=recheck(info.RealPopulation(i,:));actualPB(i)=recheck(info.PersonalBest(i,:));end
 realDiff=max(abs(actualReal-info.Fitness));pbDiff=max(abs(actualPB-info.PersonalBestCost));
 assert(bestDiff<=1e-10*max(1,abs(finalCost)),'Best:Mismatch');
 assert(all(abs(actualReal-info.Fitness)<=1e-10*max(1,abs(info.Fitness))),'RealFitness:Mismatch');
 assert(all(abs(actualPB-info.PersonalBestCost)<=1e-10*max(1,abs(info.PersonalBestCost))),'PersonalBest:Mismatch');
 assert(outsideCalls==0 && info.MaxParentEvaluations<=2,'BudgetOrBound:Invalid');
 probeDiff=0;
 for i=1:info.ProbeEvaluations
  diffValue=abs(recheck(info.ProbePoints(i,:))-info.ProbeLog(i,7));probeDiff=max(probeDiff,diffValue);
  assert(diffValue<=1e-10*max(1,abs(info.ProbeLog(i,7))),'ProbeFitness:Mismatch');
 end
 if strcmp(job.Acceptance,'replace') && info.ProbeEvaluations>0
  assert(isequal(info.ProbePoints,info.ProbeAfterReal) && isequal(info.ProbePoints,info.ProbeAfterPersonalBest),'ProbeWriteback:Mismatch');
  assert(all(info.ProbeAfterVelocity==0,'all') && info.ProbeWritebacks==info.ProbeEvaluations,'ProbeReset:Mismatch');
 end
 error20=T(round(.2*budget))-100*job.FunctionID;error60=T(round(.6*budget))-100*job.FunctionID;error80=T(round(.8*budget))-100*job.FunctionID;
catch e
 secs=toc(t0);status='error';errorID=e.identifier;errorMessage=e.message;
end
artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Method);
record=struct('JobID',job.JobID,'FunctionID',job.FunctionID,'Seed',job.Seed,'Method',job.Method,...
 'Policy',job.Policy,'Acceptance',job.Acceptance,'Dimension',D,'Population',N,'Budget',budget,...
 'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'PolicySeed',job.PolicySeed,'ProbeSeed',job.ProbeSeed,...
 'FinalCost',finalCost,'FinalError',finalCost-100*job.FunctionID,'Error20FE',error20,'Error60FE',error60,'Error80FE',error80,...
 'Evaluations',evals,'ObjectiveCalls',objectiveCalls,'OutsideCalls',outsideCalls,'PostRunRecheckCalls',postCalls,...
 'Seconds',secs,'BestRecheckAbsDiff',bestDiff,'RealFitnessMaxAbsDiff',realDiff,...
 'PersonalBestMaxAbsDiff',pbDiff,'ProbeRecheckMaxAbsDiff',probeDiff,'TraceFinite',finiteTrace,'TraceMonotone',monotoneTrace,...
 'SeekingEvaluations',fieldOr(info,'SeekingEvaluations',NaN),'TracingEvaluations',fieldOr(info,'TracingEvaluations',NaN),...
 'ProbeEvaluations',fieldOr(info,'ProbeEvaluations',NaN),'ProbeParentSuccesses',fieldOr(info,'ProbeParentSuccesses',NaN),...
 'ProbeGlobalSuccesses',fieldOr(info,'ProbeGlobalSuccesses',NaN),'ProbeWritebacks',fieldOr(info,'ProbeWritebacks',NaN),...
 'QUpdates',fieldOr(info,'QUpdates',NaN),'Status',status,'ErrorID',errorID,'ErrorMessage',errorMessage,'Artifact',artifact);
save(fullfile(outDir,'runs',artifact),'job','state','Best','T','info','record','-v7');
 function value=countedObjective(x)
  objectiveCalls=objectiveCalls+1;
  assert(objectiveCalls<=budget,'ObjectiveCalls:BudgetExceeded');
  if any(x<lb | x>ub) || any(~isfinite(x)),outsideCalls=outsideCalls+1;error('ObjectiveCalls:OutsideBounds','Objective called outside bounds.');end
  value=CEC2017Function(x,job.FunctionID);
 end
 function value=recheck(x)
  postCalls=postCalls+1;value=CEC2017Function(x,job.FunctionID);
 end
end
function value=fieldOr(s,name,default)
if isfield(s,name),value=s.(name);else,value=default;end
end

function verifyTeacherRewards(I)
w=I.WindowLog;
for k=1:size(w,1)
 improved=max(0,w(k,13)-w(k,15))>=I.ProgressThreshold*w(k,6);
 expected=-1;if improved,expected=10;elseif w(k,7)>0 && w(k,19)>0,expected=.5;end
 assert(w(k,16)==expected,'Reward:Mismatch');
end
end
