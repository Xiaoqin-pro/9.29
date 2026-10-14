function outDir=run_hpso_dms_30seed(mode)
% Add HPSO-TVAC and SIS2005 base DMS after mandatory audited preflight.
if nargin<1,mode='study';end
assert(ismember(mode,{'study','smoke'}));
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); setup_project(true);
pre=jsondecode(fileread(fullfile(root,'work','pso_baselines_audit_20261013','preflight.json')));assert(pre.Passed && pre.HPSOExactOraclePairs==29 && pre.DMSPaperCoreOraclePairs==29 && pre.DMSPaperInertiaWitness);
assert(strcmp(pre.SourceHashes.HPSO,SourceFileSHA256(fullfile(root,'src','HPSO_TVAC_CEC.m'))));
assert(strcmp(pre.SourceHashes.DMS,SourceFileSHA256(fullfile(root,'src','DMS_PSO_SIS_CEC.m'))));

dataDir=fullfile(root,'data','cec2017'); cd(dataDir);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results','cec',['hpso_dms_30seed_' mode '_' stamp]);
mkdir(outDir); mkdir(fullfile(outDir,'runs')); snap=fullfile(outDir,'source_snapshot'); mkdir(snap);
files={'src/SAQ_CSO.m','src/ASE_CSO_QuotaQ_Candidate.m','src/ASE_CSO_QuotaQ_Compact.m', ...
    'src/CLPSO_CEC_AuthorSource.m','src/HPSO_TVAC_CEC.m','src/DMS_PSO_SIS_CEC.m','src/SourceFileSHA256.m','archive/legacy/CSO_CEC.m', ...
    'archive/legacy/CEC2017Function.m','experiments/run_hpso_dms_30seed.m', ...
    'docs/HPSO_DMS_PROTOCOL_20261013.md'};
for k=1:numel(files)
    target=fullfile(snap,files{k}); if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
    copyfile(fullfile(root,files{k}),target);
end
addpath(fullfile(snap,'src'),'-begin');
work=fullfile(root,'work','pso_baselines_audit_20261013');
copyfile(fullfile(work,'source_provenance.json'),fullfile(snap,'source_provenance.json'));
copyfile(fullfile(work,'preflight.json'),fullfile(snap,'preflight.json'));
copyfile(fullfile(work,'2017-ASOC-EPSO','EPSO Codes','HPSO_TVAC.m'),fullfile(snap,'HPSO_original.m'));
copyfile(fullfile(work,'2005-IEEE-SIS-DMS_PSO_func','DMS_PSO_func.m'),fullfile(snap,'DMS_original_local_search_extension.m'));
copyfile(fullfile(work,'HPSO_ReferenceOracle.m'),fullfile(snap,'HPSO_ReferenceOracle.m'));
copyfile(fullfile(work,'DMS_PaperCoreOracle.m'),fullfile(snap,'DMS_PaperCoreOracle.m'));
copyfile(fullfile(root,'tests','test_HPSO_DMS_baselines.m'),fullfile(snap,'test_HPSO_DMS_baselines.m'));
methods={'HPSO-TVAC-CEC','DMS-PSO-SIS2005'};
functions=[1,3:30]; seeds=3001:3030; budget=100000; N=50; D=50;
if strcmp(mode,'smoke'),functions=[1,13]; seeds=3001:3002; budget=1200;end
jobs=cell(0,1);
for fid=functions
 for seed=seeds
  initSeed=261013000+fid*10000+seed; searchSeed=initSeed+1000000;
  for k=1:numel(methods)
   N=50;if strcmp(methods{k},'DMS-PSO-SIS2005'),N=30;end
   jobs{end+1}=struct('JobID',numel(jobs)+1,'FunctionID',fid,'Seed',seed, ...
      'Budget',budget,'Dimension',D,'Population',N,'Condition',methods{k}, ...
      'InitSeed',initSeed,'SearchSeed',searchSeed); %#ok<AGROW>
  end
 end
end
jobs=[jobs{:}];
cacheDir=fullfile(root,'results','cec','hpso_dms_30seed_study_20261013_110809');
assert(strcmp(SourceFileSHA256(fullfile(cacheDir,'source_snapshot','src','HPSO_TVAC_CEC.m')),pre.SourceHashes.HPSO));
cache=readtable(fullfile(cacheDir,'raw_runs.csv'),'TextType','string');cache=cache(cache.Condition=="HPSO-TVAC-CEC",:);assert(height(cache)==536 && all(cache.Status=="ok"));
environment=struct('MATLAB',version,'Computer',computer,'Dimension',D,'Budget',budget, ...
 'Functions',functions,'Seeds',seeds,'Workers',4,'ThreadsPerWorker',1,'HPSOPopulation',50,'DMSPopulation',30,'InitialPoolSize',50, ...
 'Methods',{methods},'Mode',mode,'Created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
 'Protocol','docs/HPSO_DMS_PROTOCOL_20261013.md','CachedHPSORuns',536,'NewOptimizationRuns',1204);
