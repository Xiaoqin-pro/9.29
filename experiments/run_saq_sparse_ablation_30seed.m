function outDir=run_saq_sparse_ablation_30seed(mode,resumeDir)
% Six-condition mechanism ablation, five new controls plus cached frozen SAQ.
if nargin<1,mode='study';end;if nargin<2,resumeDir='';end
assert(ismember(mode,{'study','smoke'}));root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
work=fullfile(root,'work','saq_framework_ablation_20261013');pre=jsondecode(fileread(fullfile(work,'preflight.json')));
assert(pre.Passed&&pre.ExactFrozenMainPairs==33&&pre.VariantBehaviorCases==192&&pre.Full100kNewVariants==5);
assert(strcmp(pre.SourceHashes.Engine,SourceFileSHA256(fullfile(root,'src','SAQ_CSO_FrameworkAblation.m'))));
assert(strcmp(pre.SourceHashes.Variant,SourceFileSHA256(fullfile(root,'src','SAQ_CSO_AblationVariant.m'))));
assert(strcmp(pre.SourceHashes.FrozenMain,SourceFileSHA256(fullfile(root,'src','ASE_CSO_QuotaQ_Compact.m'))));
cacheDir=fullfile(root,'results','cec','saq_cso_formal_100k_30seed_study_20261013_083541');
for rel={'src/SAQ_CSO.m','src/ASE_CSO_QuotaQ_Candidate.m','src/ASE_CSO_QuotaQ_Compact.m','archive/legacy/CEC2017Function.m'}
 assert(strcmp(SourceFileSHA256(fullfile(cacheDir,'source_snapshot',rel{1})),SourceFileSHA256(fullfile(root,rel{1}))),['Cache source mismatch: ' rel{1}]);
end
cache=readtable(fullfile(cacheDir,'raw_runs.csv'),'TextType','string');cache=cache(cache.Condition=="SAQ-CSO",:);assert(height(cache)==870&&all(cache.Status=="ok"));
dataDir=fullfile(root,'data','cec2017');cd(dataDir);stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
if isempty(resumeDir),outDir=fullfile(root,'results','cec',['saq_sparse_ablation_30seed_' mode '_' stamp]);mkdir(outDir);mkdir(fullfile(outDir,'runs'));
else,outDir=resumeDir;assert(isfolder(fullfile(outDir,'runs')));end
snap=fullfile(outDir,'source_snapshot');
files={'src/SAQ_CSO_FrameworkAblation.m','src/SAQ_CSO_AblationVariant.m','src/ASE_CSO_QuotaQ_Compact.m', ...
 'src/ASE_CSO_QuotaQ_Candidate.m','src/SAQ_CSO.m','src/SourceFileSHA256.m','src/ASE_CSO_ModeBudget.m', ...
 'archive/legacy/CEC2017Function.m','experiments/run_saq_sparse_ablation_30seed.m', ...
 'tests/test_SAQ_framework_ablation.m','docs/SAQ_SPARSE_ABLATION_PROTOCOL_20261013.md', ...
 'implement-stage/SPARSE_FRAMEWORK_ABLATION_ASSUMPTIONS_20261013.md'};
if isempty(resumeDir)
 mkdir(snap);
 for k=1:numel(files),target=fullfile(snap,files{k});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end;copyfile(fullfile(root,files{k}),target);end
 copyfile(fullfile(work,'preflight.json'),fullfile(snap,'preflight.json'));
else
 for rel={'src/SAQ_CSO_FrameworkAblation.m','src/SAQ_CSO_AblationVariant.m','src/ASE_CSO_QuotaQ_Compact.m'}
  assert(strcmp(SourceFileSHA256(fullfile(snap,rel{1})),SourceFileSHA256(fullfile(root,rel{1}))));
 end
