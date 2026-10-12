function outDir=run_fcs_repaired_pilot(mode)
% Frozen-source FCS execution repair pilot, four process workers.
if nargin<1,mode='full';end
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);dataDir=fullfile(root,'data','cec2017');cd(dataDir);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));outDir=fullfile(root,'results','cec',['fcs_repaired_' mode '_' stamp]);mkdir(outDir);mkdir(fullfile(outDir,'runs'));
sourceDir=fullfile(outDir,'source_snapshot');mkdir(sourceDir);sources={'src/ASE_CSO_FCSQ.m','src/ASE_CSO_Lean_B10.m','archive/legacy/CEC2017Function.m','experiments/run_fcs_repaired_pilot.m','docs/FCS_REPAIR_PROTOCOL_20261012.md','tests/test_FCS_repair.m'};
for k=1:numel(sources),target=fullfile(sourceDir,sources{k});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end;copyfile(fullfile(root,sources{k}),target);end
addpath(fullfile(sourceDir,'src'),fullfile(sourceDir,'archive','legacy'));
policies={'batch','continue','switch','random','success','reverse','q'};methods={'B10-Reference','FCS-batch','FCS-continue','FCS-switch','FCS-random','FCS-success','FCS-reverse','FCS-q'};jobs=cell(0,1);
if strcmp(mode,'smoke')
 jobs=appendJobs(jobs,'smoke',[1,6],901,600,methods,false);
else
 diagMethods=cellfun(@(p)['FCS-' p],policies,'UniformOutput',false);
 jobs=appendJobs(jobs,'diagnostic',[1,6,12],901,12000,diagMethods,true);
 jobs=appendJobs(jobs,'pilot',[1,3,6,9,12,13,22,30],901:905,60000,methods,false);
