function outDir=run_saq_strong_confirmation
% 29-function, 10-seed confirmation using verified cached strong baselines.
root=fileparts(fileparts(mfilename('fullpath')));
validation=fullfile(root,'work','saq_elite_probe_validation_20261014','validation.json');v=jsondecode(fileread(validation));
assert(v.AllPassed && strcmp(v.EngineSHA256,fileSHA(fullfile(root,'src','SAQ_CSO_EliteProbe.m'))));
cache=fullfile(root,'work','saq_strong_confirmation_cache_20261014');
cp=jsondecode(fileread(fullfile(cache,'cache_python_validation.json')));cm=jsondecode(fileread(fullfile(cache,'cache_matlab_validation.json')));
assert(cp.Passed && cm.Passed && cp.CachedRuns==1740 && cm.Runs==1740);
paired=readtable(fullfile(cache,'paired_seeds.csv'));assert(height(paired)==290);
cfg=struct('Stage','strong-confirmation','Date','2026-10-14','FunctionIDs',[1 3:30],'Seeds',3001:3010,...
 'Dimension',50,'Population',50,'Budget',100000,'LowerBound',-100,'UpperBound',100,...
 'WorkerCount',4,'BatchSize',8,'ProgressWindowFE',1000,'ProgressThreshold',1e-4,'EpisodeFE',100,...
 'SeedBase',261013000,'SearchSeedOffset',1000000,'MATLABVersion',version,'Methods',{{'ELS-Q','ELS-Replace'}},...
 'CachedMethods',{{'SAQ-CSO','HCLPSO-AuthorSource','HIDMS-PSO-IndexCorrected','DMS-PSO-SIS2005','HPSO-TVAC-CEC','SPSO-2011-OfficialC'}},...
 'CachedRuns',1740,'NewRuns',580,'TotalComparisonRuns',2320,'NewOptimizationCalls',58000000,...
 'DevelopmentSeeds',8101:8110,'Protocol','docs/SAQ_STRONG_CONFIRMATION_PROTOCOL_20261014.md');
assert(setEqual(paired.FunctionID,cfg.FunctionIDs) && setEqual(paired.Seed,cfg.Seeds));
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));outDir=fullfile(root,'results','cec',['saq_strong_confirmation_29f_10seed_' stamp]);
mkdir(outDir);mkdir(fullfile(outDir,'source'));mkdir(fullfile(outDir,'runs'));mkdir(fullfile(outDir,'cache'));dataOut=fullfile(outDir,'cec_data');mkdir(dataOut);mkdir(fullfile(dataOut,'input_data'));
sourceFiles={fullfile(root,'src','SAQ_CSO_EliteProbe.m'),fullfile(root,'experiments','run_saq_elite_probe_job.m'),...
 fullfile(root,'experiments','run_saq_strong_confirmation.m'),fullfile(root,'archive','legacy','CEC2017Function.m'),fullfile(root,'tests','test_SAQ_CSO_EliteProbe.m')};
for k=1:numel(sourceFiles),copyfile(sourceFiles{k},fullfile(outDir,'source'));end
for name={'cached_runs.csv','cached_convergence_nodes.csv','paired_seeds.csv','cached_source_hashes.csv','cache_python_validation.json','cache_matlab_validation.json','cache_matlab_rechecks.csv'}
 copyfile(fullfile(cache,name{1}),fullfile(outDir,'cache'));
end
copyfile(validation,outDir);copyfile(fullfile(root,'docs','SAQ_STRONG_CONFIRMATION_PROTOCOL_20261014.md'),outDir);
copyfile(fullfile(root,'docs','SAQ_ELITE_PROBE_IMPLEMENTATION_20261014.md'),outDir);
copyfile(fullfile(root,'data','cec2017','cec17_func.mexw64'),dataOut);copyfile(fullfile(root,'data','cec2017','cec17_func.cpp'),dataOut);
copyfile(fullfile(root,'data','cec2017','D50_manifest.csv'),dataOut);
for fid=cfg.FunctionIDs
 names={sprintf('shift_data_%d.txt',fid),sprintf('M_%d_D50.txt',fid),sprintf('shuffle_data_%d_D50.txt',fid)};
 for k=1:numel(names)
  path=fullfile(root,'data','cec2017','input_data',names{k});
  if isfile(path),copyfile(path,fullfile(dataOut,'input_data'));elseif k<=2,error('Required CEC data missing.');end
 end
