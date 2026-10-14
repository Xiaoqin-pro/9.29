function outDir=run_saq_seeking_window_pilot(stage,parentDir)
% Freeze source/data before a four-worker pilot. stage1 tests mechanics.
if nargin<1,stage='mechanism';end
if nargin<2,parentDir='';end
acceptance='greedy';
root=fileparts(fileparts(mfilename('fullpath')));
validation=fullfile(root,'work','saq_seeking_window_validation_20261014','validation.json');
assert(isfile(validation),'Correctness validation is required before performance runs.');
v=jsondecode(fileread(validation));assert(v.AllPassed);
assert(isfield(v,'EngineSHA256') && strcmp(v.EngineSHA256,fileSHA(fullfile(root,'src','SAQ_CSO_SeekingWindow.m'))),'Validated engine has changed; rerun correctness tests.');
cfg=struct('Stage',stage,'Date','2026-10-14','FunctionIDs',[1 6 9 13 21 22 27 30],...
 'Seeds',8101:8110,'Dimension',50,'Population',50,'Budget',100000,...
 'LowerBound',-100,'UpperBound',100,'WorkerCount',4,'BatchSize',4,...
 'ProgressWindowFE',1000,'ProgressThreshold',1e-4,'EpisodeFE',100,'SeedBase',20301014,...
 'ParentRun',parentDir,'Acceptance',acceptance,'MATLABVersion',version);
cfg.RewardScheme='teacher';
cfg.CachedControls='results/saq_elite_probe_policy_10seed_20261014';
if strcmp(stage,'mechanism')
 methods={'SW-Base','SW-Rule'};policies={'base','rule'};acceptances={'greedy','greedy'};
elseif strcmp(stage,'policy')
 assert(isfolder(parentDir));parentGate=jsondecode(fileread(fullfile(parentDir,'gate_decision.json')));
 assert(parentGate.Passed,'Window mechanism failed its development gate.');
 methods={'SW-Random','SW-Q'};policies={'random','q'};acceptances={'greedy','greedy'};
else,error('Unknown stage.');end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results','cec',['saq_seeking_window_' stage '_' stamp]);mkdir(outDir);mkdir(fullfile(outDir,'source'));mkdir(fullfile(outDir,'runs'));
dataOut=fullfile(outDir,'cec_data');mkdir(dataOut);mkdir(fullfile(dataOut,'input_data'));
sourceFiles={fullfile(root,'src','SAQ_CSO_SeekingWindow.m'),fullfile(root,'experiments','run_saq_seeking_window_job.m'),...
 fullfile(root,'experiments','run_saq_seeking_window_pilot.m'),fullfile(root,'archive','legacy','CEC2017Function.m'),...
 fullfile(root,'src','ASE_CSO_QuotaQ_Compact.m'),fullfile(root,'experiments','export_saq_seeking_window_diagnostics.m'),fullfile(root,'tests','test_SAQ_CSO_SeekingWindow.m')};
for k=1:numel(sourceFiles),copyfile(sourceFiles{k},fullfile(outDir,'source'));end
copyfile(fullfile(root,'docs','SAQ_SEEKING_WINDOW_PROTOCOL_20261014.md'),outDir);
copyfile(fullfile(root,'docs','SAQ_ELITE_PROBE_IMPLEMENTATION_20261014.md'),outDir);
copyfile(validation,outDir);copyfile(fullfile(root,'work','saq_seeking_window_validation_20261014','checks.csv'),outDir);
copyfile(fullfile(root,'data','cec2017','cec17_func.mexw64'),dataOut);copyfile(fullfile(root,'data','cec2017','cec17_func.cpp'),dataOut);
for fid=cfg.FunctionIDs
 names={sprintf('shift_data_%d.txt',fid),sprintf('M_%d_D50.txt',fid),sprintf('shuffle_data_%d_D50.txt',fid)};
 for k=1:numel(names)
  origin=fullfile(root,'data','cec2017','input_data',names{k});
  if isfile(origin),copyfile(origin,fullfile(dataOut,'input_data'));elseif k<=2,error('Required CEC data missing.');end
 end
end
jobs=struct('JobID',{},'FunctionID',{},'Seed',{},'Method',{},'Policy',{},'Acceptance',{},'InitSeed',{},'SearchSeed',{},'PolicySeed',{},'ProbeSeed',{});count=0;
for fid=cfg.FunctionIDs
 for seed=cfg.Seeds
  initSeed=cfg.SeedBase+fid*1000+seed;searchSeed=initSeed+100000;
  for m=1:numel(methods)
   count=count+1;jobs(count)=struct('JobID',count,'FunctionID',fid,'Seed',seed,'Method',methods{m},...
    'Policy',policies{m},'Acceptance',acceptances{m},'InitSeed',initSeed,'SearchSeed',searchSeed,...
    'PolicySeed',mod(searchSeed+3000001,2^32),'ProbeSeed',mod(searchSeed+6000001,2^32));
  end
 end