end
addpath(fullfile(snap,'src'),'-begin');
variants={'Dense-NoQ','RandomSparse-Fixed6','Fixed4','Fixed6','RandomQuota','Full'};
labels={'FullEval-CSO','RandomSparse-Fixed6','SpatialSparse-Fixed4','SpatialSparse-Fixed6','SpatialSparse-RandomQuota','SAQ-CSO'};
functions=[1,3:30];seeds=3001:3030;budget=100000;
if strcmp(mode,'smoke'),functions=[1,13];seeds=3001;budget=1200;end
jobs=cell(0,1);
for fid=functions,for seed=seeds,for k=1:numel(variants)
 initSeed=261013000+fid*10000+seed;
 jobs{end+1}=struct('JobID',numel(jobs)+1,'FunctionID',fid,'Seed',seed,'Budget',budget,'Dimension',50,'Population',50, ...
  'Condition',labels{k},'Variant',variants{k},'InitSeed',initSeed,'SearchSeed',initSeed+1000000); %#ok<AGROW>
end;end;end;jobs=[jobs{:}];
env=struct('MATLAB',version,'Computer',computer,'Dimension',50,'Budget',budget,'Functions',functions,'Seeds',seeds, ...
 'Workers',4,'ThreadsPerWorker',1,'Population',50,'Mode',mode,'Created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
 'Conditions',{labels},'SourcePreflight',pre,'PlannedNewRuns',4350,'CachedFullRuns',870,'CacheDirectory',cacheDir);
if isempty(resumeDir)
 fid=fopen(fullfile(outDir,'environment.json'),'w');fprintf(fid,'%s',jsonencode(env,PrettyPrint=true));fclose(fid);
 writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
else,existing=readtable(fullfile(outDir,'job_manifest.csv'),'TextType','string');assert(height(existing)==numel(jobs));end
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut);fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1);fprintf('OUTDIR %s JOBS%d workers4\n',outDir,numel(jobs));
for first=1:12:numel(jobs)
 last=min(first+11,numel(jobs));batch=jobs(first:last);res=cell(numel(batch),1);
 parfor k=1:numel(batch),res{k}=runOne(batch(k),outDir,cacheDir,cache);end
 records(first:last)=res;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));
 progress=struct('Completed',last,'Total',numel(jobs),'OK',sum(strcmp(raw.Status,'ok')),'Failed',sum(~strcmp(raw.Status,'ok')), ...
  'NewOptimizationRecords',sum(~raw.FromCache),'CachedRecords',sum(raw.FromCache),'Date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
 fid=fopen(fullfile(outDir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress,PrettyPrint=true));fclose(fid);
 fprintf('PROGRESS %d/%d ok%d fail%d new%d cached%d\n',last,numel(jobs),progress.OK,progress.Failed,progress.NewOptimizationRecords,progress.CachedRecords);assert(progress.Failed==0);
end
fid=fopen(fullfile(outDir,'COMPLETED.json'),'w');fprintf(fid,'%s',jsonencode(struct('QualityRecords',numel(jobs),'NewRuns',sum(~raw.FromCache),'CachedRuns',sum(raw.FromCache),'Completed',true)));fclose(fid);
fprintf('DONE %s\n',outDir);
end
function rec=runOne(job,outDir,cacheDir,cache)
path=fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID));
if isfile(path)
 saved=load(path,'job','rec');assert(isequal(job,saved.job)&&strcmp(saved.rec.Status,'ok'));rec=saved.rec;return;
end
D=job.Dimension;lb=-100*ones(1,D);ub=100*ones(1,D);rng(job.InitSeed,'twister');p0=lb+rand(50,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget,'ablationVariant',job.Variant);
rec=job;names={'FinalError','FinalCost','Seconds','Evaluations','ObjectiveCalls','OutsideCalls','PostRunRecheckCalls','BestDiff','InitialCost', ...
 'Rounds','SeekingEvaluations','TracingEvaluations','MaxParentEvaluations','Decisions','QUpdates','FreeDecisions','GateFraction', ...
 'Action1Share','Action2Share','Action3Share','CandidatePointsGenerated','RealEvaluationFraction','MeanRoundCost', ...
 'Error20FE','Error60FE','Error80FE','FirstImprovementEvaluation'};
