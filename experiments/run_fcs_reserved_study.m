function outDir=run_fcs_reserved_study(mode,selected)
% One reserved real FE: exact Keep baseline, independent policy stream.
if nargin<1,mode='study';end
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);dataDir=fullfile(root,'data','cec2017');cd(dataDir);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));outDir=fullfile(root,'results','cec',['fcs_reserved_' mode '_' stamp]);mkdir(outDir);mkdir(fullfile(outDir,'runs'));sourceDir=fullfile(outDir,'source_snapshot');mkdir(sourceDir);
files={'src/ASE_CSO_ReservedEval.m','src/+fcs/updateCredit.m','src/ASE_CSO_Lean_B10.m','archive/legacy/CEC2017Function.m','experiments/run_fcs_reserved_study.m','docs/FCS_RESERVED_STUDY_PROTOCOL_20261012.md','tests/test_FCS_reserved.m'};
for k=1:numel(files),target=fullfile(sourceDir,files{k});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end;copyfile(fullfile(root,files{k}),target);end
addpath(fullfile(sourceDir,'src'),fullfile(sourceDir,'archive','legacy'));
conditions={'Explore','Random','Progress','Reverse','Q1-g0','Q1-g9','Q10-g0','Q10-g9'};functions=[1,3,6,9,12,13,22,30];seeds=901:905;budget=60000;
if strcmp(mode,'smoke'),functions=1;seeds=901;budget=600;
elseif strcmp(mode,'confirm'),assert(nargin>=2);conditions={'Keep','Explore','Random','Progress','Reverse',selected,'B10'};seeds=1001:1010;
else,assert(strcmp(mode,'study'));end
jobs=cell(0,1);
for fid=functions
 for seed=seeds
  for c=1:numel(conditions)
   condition=conditions{c};[policy,bonus,gamma]=configuration(condition);initSeed=20701012+fid*10000+seed;
   jobs{end+1}=struct('JobID',numel(jobs)+1,'Cohort',mode,'FunctionID',fid,'Seed',seed,'Dimension',30,'Budget',budget,'Condition',condition,'Policy',policy,'RewardMode','global_binary','RewardBonus',bonus,'Gamma',gamma,'Alpha',.1,'Epsilon',.1,'GainScaleDecay',.1,'InitSeed',initSeed,'SearchSeed',initSeed+1000000); %#ok<AGROW>
  end
 end