end
jobs=[jobs{:}];writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut);fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1);fprintf('OUTDIR %s JOBS %d workers4%c',outDir,numel(jobs),10);
for first=1:12:numel(jobs)
 last=min(first+11,numel(jobs));batch=jobs(first:last);r=cell(numel(batch),1);
 parfor j=1:numel(batch),r{j}=runOne(batch(j),outDir);end
 records(first:last)=r;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));save(fullfile(outDir,'checkpoint.mat'),'records','jobs');
 progress=struct('Completed',last,'Total',numel(jobs),'OK',sum(strcmp(raw.Status,'ok')),'Failed',sum(~strcmp(raw.Status,'ok')),'Cohort',batch(end).Cohort,'Date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
 fid=fopen(fullfile(outDir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress,PrettyPrint=true));fclose(fid);
 fprintf('PROGRESS %d/%d ok%d fail%d cohort%s time%s%c',last,numel(jobs),progress.OK,progress.Failed,progress.Cohort,progress.Date,10);
 assert(progress.Failed==0,'Invalid FCS pilot run; inspect CSV and MAT.');
end
fid=fopen(fullfile(outDir,'COMPLETED.json'),'w');fprintf(fid,'%s',jsonencode(struct('Runs',numel(jobs),'Completed',true),PrettyPrint=true));fclose(fid);fprintf('DONE %s%c',outDir,10);
end
function jobs=appendJobs(jobs,cohort,functions,seeds,budget,methods,audit)
for fid=functions
 for seed=seeds
  for m=1:numel(methods)
   initSeed=20701012+fid*10000+seed;searchSeed=initSeed+1000000;
   jobs{end+1}=struct('JobID',numel(jobs)+1,'Cohort',cohort,'FunctionID',fid,'Seed',seed,'Method',methods{m},'Dimension',30,'Budget',budget,'InitSeed',initSeed,'SearchSeed',searchSeed,'AuditDecisions',audit); %#ok<AGROW>
  end
 end
end
end
function rec=runOne(job,outDir)
D=job.Dimension;lb=-100*ones(1,D);ub=100*ones(1,D);rng(job.InitSeed,'twister');p0=lb+rand(50,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget,'auditDecisions',job.AuditDecisions);calls=0;outside=0;
rec=job;rec.FinalCost=NaN;rec.FinalError=NaN;rec.Seconds=NaN;rec.Evaluations=NaN;rec.ObjectiveCalls=NaN;rec.OutsideCalls=NaN;rec.PostRunRecheckCalls=NaN;rec.BestDiff=NaN;rec.TraceFinite=false;rec.TraceMonotone=false;rec.Error20FE=NaN;rec.Error60FE=NaN;rec.Error80FE=NaN;
fields={'Rounds','TracingEvaluations','SeekingEvaluations','ContinueCount','SwitchCount','FallbackCount','ActionMismatchCount','QFallbackUpdates','SameParentSecondEvaluations','OtherParentSecondEvaluations','OpenedParentEvaluations','FirstVisitEvaluations','ActualMaxParentEvaluations','MeanParentCoverage','SecondEvaluationSuccesses','SeekSuccesses','TraceSuccesses'};
for k=1:numel(fields),rec.(fields{k})=NaN;end
rec.ExecutedContinue=NaN;rec.ExecutedSwitch=NaN;rec.QUpdates=NaN;rec.DecisionRows=NaN;rec.Status='error';rec.ErrorID='';rec.ErrorMessage='';B=[];T=[];I=[];started=tic;
try
 if strcmp(job.Method,'B10-Reference'),[B,T,I]=ASE_CSO_Lean_B10(@capture,state,[],50,job.SearchSeed);
 else,state.fcsPolicy=char(extractAfter(job.Method,'FCS-'));[B,T,I]=ASE_CSO_FCSQ(@capture,state,[],50,job.SearchSeed);end
 rec.Seconds=toc(started);callsRun=calls;rec.Evaluations=I.Evaluations;rec.ObjectiveCalls=callsRun;rec.OutsideCalls=outside;rec.TraceFinite=all(isfinite(T));rec.TraceMonotone=all(diff(T)<=0);
 assert(callsRun==job.Budget && I.Evaluations==job.Budget && numel(T)==job.Budget && outside==0 && rec.TraceFinite && rec.TraceMonotone);
 check=capture(B.Vector);rec.PostRunRecheckCalls=calls-callsRun;rec.BestDiff=abs(check-B.Cost);assert(rec.PostRunRecheckCalls==1 && rec.BestDiff<=1e-8*max(1,abs(B.Cost)));
 rec.FinalCost=B.Cost;rec.FinalError=B.Cost-100*job.FunctionID;rec.Error20FE=T(round(.2*job.Budget))-100*job.FunctionID;rec.Error60FE=T(round(.6*job.Budget))-100*job.FunctionID;rec.Error80FE=T(round(.8*job.Budget))-100*job.FunctionID;
 for k=1:numel(fields),rec.(fields{k})=fieldOr(I,fields{k},NaN);end
 assert(rec.TracingEvaluations+rec.SeekingEvaluations==job.Budget-50);
 if ~strcmp(job.Method,'B10-Reference')
  assert(I.ActualMaxParentEvaluations<=2 && I.Rounds==ceil((job.Budget-50)/10));
  assert(I.ActionMismatchCount==0 && I.QFallbackUpdates==0,'Unexecuted action would receive Q credit.');
  rec.ExecutedContinue=I.ExecutedActionCounts(1);rec.ExecutedSwitch=I.ExecutedActionCounts(2);rec.QUpdates=sum(I.QVisits);rec.DecisionRows=size(I.DecisionLog,1);
  if strcmp(state.fcsPolicy,'continue'),assert(I.ExecutedActionCounts(2)==0 && I.SameParentSecondEvaluations==I.ContinueCount);end
  if strcmp(state.fcsPolicy,'switch'),assert(I.ExecutedActionCounts(1)==0);end
 end
 rec.Status='ok';
catch e,rec.Seconds=toc(started);rec.ObjectiveCalls=calls;rec.OutsideCalls=outside;rec.ErrorID=e.identifier;rec.ErrorMessage=e.message;end
save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I');
 function value=capture(x)
  calls=calls+1;outside=outside+double(any(x<lb | x>ub));assert(calls<=job.Budget+1 && outside==0 && all(isfinite(x)));value=CEC2017Function(x,job.FunctionID);assert(isscalar(value) && isfinite(value));
 end
end
function value=fieldOr(s,name,default)
if isfield(s,name),value=s.(name);else,value=default;end
end
