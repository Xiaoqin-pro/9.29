function run_asc_rank_comparison(outDir)
addpath(fullfile(outDir,'source'),'-begin');cd(fullfile(outDir,'cec_data'));
cfg=jsondecode(fileread(fullfile(outDir,'config.json')));
validation=jsondecode(fileread(fullfile(outDir,'validation.json')));assert(validation.Passed);
assert(strcmp(sha(fullfile(outDir,'source','ASC_NoFarness.m')),validation.OriginalSHA256));
assert(strcmp(sha(fullfile(outDir,'source','ASC_NoFarness_PositionRank.m')),validation.ImprovedSHA256));
cacheReport=fullfile(outDir,'cache','cache_validation.json');
if ~isfile(cacheReport),verify_asc_rank_cache(outDir);end
c=jsondecode(fileread(cacheReport));assert(c.Passed&&c.Runs==5220);
J=readtable(fullfile(outDir,'jobs.csv'),'TextType','char');jobs=table2struct(J);records=cell(numel(jobs),1);
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
addAttachedFiles(pool,{fullfile(outDir,'source','ASC_NoFarness.m'),fullfile(outDir,'source','ASC_NoFarness_PositionRank.m'),fullfile(outDir,'source','run_asc_rank_job.m'),fullfile(outDir,'source','CEC2017Function.m')});
f=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(f);
for first=1:16:numel(jobs)
 last=min(first+15,numel(jobs));batch=jobs(first:last);result=cell(numel(batch),1);
 parfor j=1:numel(batch)
  artifact=sprintf('run_%04d_F%02d_seed%d_%s.mat',batch(j).JobID,batch(j).FunctionID,batch(j).Seed,batch(j).Method);
  path=fullfile(outDir,'runs',artifact);
  if isfile(path)
   d=load(path,'job','record');assert(isequal(d.job,batch(j))&&strcmp(d.record.Status,'ok'));result{j}=d.record;
  else,result{j}=run_asc_rank_job(batch(j),cfg,outDir);end
 end
 records(first:last)=result;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));
 status='running';if any(~strcmp(raw.Status,'ok')),status='failed';end
 writeJSON(fullfile(outDir,'status.json'),struct('Status',status,'Completed',last,'Total',numel(jobs),'Directory',outDir));
 fprintf('ASC30 %d/%d F%d seed%d %s\n',last,numel(jobs),batch(end).FunctionID,batch(end).Seed,batch(end).Method);
 assert(strcmp(status,'running'),'ASC:FailedRun','A counted run failed; stopped.');
end
h=readtable(fullfile(outDir,'prelaunch_hashes.csv'),'TextType','string');
for k=1:height(h),assert(strcmp(sha(char(h.Path(k))),h.SHA256(k)));end
writeJSON(fullfile(outDir,'status.json'),struct('Status','complete','Completed',numel(jobs),'Total',numel(jobs),'SnapshotHashesVerified',true,'Directory',outDir));
fprintf('COMPLETE %s\n',outDir);
end
function writeJSON(path,s)
f=fopen(path,'w');fprintf(f,'%s',jsonencode(s,PrettyPrint=true));fclose(f);
end
function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