fid=fopen(fullfile(outDir,'environment.json'),'w');fprintf(fid,'%s',jsonencode(environment,PrettyPrint=true));fclose(fid);
writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
pool=gcp('nocreate'); if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut); fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1); fprintf('OUTDIR %s JOBS %d workers4\n',outDir,numel(jobs));
batchSize=8;
for first=1:batchSize:numel(jobs)
 last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); res=cell(numel(batch),1);
 parfor k=1:numel(batch),res{k}=runOne(batch(k),outDir,cacheDir,cache);end
 records(first:last)=res; raw=struct2table([records{1:last}]);
 writetable(raw,fullfile(outDir,'raw_runs.csv'));
 progress=struct('Completed',last,'Total',numel(jobs),'OK',sum(strcmp(raw.Status,'ok')), ...
  'Failed',sum(~strcmp(raw.Status,'ok')),'Date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
 fid=fopen(fullfile(outDir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress,PrettyPrint=true));fclose(fid);
 fprintf('PROGRESS %d/%d ok%d fail%d %s\n',last,numel(jobs),progress.OK,progress.Failed,progress.Date); assert(progress.Failed==0);
end
fid=fopen(fullfile(outDir,'COMPLETED.json'),'w');fprintf(fid,'%s',jsonencode(struct('Runs',numel(jobs),'Completed',true)));fclose(fid);
fprintf('DONE %s\n',outDir);
end

function rec=runOne(job,outDir,cacheDir,cache)
D=job.Dimension; lb=-100*ones(1,D); ub=100*ones(1,D);
rng(job.InitSeed,'twister'); p0=lb+rand(50,D).*(ub-lb);p0=p0(1:job.Population,:);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget);
rec=job; rec.FinalError=NaN; rec.FinalCost=NaN; rec.Seconds=NaN; rec.Evaluations=NaN;
rec.ObjectiveCalls=NaN; rec.PostRunRecheckCalls=NaN; rec.BestDiff=NaN; rec.InitialCost=NaN;
rec.FirstImprovementEvaluation=NaN; rec.Iterations=NaN; rec.SkippedOutside=NaN; rec.RefreshCount=NaN;
rec.TracingEvaluations=NaN; rec.SeekingEvaluations=NaN; rec.Decisions=NaN; rec.QUpdates=NaN;
rec.ZeroVelocityRestarts=NaN;rec.RegroupCount=NaN;rec.GlobalStartFE=NaN;rec.Action1Share=NaN;rec.Action2Share=NaN;rec.Action3Share=NaN;rec.Status='error';rec.ErrorMessage='';
rec.FromCache=false;rec.CacheRunDirectory='';

if strcmp(job.Condition,'HPSO-TVAC-CEC')&&job.Budget==100000
 match=cache(cache.FunctionID==job.FunctionID & cache.Seed==job.Seed,:);
 if ~isempty(match)
  assert(height(match)==1);cached=load(fullfile(cacheDir,'runs',sprintf('job_%04d.mat',match.JobID)));
  assert(isequal(cached.p0,p0)&&cached.job.SearchSeed==job.SearchSeed&&cached.job.Budget==job.Budget&&cached.rec.Status=="ok");
  B=cached.B;T=cached.T;I=cached.I;assert(numel(T)==job.Budget&&all(isfinite(T))&&all(diff(T)<=0));
  rec=cached.rec;rec.JobID=job.JobID;rec.FromCache=true;rec.CacheRunDirectory=cacheDir;rec=orderfields(rec);
  save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I','p0');return;
 end
end

calls=0; outside=0; B=[]; T=[]; I=[]; start=tic;
try
 switch job.Condition
  case 'Original-CSO-MR02'
   [B,T,I]=CSO_CEC(@capture,state,[],job.Population,job.SearchSeed);
  case 'SAQ-CSO'
   [B,T,I]=SAQ_CSO(@capture,state,[],job.Population,job.SearchSeed);
  case 'CLPSO-AuthorSource'
   [B,T,I]=CLPSO_CEC_AuthorSource(@capture,state,[],job.Population,job.SearchSeed);
  case 'HPSO-TVAC-CEC'
   [B,T,I]=HPSO_TVAC_CEC(@capture,state,[],job.Population,job.SearchSeed);
  case 'DMS-PSO-SIS2005'
   [B,T,I]=DMS_PSO_SIS_CEC(@capture,state,[],job.Population,job.SearchSeed);
  otherwise, error('Unknown condition: %s',job.Condition);
 end
 rec.Seconds=toc(start); rec.ObjectiveCalls=calls; rec.Evaluations=I.Evaluations; rec.OutsideCalls=outside;
 assert(calls==job.Budget && numel(T)==job.Budget && all(isfinite(T)) && all(diff(T)<=0) && outside==0);
 val=capture(B.Vector); rec.PostRunRecheckCalls=calls-rec.ObjectiveCalls; rec.BestDiff=abs(val-B.Cost);
 assert(rec.PostRunRecheckCalls==1 && rec.BestDiff<=1e-8*max(1,abs(B.Cost)));
 rec.InitialCost=T(job.Population); if isfield(I,'InitialCost'),rec.InitialCost=I.InitialCost;end
 rec.FinalCost=B.Cost; rec.FinalError=B.Cost-100*job.FunctionID;
 rec.Error20FE=T(round(.2*job.Budget))-100*job.FunctionID;
 rec.Error60FE=T(round(.6*job.Budget))-100*job.FunctionID;
 rec.Error80FE=T(round(.8*job.Budget))-100*job.FunctionID;
 names={'FirstImprovementEvaluation','Iterations','SkippedOutside','RefreshCount','TracingEvaluations','SeekingEvaluations','Decisions','QUpdates','Action1Share','Action2Share','Action3Share','ZeroVelocityRestarts','RegroupCount','GlobalStartFE'};
 for k=1:numel(names),if isfield(I,names{k}),rec.(names{k})=I.(names{k});end,end
 rec.Status='ok';
catch e
 rec.Seconds=toc(start); rec.ErrorMessage=e.message;
end
rec=orderfields(rec);
save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I','p0');
 function v=capture(x)
  calls=calls+1; outside=outside+double(any(x<lb|x>ub));
  assert(calls<=job.Budget+1 && outside==0 && all(isfinite(x)));
  v=CEC2017Function(x,job.FunctionID); assert(isfinite(v));
 end
end
