function run_asc_jump_study(outDir)
addpath(fullfile(outDir,'source'),'-begin');cd(fullfile(outDir,'cec_data'));
cfg=jsondecode(fileread(fullfile(outDir,'config.json')));v=jsondecode(fileread(fullfile(outDir,'validation.json')));
assert(v.Passed&&strcmp(sha(fullfile(outDir,'source','ASC_NoFarness.m')),v.EngineSHA256));
J=readtable(fullfile(outDir,'jobs.csv'),'TextType','char');jobs=table2struct(J);
% One counted original run at the prior protocol's full budget, checked against saved trajectory.
if ~isfile(fullfile(outDir,'preflight.json'))
 pre=jobs(1);pre.JobID=0;pre.FunctionID=1;pre.Seed=3001;pre.InitSeed=261013000+10000+3001;pre.SearchSeed=pre.InitSeed+1000000;
 record=run_asc_jump_job(pre,cfg,outDir);assert(strcmp(record.Status,'ok'));
 actual=load(fullfile(outDir,'runs',record.Artifact),'B','T','p0');original=load(cfg.ReferenceArtifact,'B','T','p0');
 assert(isequal(actual.B,original.B)&&isequal(actual.T,original.T)&&isequal(actual.p0,original.p0));
 writeJSON(fullfile(outDir,'preflight.json'),struct('Passed',true,'FullBudgetReferenceParity',true,'ObjectiveCalls',record.ObjectiveCalls,'RecheckCalls',record.PostRunRecheckCalls));
end
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
addAttachedFiles(pool,{fullfile(outDir,'source','ASC_NoFarness.m'),fullfile(outDir,'source','run_asc_jump_job.m'),fullfile(outDir,'source','CEC2017Function.m')});
f=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(f);records=cell(numel(jobs),1);
for first=1:12:numel(jobs)
 last=min(first+11,numel(jobs));batch=jobs(first:last);result=cell(numel(batch),1);
 parfor j=1:numel(batch)
  name=sprintf('run_%04d_F%02d_seed%d_%s.mat',batch(j).JobID,batch(j).FunctionID,batch(j).Seed,batch(j).Method);path=fullfile(outDir,'runs',name);
  if isfile(path)
   saved=load(path,'job','rec');assert(isequal(saved.job,batch(j))&&strcmp(saved.rec.Status,'ok'));result{j}=saved.rec;
  else,result{j}=run_asc_jump_job(batch(j),cfg,outDir);end
 end
 records(first:last)=result;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));
 status='running';if any(~strcmp(raw.Status,'ok')),status='failed';end
 writeJSON(fullfile(outDir,'status.json'),struct('Status',status,'Completed',last,'Total',numel(jobs),'Directory',outDir));
 fprintf('ASC Jump %d/%d F%d seed%d %s%c',last,numel(jobs),batch(end).FunctionID,batch(end).Seed,batch(end).Method,10);
 assert(strcmp(status,'running'),'JumpStudy:InvalidRun','Counted run failed; stopping without dropping the record.');
end
h=readtable(fullfile(outDir,'prelaunch_hashes.csv'),'TextType','string');
for k=1:height(h),assert(strcmp(sha(char(h.Path(k))),char(h.SHA256(k))));end
writeJSON(fullfile(outDir,'status.json'),struct('Status','complete','Completed',numel(jobs),'Total',numel(jobs),'SnapshotHashesVerified',true,'Directory',outDir));
fprintf('COMPLETE ASC JUMP %s%c',outDir,10);
end
function writeJSON(path,s)
f=fopen(path,'w');fprintf(f,'%s',jsonencode(s,PrettyPrint=true));fclose(f);
end
function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
