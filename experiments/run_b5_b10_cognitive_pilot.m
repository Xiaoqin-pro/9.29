clc
clear
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy'));
dataDir=fullfile(root,'data','cec2017'); cd(dataDir);
functionIDs=[1 3 6 9 12 22]; seeds=101:103; D=30; N=50; maxEvaluations=60000; lb=-100; ub=100; workerCount=4; batchSize=4; methods={'ASE-CSO-B5','ASE-CSO-B10','ASE-CSO-B10-Cognitive'};
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss')); outDir=fullfile(root,'results','cec',['ase_b5_b10_cognitive_pilot_' stamp]); mkdir(outDir);
seedBase=20271011; jobs=struct('FunctionID',{},'Run',{},'Seed',{},'Method',{},'InitSeed',{},'SearchSeed',{}); c=0;
for fid=functionIDs
 for r=1:numel(seeds)
  seed=seeds(r); initSeed=seedBase+fid*1000+seed; searchSeed=initSeed+100000;
  for m=1:numel(methods)
   c=c+1; jobs(c)=struct('FunctionID',fid,'Run',r,'Seed',seed,'Method',methods{m},'InitSeed',initSeed,'SearchSeed',searchSeed);
  end
 end
end
pool=gcp('nocreate'); if isempty(pool), parpool('local',workerCount); elseif pool.NumWorkers~=workerCount, delete(pool); parpool('local',workerCount); end
records=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
 last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); batchResults=cell(numel(batch),1);
 parfor j=1:numel(batch)
  job=batch(j); rng(job.InitSeed,'twister'); pop0=lb+rand(N,D).*(ub-lb); state=struct('lowerBound',lb*ones(1,D),'upperBound',ub*ones(1,D),'maxEvaluations',maxEvaluations,'initialPopulation',pop0); f=@(x)CEC2017Function(x,job.FunctionID); status='ok'; errID=''; errMsg=''; finalCost=NaN; evals=NaN; secs=NaN; recheckDiff=NaN; traceFinite=false; traceMonotone=false; error20=NaN; error60=NaN; error80=NaN;
  try
   t0=tic; if strcmp(job.Method,'ASE-CSO-B5'), [Best,T,info]=ASE_CSO_Lean(f,state,[],N,job.SearchSeed); elseif strcmp(job.Method,'ASE-CSO-B10'), [Best,T,info]=ASE_CSO_Lean_B10(f,state,[],N,job.SearchSeed); else, [Best,T,info]=ASE_CSO_Lean_B10_Cognitive(f,state,[],N,job.SearchSeed); end; secs=toc(t0); finalCost=Best.Cost; evals=info.Evaluations; recheckDiff=abs(f(Best.Vector)-finalCost); bias=100*job.FunctionID; error20=T(round(.2*maxEvaluations))-bias; error60=T(round(.6*maxEvaluations))-bias; error80=T(round(.8*maxEvaluations))-bias; traceFinite=all(isfinite(T)); traceMonotone=all(diff(T)<=0); if evals~=maxEvaluations || numel(T)~=maxEvaluations, status='invalid'; errID='FE:Mismatch'; errMsg='FE or trace length mismatch'; elseif ~traceFinite || ~traceMonotone, status='invalid'; errID='Trace:Invalid'; errMsg='trace invalid'; end
  catch e, status='error'; errID=e.identifier; errMsg=e.message; secs=toc(t0); end
  batchResults{j}=struct('FunctionID',job.FunctionID,'Function',sprintf('F%02d',job.FunctionID),'Run',job.Run,'Seed',job.Seed,'Dimension',D,'Method',job.Method,'Population',N,'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'Budget',maxEvaluations,'FinalCost',finalCost,'FinalError',finalCost-100*job.FunctionID,'Error20FE',error20,'Error60FE',error60,'Error80FE',error80,'Evaluations',evals,'Seconds',secs,'BestRecheckAbsDiff',recheckDiff,'TraceFinite',traceFinite,'TraceMonotone',traceMonotone,'Status',status,'ErrorID',errID,'ErrorMessage',errMsg);
 end
 records(first:last)=batchResults; writetable(struct2table([records{1:last}]),fullfile(outDir,'raw_runs.csv')); fprintf('Completed %d/%d runs\n',last,numel(jobs));
end
writetable(struct2table([records{:}]),fullfile(outDir,'raw_runs.csv')); fprintf('Saved %s\n',outDir);