for n=names,rec.(n{1})=NaN;end
rec.FromCache=false;rec.SourceDirectory='';rec.SourceJobID=NaN;rec.Status='error';rec.ErrorMessage='';B=[];T=[];I=[];calls=0;outside=0;start=tic;
try
 if strcmp(job.Variant,'Full')&&job.Budget==100000
  match=cache(cache.FunctionID==job.FunctionID&cache.Seed==job.Seed,:);assert(height(match)==1);
  saved=load(fullfile(cacheDir,'runs',sprintf('job_%04d.mat',match.JobID)));assert(isequal(saved.p0,p0)&&saved.job.SearchSeed==job.SearchSeed&&strcmp(saved.rec.Status,'ok'));
  B=saved.B;T=saved.T;I=saved.I;rec.FromCache=true;rec.SourceDirectory=cacheDir;rec.SourceJobID=match.JobID;
  rec.Seconds=match.Seconds;rec.ObjectiveCalls=match.ObjectiveCalls;rec.OutsideCalls=match.OutsideCalls;
  rec.PostRunRecheckCalls=match.PostRunRecheckCalls;rec.BestDiff=match.BestDiff;
 else
  [B,T,I]=SAQ_CSO_AblationVariant(@capture,state,[],50,job.SearchSeed);
  rec.Seconds=toc(start);rec.ObjectiveCalls=calls;rec.OutsideCalls=outside;
  assert(calls==job.Budget);v=capture(B.Vector);rec.PostRunRecheckCalls=calls-rec.ObjectiveCalls;rec.BestDiff=abs(v-B.Cost);
 end
 assert(rec.ObjectiveCalls==job.Budget&&I.Evaluations==job.Budget&&numel(T)==job.Budget&&all(isfinite(T))&&all(diff(T)<=0)&&rec.OutsideCalls==0);
 assert(rec.PostRunRecheckCalls==1&&rec.BestDiff<=1e-8*max(1,abs(B.Cost)));
 rec.Evaluations=I.Evaluations;rec.FinalCost=B.Cost;rec.FinalError=B.Cost-100*job.FunctionID;rec.InitialCost=T(50);
 fields={'Rounds','SeekingEvaluations','TracingEvaluations','MaxParentEvaluations','Decisions','QUpdates','FreeDecisions'};
 for n=fields,rec.(n{1})=I.(n{1});end
 R=I.RoundLog;rec.CandidatePointsGenerated=sum(R(:,5)+4*R(:,6));rec.RealEvaluationFraction=(job.Budget-50)/rec.CandidatePointsGenerated;
 rec.MeanRoundCost=(job.Budget-50)/I.Rounds;G=I.GateLog;rec.GateFraction=mean(G(:,2));DL=I.DecisionLog;
 rec.Action1Share=mean(DL(:,4)==1);rec.Action2Share=mean(DL(:,4)==2);rec.Action3Share=mean(DL(:,4)==3); % col4=actionindex, col5=quota
 rec.Error20FE=T(round(.2*job.Budget))-100*job.FunctionID;rec.Error60FE=T(round(.6*job.Budget))-100*job.FunctionID;rec.Error80FE=T(round(.8*job.Budget))-100*job.FunctionID;
 j=find(T(51:end)<T(50),1);if ~isempty(j),rec.FirstImprovementEvaluation=50+j;end
 rec.Status='ok';
catch e,rec.Seconds=toc(start);rec.ErrorMessage=e.message;end
save(path,'job','rec','B','T','I','p0');
 function value=capture(x)
  calls=calls+1;outside=outside+double(any(x<lb|x>ub));assert(calls<=job.Budget+1&&outside==0&&all(isfinite(x)));value=CEC2017Function(x,job.FunctionID);assert(isfinite(value));
 end
end