end
cachedHashes=readtable(fullfile(cache,'cached_source_hashes.csv'),'TextType','string');
for k=1:height(cachedHashes)
 assert(strcmp(fileSHA(fullfile(root,char(cachedHashes.Path(k)))),cachedHashes.SHA256(k)));
 path=fullfile(root,char(cachedHashes.Path(k)));target=fullfile(outDir,'cache','source',char(cachedHashes.Path(k)));
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end;copyfile(path,target);
end
jobs=struct('JobID',{},'FunctionID',{},'Seed',{},'Method',{},'Policy',{},'Acceptance',{},'InitSeed',{},'SearchSeed',{},'PolicySeed',{},'ProbeSeed',{});count=0;
for k=1:height(paired)
 row=paired(k,:);assert(row.InitSeed==cfg.SeedBase+row.FunctionID*10000+row.Seed && row.SearchSeed==row.InitSeed+cfg.SearchSeedOffset);
 for m=1:2
  count=count+1;method=cfg.Methods{m};policy='q';if m==2,policy='rule';end
  jobs(count)=struct('JobID',count,'FunctionID',row.FunctionID,'Seed',row.Seed,'Method',method,'Policy',policy,'Acceptance','replace',...
   'InitSeed',row.InitSeed,'SearchSeed',row.SearchSeed,'PolicySeed',mod(row.SearchSeed+3000001,2^32),'ProbeSeed',mod(row.SearchSeed+6000001,2^32));
 end
end
assert(numel(jobs)==580);writeJSON(fullfile(outDir,'config.json'),cfg);writetable(struct2table(jobs),fullfile(outDir,'jobs.csv'));
files=dir(fullfile(outDir,'**','*'));hashes=cell(0,1);
for k=1:numel(files)
 if files(k).isdir,continue;end;path=fullfile(files(k).folder,files(k).name);hashes{end+1}=struct('Path',path,'SHA256',fileSHA(path)); %#ok<AGROW>
end
writetable(struct2table([hashes{:}]),fullfile(outDir,'prelaunch_hashes.csv'));
writeJSON(fullfile(outDir,'status.json'),struct('Status','prepared','Completed',0,'Total',580,'CachedRuns',1740,'OutputDirectory',outDir));
f=fopen(fullfile(root,'work','saq_strong_confirmation_latest.txt'),'w');fprintf(f,'%s',outDir);fclose(f);
old=pwd;cleanup=onCleanup(@()cd(old));cd(dataOut);addpath(fullfile(outDir,'source'),'-begin'); %#ok<NASGU>
clear SAQ_CSO_EliteProbe CEC2017Function run_saq_elite_probe_job;
preCfg=cfg;preCfg.Budget=1250;preCfg.ProgressWindowFE=10;preCfg.ProgressThreshold=1e6;
preJob=jobs(1);preJob.JobID=0;preJob.Method='Preflight';preJob.Policy='rule';
rec=run_saq_elite_probe_job(preJob,preCfg,outDir);writetable(struct2table(rec,'AsArray',true),fullfile(outDir,'preflight.csv'));
assert(strcmp(rec.Status,'ok') && rec.ObjectiveCalls==1250 && rec.ProbeEvaluations>0 && rec.ProbeWritebacks==rec.ProbeEvaluations);
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',cfg.WorkerCount);else,assert(pool.NumWorkers==cfg.WorkerCount);end
addAttachedFiles(pool,{fullfile(outDir,'source','SAQ_CSO_EliteProbe.m'),fullfile(outDir,'source','CEC2017Function.m'),fullfile(outDir,'source','run_saq_elite_probe_job.m')});
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut);
records=cell(numel(jobs),1);
for first=1:cfg.BatchSize:numel(jobs)
 last=min(first+cfg.BatchSize-1,numel(jobs));batch=jobs(first:last);results=cell(numel(batch),1);
 parfor j=1:numel(batch),results{j}=run_saq_elite_probe_job(batch(j),cfg,outDir);end
 records(first:last)=results;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));
 writeJSON(fullfile(outDir,'status.json'),struct('Status','running','Completed',last,'Total',580,'CachedRuns',1740,'OutputDirectory',outDir));
 fprintf('Strong confirmation completed %d/580 new runs; latest F%d seed%d %s%c',last,batch(end).FunctionID,batch(end).Seed,batch(end).Method,10);
 if any(~strcmp(raw.Status,'ok'))
  writeJSON(fullfile(outDir,'status.json'),struct('Status','failed','Completed',last,'Total',580,'CachedRuns',1740,'OutputDirectory',outDir));
  error('Confirmation:InvalidRun','A run failed validation; remaining jobs stopped.');
 end
end
for k=1:numel(hashes),assert(strcmp(fileSHA(hashes{k}.Path),hashes{k}.SHA256),'Prelaunch input changed.');end
writeJSON(fullfile(outDir,'status.json'),struct('Status','complete','Completed',580,'Total',580,'CachedRuns',1740,'OutputDirectory',outDir,'SnapshotHashesVerified',true));
fprintf('Completed strong confirmation: %s%c',outDir,10);
end
function result=setEqual(values,expected),result=isequal(sort(unique(values(:)))',sort(expected));end
function writeJSON(path,value),f=fopen(path,'w');fprintf(f,'%s',jsonencode(value,PrettyPrint=true));fclose(f);end
function digest=fileSHA(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
