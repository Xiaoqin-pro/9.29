clc; clear;
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));addpath(fullfile(root,'archive','legacy'));
dataDir=fullfile(root,'data','cec2017');cd(dataDir);
functionIDs=[1 6 9 12 13 21 22 30];seeds=701:710;D=50;N=50;maxEvaluations=100000;lb=-100;ub=100;workerCount=4;batchSize=4;
methods={'Sparse-Base','Fixed-Restart','Random-Restart','Q-Restart'};
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));outDir=fullfile(root,'results','cec',['saq_restart_pilot_' stamp]);mkdir(outDir);
seedBase=20301013;jobs=struct('FunctionID',{},'Run',{},'Seed',{},'Method',{},'InitSeed',{},'SearchSeed',{});c=0;
for fid=functionIDs
 for r=1:numel(seeds)
  seed=seeds(r);initSeed=seedBase+fid*1000+seed;searchSeed=initSeed+100000;
  for m=1:numel(methods),c=c+1;jobs(c)=struct('FunctionID',fid,'Run',r,'Seed',seed,'Method',methods{m},'InitSeed',initSeed,'SearchSeed',searchSeed);end
 end
end
pool=gcp('nocreate');if isempty(pool),parpool('local',workerCount);elseif pool.NumWorkers~=workerCount,delete(pool);parpool('local',workerCount);end
records=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
 last=min(first+batchSize-1,numel(jobs));batch=jobs(first:last);batchResults=cell(numel(batch),1);
 parfor j=1:numel(batch)
  job=batch(j);t0=tic;rng(job.InitSeed,'twister');pop0=lb+rand(N,D).*(ub-lb);
  policyMap=struct('Sparse_Base','base','Fixed_Restart','fixed','Random_Restart','random','Q_Restart','q');
  key=strrep(job.Method,'-','_');state=struct('initialPopulation',pop0,'lowerBound',lb*ones(1,D),'upperBound',ub*ones(1,D),'maxEvaluations',maxEvaluations,'policy',policyMap.(key));
  f=@(x)CEC2017Function(x,job.FunctionID);status='ok';errID='';errMsg='';finalCost=NaN;evals=NaN;secs=NaN;recheckDiff=NaN;traceFinite=false;traceMonotone=false;error20=NaN;error60=NaN;error80=NaN;info=struct();
  try
   [Best,T,info]=SAQ_CSO_RestartQ(f,state,[],N,job.SearchSeed);finalCost=Best.Cost;evals=info.Evaluations;secs=toc(t0);recheckDiff=abs(f(Best.Vector)-finalCost);bias=100*job.FunctionID;
   error20=T(round(.2*maxEvaluations))-bias;error60=T(round(.6*maxEvaluations))-bias;error80=T(round(.8*maxEvaluations))-bias;traceFinite=all(isfinite(T));traceMonotone=all(diff(T)<=1e-10);
   if evals~=maxEvaluations||numel(T)~=maxEvaluations,status='invalid';errID='FE:Mismatch';errMsg='FE or trace length mismatch';elseif ~traceFinite||~traceMonotone,status='invalid';errID='Trace:Invalid';errMsg='trace invalid';elseif recheckDiff>1e-7*max(1,abs(finalCost)),status='invalid';errID='Best:Mismatch';errMsg='best recheck mismatch';end
  catch e,secs=toc(t0);status='error';errID=e.identifier;errMsg=e.message;end
  batchResults{j}=struct('FunctionID',job.FunctionID,'Function',sprintf('F%02d',job.FunctionID),'Run',job.Run,'Seed',job.Seed,'Dimension',D,'Method',job.Method,'Population',N,'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'Budget',maxEvaluations,'FinalCost',finalCost,'FinalError',finalCost-100*job.FunctionID,'Error20FE',error20,'Error60FE',error60,'Error80FE',error80,'Evaluations',evals,'Seconds',secs,'BestRecheckAbsDiff',recheckDiff,'TraceFinite',traceFinite,'TraceMonotone',traceMonotone,'Status',status,'ErrorID',errID,'ErrorMessage',errMsg,'SeekingEvaluations',fieldOr(info,'SeekingEvaluations',NaN),'TracingEvaluations',fieldOr(info,'TracingEvaluations',NaN),'RestartEvaluations',fieldOr(info,'RestartEvaluations',NaN),'RestartSuccesses',fieldOr(info,'RestartSuccesses',NaN),'RestartParentSuccesses',fieldOr(info,'RestartParentSuccesses',NaN),'MeanRestartCandidateDistance',fieldOr(info,'MeanRestartCandidateDistance',NaN),'RestartWindows',fieldOr(info,'RestartWindows',NaN),'QUpdates',fieldOr(info,'QUpdates',NaN),'ActionNormal',actionValue(info,1),'ActionRestart',actionValue(info,2),'MeanParentCoverage',fieldOr(info,'MeanParentCoverage',NaN));
 end
 records(first:last)=batchResults;writetable(struct2table([records{1:last}]),fullfile(outDir,'raw_runs.csv'));fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end
raw=struct2table([records{:}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));copyfile(fullfile(root,'src','SAQ_CSO_RestartQ.m'),fullfile(outDir,'SAQ_CSO_RestartQ.m'));fprintf('Saved %s\n',outDir);
function value=fieldOr(s,name,default),if isfield(s,name),value=s.(name);else,value=default;end,end
function value=actionValue(s,k),value=NaN;if isfield(s,'ActionCounts')&&numel(s.ActionCounts)>=k,value=s.ActionCounts(k);end,end
