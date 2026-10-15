function record=run_asc_rank_job(job,cfg,outDir)
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
N=50;D=cfg.Dimension;budget=cfg.Budget;lb=-100*ones(1,D);ub=100*ones(1,D);
rng(job.InitSeed,'twister');p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
objectiveCalls=0;outside=0;postCalls=0;B=[];T=[];I=[];status='ok';message='';t=tic;record=job;
try
 if strcmp(job.Method,'ASC-NoFarness'),[B,T,I]=ASC_NoFarness(@objective,state,[],N,job.SearchSeed);
 else,[B,T,I]=ASC_NoFarness_PositionRank(@objective,state,[],N,job.SearchSeed);end
 elapsed=toc(t);assert(objectiveCalls==budget&&I.Evaluations==budget&&numel(T)==budget);
 assert(all(isfinite(T))&&all(diff(T)<=0)&&outside==0);
 assert(all(isfinite(B.Vector))&&all(B.Vector>=lb&B.Vector<=ub));
 bestDiff=abs(recheck(B.Vector)-B.Cost);assert(bestDiff<=1e-10*max(1,abs(B.Cost)));
 assert(isequal(I.InitialPopulation,p0)&&I.Parameters.traceBoostGain==0&&~I.Parameters.useGroup);
 assert(~I.Parameters.useOBL&&~I.Parameters.useGaussBest&&strcmp(I.Parameters.seekNoise,'uniform'));
 assert(sum(I.RoundLog(:,3))+N==budget&&all(I.RoundLog(:,2)-I.RoundLog(:,1)==I.RoundLog(:,3)));
 if isfield(I,'TracingEvaluations'),assert(I.TracingEvaluations+I.SeekingEvaluations+N==budget);end
catch e
 elapsed=toc(t);status='error';message=getReport(e,'extended','hyperlinks','off');bestDiff=NaN;
end
record.FinalCost=getField(B,'Cost',NaN);record.FinalError=record.FinalCost-100*job.FunctionID;
record.Budget=budget;record.Dimension=D;record.Population=N;record.Seconds=elapsed;record.ObjectiveCalls=objectiveCalls;
record.Evaluations=getField(I,'Evaluations',NaN);record.OutsideCalls=outside;record.PostRunRecheckCalls=postCalls;record.BestDiff=bestDiff;
record.Rounds=getField(I,'Rounds',NaN);record.Jumps=getField(I,'Jumps',NaN);
record.TracingEvaluations=getField(I,'TracingEvaluations',NaN);record.SeekingEvaluations=getField(I,'SeekingEvaluations',NaN);
record.Status=status;record.ErrorMessage=message;record.Artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',job.JobID,job.FunctionID,job.Seed,job.Method);
save(fullfile(outDir,'runs',record.Artifact),'job','record','p0','state','B','T','I','-v7');
 function v=objective(x)
  objectiveCalls=objectiveCalls+1;assert(objectiveCalls<=budget);
  if any(~isfinite(x))||any(x<lb|x>ub),outside=outside+1;error('Objective:Bounds','Outside search bounds');end
  v=CEC2017Function(x,job.FunctionID);assert(isscalar(v)&&isfinite(v));
 end
 function v=recheck(x)
  postCalls=postCalls+1;v=CEC2017Function(x,job.FunctionID);
 end
end
function v=getField(s,key,default)
if isstruct(s)&&isfield(s,key),v=s.(key);else,v=default;end
end