end
cfg.Methods=methods;cfg.Runs=numel(jobs);cfg.OptimizationFETotal=numel(jobs)*cfg.Budget;
writeJSON(fullfile(outDir,'config.json'),cfg);writetable(struct2table(jobs),fullfile(outDir,'jobs.csv'));
cacheDir=fullfile(outDir,'cache');mkdir(cacheDir);
for name={'all_runs.csv','config.json','convergence_nodes.csv','policy_state_diagnostics.csv'}
 copyfile(fullfile(root,cfg.CachedControls,name{1}),cacheDir);
end
files=[dir(fullfile(cacheDir,'*'));dir(fullfile(outDir,'source','*'));dir(fullfile(dataOut,'*'));dir(fullfile(dataOut,'input_data','*'))];
hashes=cell(0,1);
for k=1:numel(files)
 if files(k).isdir,continue;end
 path=fullfile(files(k).folder,files(k).name);hashes{end+1}=struct('Path',path,'SHA256',fileSHA(path)); %#ok<AGROW>
end
writetable(struct2table([hashes{:}]),fullfile(outDir,'prelaunch_hashes.csv'));
writeJSON(fullfile(outDir,'status.json'),struct('Status','prepared','Completed',0,'Total',numel(jobs),'OutputDirectory',outDir));
fidLatest=fopen(fullfile(root,'work',['saq_seeking_window_latest_' stage '.txt']),'w');fprintf(fidLatest,'%s',outDir);fclose(fidLatest);
oldDir=pwd;cleanup=onCleanup(@()cd(oldDir)); %#ok<NASGU>
cd(dataOut);addpath(fullfile(outDir,'source'),'-begin');clear SAQ_CSO_SeekingWindow CEC2017Function run_saq_seeking_window_job;
preCfg=cfg;preCfg.Budget=1250;preCfg.ProgressWindowFE=10;preCfg.ProgressThreshold=1e6;
preJob=jobs(1);preJob.JobID=0;preJob.Method='Preflight';preJob.Policy='rule';preJob.Acceptance='greedy';
preRecord=run_saq_seeking_window_job(preJob,preCfg,outDir);writetable(struct2table(preRecord,'AsArray',true),fullfile(outDir,'preflight.csv'));
assert(strcmp(preRecord.Status,'ok') && preRecord.ProbeEvaluations>0,'Runner preflight failed.');
pool=gcp('nocreate');if isempty(pool),pool=parpool('local',cfg.WorkerCount);else,assert(pool.NumWorkers==cfg.WorkerCount);end
attached={fullfile(outDir,'source','SAQ_CSO_SeekingWindow.m'),fullfile(outDir,'source','CEC2017Function.m'),fullfile(outDir,'source','run_saq_seeking_window_job.m')};
addAttachedFiles(pool,attached);records=cell(numel(jobs),1);
for first=1:cfg.BatchSize:numel(jobs)
 last=min(first+cfg.BatchSize-1,numel(jobs));batch=jobs(first:last);batchResults=cell(numel(batch),1);
 parfor j=1:numel(batch),batchResults{j}=run_saq_seeking_window_job(batch(j),cfg,outDir);end
 records(first:last)=batchResults;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));
 writeJSON(fullfile(outDir,'status.json'),struct('Status','running','Completed',last,'Total',numel(jobs),'OutputDirectory',outDir));
 fprintf('EliteProbe %s completed %d/%d runs; latest F%d seed%d %s%c',stage,last,numel(jobs),batch(end).FunctionID,batch(end).Seed,batch(end).Method,10);
 if any(~strcmp(raw.Status,'ok'))
  writeJSON(fullfile(outDir,'status.json'),struct('Status','failed','Completed',last,'Total',numel(jobs),'OutputDirectory',outDir));
  error('Pilot:InvalidRun','A run failed validation; remaining experiment stopped.');
 end
end
for k=1:numel(hashes),assert(strcmp(fileSHA(hashes{k}.Path),hashes{k}.SHA256),'Snapshot changed during run.');end
export_saq_seeking_window_diagnostics(outDir);
writeJSON(fullfile(outDir,'status.json'),struct('Status','complete','Completed',numel(jobs),'Total',numel(jobs),'OutputDirectory',outDir,'SnapshotHashesVerified',true));
fprintf('Completed elite probe %s pilot: %s%c',stage,outDir,10);
end
function writeJSON(path,value)
f=fopen(path,'w');fprintf(f,'%s',jsonencode(value,PrettyPrint=true));fclose(f);
end
function digest=fileSHA(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
