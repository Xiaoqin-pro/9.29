function outDir=run_saq_cso_formal_100k_30seed(mode)
% Formal D50/100k/30-seed comparison for SAQ-CSO, CSO, CLPSO, HCLPSO.
if nargin<1,mode='study';end
assert(ismember(mode,{'study','smoke'}));
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); setup_project(true);
dataDir=fullfile(root,'data','cec2017'); cd(dataDir);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results','cec',['saq_cso_formal_100k_30seed_' mode '_' stamp]);
mkdir(outDir); mkdir(fullfile(outDir,'runs')); snap=fullfile(outDir,'source_snapshot'); mkdir(snap);
files={'src/SAQ_CSO.m','src/ASE_CSO_QuotaQ_Candidate.m','src/ASE_CSO_QuotaQ_Compact.m', ...
    'src/CLPSO_CEC_AuthorSource.m','src/HCLPSO_CEC_Reference.m','archive/legacy/CSO_CEC.m', ...
    'archive/legacy/CEC2017Function.m','experiments/run_saq_cso_formal_100k_30seed.m', ...
    'docs/SAQ_CSO_FORMAL_COMPARISON_PROTOCOL_20261013.md'};
for k=1:numel(files)
    target=fullfile(snap,files{k}); if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
    copyfile(fullfile(root,files{k}),target);
end
refSrc=fullfile(root,'work','external','neorl_source_20261013','neorl','evolu','hclpso.py');
refDoc=fullfile(root,'work','external','neorl_source_20261013','docs','source','modules','evolutionary','hclpso.rst');
if isfile(refSrc),copyfile(refSrc,fullfile(snap,'reference_hclpso.py'));end
if isfile(refDoc),copyfile(refDoc,fullfile(snap,'reference_hclpso.rst'));end
methods={'Original-CSO-MR02','SAQ-CSO','CLPSO-AuthorSource','HCLPSO-Reference'};
functions=[1,3:30]; seeds=3001:3030; budget=100000; N=50; D=50;
if strcmp(mode,'smoke'),functions=[1,13]; seeds=3001:3002; budget=1200;end
jobs=cell(0,1);
for fid=functions
 for seed=seeds
  initSeed=261013000+fid*10000+seed; searchSeed=initSeed+1000000;
  for k=1:numel(methods)
   jobs{end+1}=struct('JobID',numel(jobs)+1,'FunctionID',fid,'Seed',seed, ...
      'Budget',budget,'Dimension',D,'Population',N,'Condition',methods{k}, ...
      'InitSeed',initSeed,'SearchSeed',searchSeed); %#ok<AGROW>
  end
 end
end
jobs=[jobs{:}];
environment=struct('MATLAB',version,'Computer',computer,'Dimension',D,'Budget',budget, ...
 'Functions',functions,'Seeds',seeds,'Workers',4,'ThreadsPerWorker',1,'Population',N, ...
 'Methods',{methods},'Mode',mode,'Created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
 'Protocol','docs/SAQ_CSO_FORMAL_COMPARISON_PROTOCOL_20261013.md');
fid=fopen(fullfile(outDir,'environment.json'),'w');fprintf(fid,'%s',jsonencode(environment,PrettyPrint=true));fclose(fid);
writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
pool=gcp('nocreate'); if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut); fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1); fprintf('OUTDIR %s JOBS %d workers4\n',outDir,numel(jobs));
batchSize=8;
for first=1:batchSize:numel(jobs)
 last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); res=cell(numel(batch),1);
 parfor k=1:numel(batch),res{k}=runOne(batch(k),outDir);end
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

function rec=runOne(job,outDir)
D=job.Dimension; lb=-100*ones(1,D); ub=100*ones(1,D);
rng(job.InitSeed,'twister'); p0=lb+rand(job.Population,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget);
rec=job; rec.FinalError=NaN; rec.FinalCost=NaN; rec.Seconds=NaN; rec.Evaluations=NaN;
rec.ObjectiveCalls=NaN; rec.PostRunRecheckCalls=NaN; rec.BestDiff=NaN; rec.InitialCost=NaN;
rec.FirstImprovementEvaluation=NaN; rec.Iterations=NaN; rec.SkippedOutside=NaN; rec.RefreshCount=NaN;
rec.TracingEvaluations=NaN; rec.SeekingEvaluations=NaN; rec.Decisions=NaN; rec.QUpdates=NaN;
rec.Action1Share=NaN;rec.Action2Share=NaN;rec.Action3Share=NaN;rec.Status='error';rec.ErrorMessage='';
calls=0; outside=0; B=[]; T=[]; I=[]; start=tic;
try
 switch job.Condition
  case 'Original-CSO-MR02'
   [B,T,I]=CSO_CEC(@capture,state,[],job.Population,job.SearchSeed);
  case 'SAQ-CSO'
   [B,T,I]=SAQ_CSO(@capture,state,[],job.Population,job.SearchSeed);
  case 'CLPSO-AuthorSource'
   [B,T,I]=CLPSO_CEC_AuthorSource(@capture,state,[],job.Population,job.SearchSeed);
  case 'HCLPSO-Reference'
   [B,T,I]=HCLPSO_CEC_Reference(@capture,state,[],job.Population,job.SearchSeed);
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
 names={'FirstImprovementEvaluation','Iterations','SkippedOutside','RefreshCount','TracingEvaluations','SeekingEvaluations','Decisions','QUpdates','Action1Share','Action2Share','Action3Share'};
 for k=1:numel(names),if isfield(I,names{k}),rec.(names{k})=I.(names{k});end,end
 rec.Status='ok';
catch e
 rec.Seconds=toc(start); rec.ErrorMessage=e.message;
end
save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I','p0');
 function v=capture(x)
  calls=calls+1; outside=outside+double(any(x<lb|x>ub));
  assert(calls<=job.Budget+1 && outside==0 && all(isfinite(x)));
  v=CEC2017Function(x,job.FunctionID); assert(isfinite(v));
 end
end
