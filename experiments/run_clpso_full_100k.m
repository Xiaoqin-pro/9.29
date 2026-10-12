function outDir=run_clpso_full_100k(mode)
if nargin<1,mode='study';end;assert(ismember(mode,{'study','smoke'}));
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);dataDir=fullfile(root,'data','cec2017');cd(dataDir);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));outDir=fullfile(root,'results','cec',['clpso_full_100k_' mode '_' stamp]);mkdir(outDir);mkdir(fullfile(outDir,'runs'));snap=fullfile(outDir,'source_snapshot');mkdir(snap);
files={'src/CLPSO_CEC_Audit.m','src/CLPSO_CEC_AuthorSource.m','src/ASE_CSO_Lean_B10.m','src/ASE_CSO_ModeBudget.m','archive/legacy/CLPSO_CEC.m','archive/legacy/CEC2017Function.m','experiments/run_clpso_full_100k.m','tests/test_CLPSO_audit.m','tests/test_CLPSO_D50_adapter.m','docs/CLPSO_FULL_100K_PROTOCOL_20261012.md'};
for k=1:numel(files),t=fullfile(snap,files{k});if ~isfolder(fileparts(t)),mkdir(fileparts(t));end;copyfile(fullfile(root,files{k}),t);end
addpath(fullfile(snap,'src'),fullfile(snap,'archive','legacy'));
methods={'CSO-Fixed6','CLPSO-AuthorSource40'};functions=[1,3:30];seeds=2201:2205;budgets=100000;if strcmp(mode,'smoke'),functions=[1,13];seeds=2201;budgets=600;end
jobs=cell(0,1);
for fid=functions,for seed=seeds,for budget=budgets,for k=1:numel(methods)
 N=50;if strcmp(methods{k},'CLPSO-AuthorSource40'),N=40;end;initSeed=21701012+fid*10000+seed;jobs{end+1}=struct('JobID',numel(jobs)+1,'FunctionID',fid,'Seed',seed,'Budget',budget,'Dimension',50,'Population',N,'Condition',methods{k},'InitSeed',initSeed,'SearchSeed',initSeed+1000000); %#ok<AGROW>
end;end;end;end
jobs=[jobs{:}];
environment=struct('MATLAB',version,'Computer',computer,'Dimension',50,'Budget',100000,'Functions',[1,3:30],'Seeds',2201:2205,'Workers',4,'ThreadsPerWorker',1,'CSOPopulation',50,'CLPSOPopulation',40,'CLPSOSource','author-public-code-profile','Mode',mode,'Created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fid=fopen(fullfile(outDir,'environment.json'),'w');fprintf(fid,'%s',jsonencode(environment,PrettyPrint=true));fclose(fid);
writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end;fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut);fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1);fprintf('OUTDIR %s JOBS%d workers4%c',outDir,numel(jobs),10);
for first=1:12:numel(jobs)
 last=min(first+11,numel(jobs));batch=jobs(first:last);res=cell(numel(batch),1);parfor k=1:numel(batch),res{k}=runOne(batch(k),outDir);end
 records(first:last)=res;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));progress=struct('Completed',last,'Total',numel(jobs),'OK',sum(strcmp(raw.Status,'ok')),'Failed',sum(~strcmp(raw.Status,'ok')),'Date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
 fid=fopen(fullfile(outDir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress,PrettyPrint=true));fclose(fid);fprintf('PROGRESS %d/%d ok%d fail%d %s%c',last,numel(jobs),progress.OK,progress.Failed,progress.Date,10);assert(progress.Failed==0);
end
fid=fopen(fullfile(outDir,'COMPLETED.json'),'w');fprintf(fid,'%s',jsonencode(struct('Runs',numel(jobs),'Completed',true)));fclose(fid);fprintf('DONE %s%c',outDir,10);
end
function rec=runOne(job,outDir)
D=job.Dimension;lb=-100*ones(1,D);ub=100*ones(1,D);rng(job.InitSeed,'twister');p0=lb+rand(50,D).*(ub-lb);p0=p0(1:job.Population,:);state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget);
rec=job;rec.FinalError=NaN;rec.FinalCost=NaN;rec.Seconds=NaN;rec.Evaluations=NaN;rec.ObjectiveCalls=NaN;rec.OutsideCalls=0;rec.PostRunRecheckCalls=0;rec.BestDiff=NaN;rec.InitialCost=NaN;rec.TracingEvaluations=NaN;rec.SeekingEvaluations=NaN;rec.FirstImprovementEvaluation=NaN;rec.Iterations=NaN;rec.SkippedOutside=NaN;rec.BoundaryClips=NaN;rec.RefreshCount=NaN;rec.Error20FE=NaN;rec.Error60FE=NaN;rec.Error80FE=NaN;rec.Status='error';rec.ErrorMessage='';calls=0;outside=0;B=[];T=[];I=[];start=tic;
try
 if strcmp(job.Condition,'CSO-Fixed6')
  state.modeTraceQuota=6;[B,T,I]=ASE_CSO_ModeBudget(@capture,state,[],job.Population,job.SearchSeed);
 else
  [B,T,I]=CLPSO_CEC_AuthorSource(@capture,state,[],job.Population,job.SearchSeed);
 end
 rec.Seconds=toc(start);rec.ObjectiveCalls=calls;rec.Evaluations=I.Evaluations;rec.OutsideCalls=outside;assert(calls==job.Budget&&numel(T)==job.Budget&&all(isfinite(T))&&all(diff(T)<=0)&&outside==0);
 val=capture(B.Vector);rec.PostRunRecheckCalls=calls-rec.ObjectiveCalls;rec.BestDiff=abs(val-B.Cost);assert(rec.BestDiff<=1e-8*max(1,abs(B.Cost))&&rec.PostRunRecheckCalls==1);
 rec.InitialCost=T(1);if isfield(I,'InitialCost'),rec.InitialCost=I.InitialCost;end
 if strcmp(job.Condition,'CSO-Fixed6')
  rec.TracingEvaluations=I.TracingEvaluations;rec.SeekingEvaluations=I.SeekingEvaluations;assert(I.TracingEvaluations+I.SeekingEvaluations==job.Budget-job.Population&&I.MaxParentEvaluations<=2);
 end
 if isfield(I,'FirstImprovementEvaluation'),rec.FirstImprovementEvaluation=I.FirstImprovementEvaluation;else,j=find(T(job.Population+1:end)<T(job.Population),1);if ~isempty(j),rec.FirstImprovementEvaluation=job.Population+j;end;end
 rec.FinalCost=B.Cost;rec.FinalError=B.Cost-100*job.FunctionID;rec.Error20FE=T(round(.2*job.Budget))-100*job.FunctionID;rec.Error60FE=T(round(.6*job.Budget))-100*job.FunctionID;rec.Error80FE=T(round(.8*job.Budget))-100*job.FunctionID;
 fields={'Iterations','SkippedOutside','BoundaryClips','RefreshCount'};for k=1:numel(fields),if isfield(I,fields{k}),rec.(fields{k})=I.(fields{k});end;end;rec.Status='ok';
catch e,rec.Seconds=toc(start);rec.ErrorMessage=e.message;end
save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I','p0');
 function v=capture(x)
  calls=calls+1;outside=outside+double(any(x<lb|x>ub));assert(calls<=job.Budget+1&&outside==0&&all(isfinite(x)));v=CEC2017Function(x,job.FunctionID);assert(isfinite(v));
 end
end