end
jobs=[jobs{:}];writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut);fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1);fprintf('OUTDIR %s JOBS %d workers4%c',outDir,numel(jobs),10);
for first=1:12:numel(jobs)
 last=min(first+11,numel(jobs));batch=jobs(first:last);results=cell(numel(batch),1);
 parfor j=1:numel(batch),results{j}=runOne(batch(j),outDir);end
 records(first:last)=results;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));save(fullfile(outDir,'checkpoint.mat'),'records','jobs');
 progress=struct('Completed',last,'Total',numel(jobs),'OK',sum(strcmp(raw.Status,'ok')),'Failed',sum(~strcmp(raw.Status,'ok')),'Date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
 fid=fopen(fullfile(outDir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress,PrettyPrint=true));fclose(fid);fprintf('PROGRESS %d/%d ok%d fail%d time%s%c',last,numel(jobs),progress.OK,progress.Failed,progress.Date,10);
 assert(progress.Failed==0,'Reward study invalid run.');
end
fid=fopen(fullfile(outDir,'COMPLETED.json'),'w');fprintf(fid,'%s',jsonencode(struct('Runs',numel(jobs),'Completed',true)));fclose(fid);fprintf('DONE %s%c',outDir,10);
end
function [policy,bonus,gamma]=configuration(name)
policy='q';bonus=1;gamma=0;
switch name
 case 'B10',policy='b10';return
 case 'Keep',policy='keep';return
 case 'Explore',policy='explore';return
 case 'Random',policy='random';return
 case 'Progress',policy='progress';return
 case 'Reverse',policy='reverse';return
end
assert(startsWith(name,'Q1-') || startsWith(name,'Q10-'));if startsWith(name,'Q10-'),bonus=10;end
if endsWith(name,'g9'),gamma=.9;else,assert(endsWith(name,'g0'));end
end
function rec=runOne(job,outDir)
D=job.Dimension;lb=-100*ones(1,D);ub=100*ones(1,D);rng(job.InitSeed,'twister');p0=lb+rand(50,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget,'reservePolicy',job.Policy,'rewardMode',job.RewardMode,'rewardBonus',job.RewardBonus,'gamma',job.Gamma,'alpha',job.Alpha,'epsilon',job.Epsilon,'gainScaleDecay',job.GainScaleDecay,'auditDecisions',false);
calls=0;outside=0;rec=job;rec.FinalCost=NaN;rec.FinalError=NaN;rec.Seconds=NaN;rec.Evaluations=NaN;rec.ObjectiveCalls=NaN;rec.PostRunRecheckCalls=NaN;rec.OutsideCalls=NaN;rec.BestDiff=NaN;rec.TraceFinite=false;rec.TraceMonotone=false;
fields={'MeanParentCoverage','MeanPlannedCoverage','Decisions','FreeDecisions','ForcedKeep','QUpdates','GlobalLastSuccesses','GlobalLastGain','ActualMaxParentEvaluations'};
for k=1:numel(fields),rec.(fields{k})=NaN;end
rec.KeepCount=NaN;rec.ExploreCount=NaN;rec.Status='error';rec.ErrorID='';rec.ErrorMessage='';B=[];T=[];I=[];started=tic;
try
 if strcmp(job.Policy,'b10'),[B,T,I]=ASE_CSO_Lean_B10(@capture,state,[],50,job.SearchSeed);
 else,[B,T,I]=ASE_CSO_ReservedEval(@capture,state,[],50,job.SearchSeed);end
 rec.Seconds=toc(started);callsRun=calls;rec.Evaluations=I.Evaluations;rec.ObjectiveCalls=callsRun;rec.OutsideCalls=outside;rec.TraceFinite=all(isfinite(T));rec.TraceMonotone=all(diff(T)<=0);
 assert(callsRun==job.Budget && I.Evaluations==job.Budget && numel(T)==job.Budget && outside==0 && rec.TraceFinite && rec.TraceMonotone);
 check=capture(B.Vector);rec.PostRunRecheckCalls=calls-callsRun;rec.BestDiff=abs(check-B.Cost);assert(rec.PostRunRecheckCalls==1 && rec.BestDiff<=1e-8*max(1,abs(B.Cost)));
 rec.FinalCost=B.Cost;rec.FinalError=B.Cost-100*job.FunctionID;
 if ~strcmp(job.Policy,'b10')
  assert(~I.PendingAtEnd && I.ActualMaxParentEvaluations<=2);
  if strcmp(job.Policy,'q'),assert(I.QUpdates==sum(I.QVisits) && I.QUpdates==I.FreeDecisions);else,assert(I.QUpdates==0);end
  for k=1:numel(fields),rec.(fields{k})=I.(fields{k});end
  rec.KeepCount=I.ActionCounts(1);rec.ExploreCount=I.ActionCounts(2);
 end
 rec.Status='ok';
catch e,rec.Seconds=toc(started);rec.ObjectiveCalls=calls;rec.OutsideCalls=outside;rec.ErrorID=e.identifier;rec.ErrorMessage=e.message;end
save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I','p0');
 function value=capture(x)
  calls=calls+1;outside=outside+double(any(x<lb | x>ub));assert(calls<=job.Budget+1 && outside==0 && all(isfinite(x)));value=CEC2017Function(x,job.FunctionID);assert(isscalar(value) && isfinite(value));
 end
end
