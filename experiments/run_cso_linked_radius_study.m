function outDir=run_cso_linked_radius_study(mode)
% Fixed MR mode-quota complementarity study: no Q, no new operators.
if nargin<1,mode='study';end
assert(ismember(mode,{'study','smoke'}));
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);dataDir=fullfile(root,'data','cec2017');cd(dataDir);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));outDir=fullfile(root,'results','cec',['cso_linked_radius_' mode '_' stamp]);mkdir(outDir);mkdir(fullfile(outDir,'runs'));sourceDir=fullfile(outDir,'source_snapshot');mkdir(sourceDir);
files={'src/ASE_CSO_Simplify.m','src/ASE_CSO_ModeBudget.m','src/ASE_CSO_ModeQ.m','src/ASE_CSO_ModeQ_Progress.m','src/ASE_CSO_ModeQ_State.m','src/ASE_CSO_ModeQ_Reheat.m','src/ASE_CSO_Lean_B10.m','archive/legacy/CEC2017Function.m','experiments/run_cso_linked_radius_study.m','docs/CSO_TWO_ROUTES_PROTOCOL_20261012.md','tests/test_CSO_mode_q_reheat.m'};
for k=1:numel(files),target=fullfile(sourceDir,files{k});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end;copyfile(fullfile(root,files{k}),target);end
addpath(fullfile(sourceDir,'src'),fullfile(sourceDir,'archive','legacy'));
functions=[1,3,6,9,12,13,22,30];seeds=1701:1705;budgets=100000;conditions={'Q-reset','Rule-reset','Random-reset','EpsFixed-reset'};
if strcmp(mode,'smoke'),functions=[1,12];seeds=1701;budgets=600;end
jobs=cell(0,1);
for fid=functions
 for seed=seeds
  for budget=budgets
   for c=1:numel(conditions)
    count=4;useElite=true;stateMode='stagnation';useReheat=true;radiusMode='reset';switch conditions{c},case 'Q-reset',policy='q';case 'Rule-reset',policy='stallrule';case 'Random-reset',policy='random';case 'EpsFixed-reset',policy='epsfixed';end
    initSeed=21401012+fid*10000+seed;
    jobs{end+1}=struct('JobID',numel(jobs)+1,'Cohort',mode,'FunctionID',fid,'Seed',seed,'Dimension',50,'Population',50,'Budget',budget,'Condition',conditions{c},'SeekCandidateCount',count,'UseSeekingElite',useElite,'ModePolicy',policy,'RewardMode','binary','StateMode',stateMode,'StagnationThreshold',1000,'UseReheat',useReheat,'RadiusMode',radiusMode,'InitSeed',initSeed,'SearchSeed',initSeed+1000000); %#ok<AGROW>
   end
  end
 end
end
jobs=[jobs{:}];writetable(struct2table(jobs),fullfile(outDir,'job_manifest.csv'));
manifest=struct('Mode',mode,'Jobs',numel(jobs),'MATLAB',version,'Computer',computer,'Workers',4,'ThreadsPerWorker',1,'SourceFiles',{files},'ObjectiveBinary',fullfile(dataDir,'cec17_func.mexw64'),'Created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fid=fopen(fullfile(outDir,'environment.json'),'w');fprintf(fid,'%s',jsonencode(manifest,PrettyPrint=true));fclose(fid);
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
fut=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(fut);fut=parfevalOnAll(pool,@cd,0,dataDir);wait(fut);
records=cell(numel(jobs),1);fprintf('OUTDIR %s JOBS%d workers4\n',outDir,numel(jobs));
for first=1:12:numel(jobs)
 last=min(first+11,numel(jobs));batch=jobs(first:last);results=cell(numel(batch),1);
 parfor j=1:numel(batch),results{j}=runOne(batch(j),outDir);end
 records(first:last)=results;raw=struct2table([records{1:last}]);writetable(raw,fullfile(outDir,'raw_runs.csv'));save(fullfile(outDir,'checkpoint.mat'),'records','jobs');
 progress=struct('Completed',last,'Total',numel(jobs),'OK',sum(strcmp(raw.Status,'ok')),'Failed',sum(~strcmp(raw.Status,'ok')),'Date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
 fid=fopen(fullfile(outDir,'progress.json'),'w');fprintf(fid,'%s',jsonencode(progress,PrettyPrint=true));fclose(fid);fprintf('PROGRESS %d/%d ok%d fail%d %s\n',last,numel(jobs),progress.OK,progress.Failed,progress.Date);
 assert(progress.Failed==0,'Invalid simplification run; inspect saved raw/MAT.');
end
fid=fopen(fullfile(outDir,'COMPLETED.json'),'w');fprintf(fid,'%s',jsonencode(struct('Runs',numel(jobs),'Completed',true),PrettyPrint=true));fclose(fid);fprintf('DONE %s\n',outDir);
end
function rec=runOne(job,outDir)
D=job.Dimension;lb=-100*ones(1,D);ub=100*ones(1,D);rng(job.InitSeed,'twister');p0=lb+rand(50,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',job.Budget,'seekCandidateCount',job.SeekCandidateCount,'useSeekingElite',job.UseSeekingElite,'auditSimplify',false,'modePolicy',job.ModePolicy,'modeReward',job.RewardMode,'logTrajectory',true,'modeState',job.StateMode,'stagnationThreshold',job.StagnationThreshold,'useReheat',job.UseReheat,'radiusMode',job.RadiusMode);
calls=0;outside=0;rec=job;rec.FinalCost=NaN;rec.FinalError=NaN;rec.Seconds=NaN;rec.Evaluations=NaN;rec.ObjectiveCalls=NaN;rec.PostRunRecheckCalls=NaN;rec.OutsideCalls=NaN;rec.BestDiff=NaN;rec.TraceFinite=false;rec.TraceMonotone=false;rec.Error20FE=NaN;rec.Error60FE=NaN;rec.Error80FE=NaN;
rec.Rounds=NaN;rec.TracingEvaluations=NaN;rec.SeekingEvaluations=NaN;rec.MaxParentEvaluations=NaN;rec.MeanSeekCoverage=NaN;rec.TraceLocalSuccesses=NaN;rec.SeekMarginalSuccesses=NaN;rec.TraceGlobalSuccesses=NaN;rec.SeekGlobalSuccesses=NaN;rec.QuotaFallbackRounds=NaN;
rec.ReheatBlocks=NaN;rec.ReheatSeekingEvaluations=NaN;rec.Decisions=NaN;rec.QUpdates=NaN;rec.PositiveRewardBlocks=NaN;rec.Action1Share=NaN;rec.Action2Share=NaN;rec.Action3Share=NaN;rec.Status='error';rec.ErrorID='';rec.ErrorMessage='';B=[];T=[];I=[];started=tic;
try
 [B,T,I]=ASE_CSO_ModeQ_Reheat(@capture,state,[],50,job.SearchSeed);
 rec.Seconds=toc(started);callsRun=calls;rec.Evaluations=I.Evaluations;rec.ObjectiveCalls=callsRun;rec.OutsideCalls=outside;rec.TraceFinite=all(isfinite(T));rec.TraceMonotone=all(diff(T)<=0);
 assert(callsRun==job.Budget && I.Evaluations==job.Budget && numel(T)==job.Budget && outside==0 && rec.TraceFinite && rec.TraceMonotone);
 check=capture(B.Vector);rec.PostRunRecheckCalls=calls-callsRun;rec.BestDiff=abs(check-B.Cost);assert(rec.PostRunRecheckCalls==1 && rec.BestDiff<=1e-8*max(1,abs(B.Cost)));
 assert(I.TracingEvaluations+I.SeekingEvaluations==job.Budget-50 && I.Rounds==ceil((job.Budget-50)/10) && I.MaxParentEvaluations<=2);
 assert(I.SeekCandidateCount==job.SeekCandidateCount && I.UseSeekingElite==job.UseSeekingElite);
 L=I.RoundLog;assert(sum(L(:,3))==I.TracingEvaluations && sum(L(:,4))==I.SeekingEvaluations && all(L(:,2)-L(:,1)==L(:,3)+L(:,4)));
 rec.FinalCost=B.Cost;rec.FinalError=B.Cost-100*job.FunctionID;assert(rec.FinalError>=-1e-8);rec.Error20FE=T(round(.2*job.Budget))-100*job.FunctionID;rec.Error60FE=T(round(.6*job.Budget))-100*job.FunctionID;rec.Error80FE=T(round(.8*job.Budget))-100*job.FunctionID;
 rec.Rounds=I.Rounds;rec.TracingEvaluations=I.TracingEvaluations;rec.SeekingEvaluations=I.SeekingEvaluations;rec.MaxParentEvaluations=I.MaxParentEvaluations;rec.MeanSeekCoverage=mean(L(:,7));rec.TraceLocalSuccesses=sum(L(:,8));rec.SeekMarginalSuccesses=sum(L(:,9));rec.TraceGlobalSuccesses=sum(L(:,10));rec.SeekGlobalSuccesses=sum(L(:,11));Dlog=I.DecisionLog;rec.QuotaFallbackRounds=sum(Dlog(:,13));rec.ReheatBlocks=I.ReheatBlocks;rec.ReheatSeekingEvaluations=I.ReheatSeekingEvaluations;rec.Decisions=I.Decisions;rec.QUpdates=I.QUpdates;rec.PositiveRewardBlocks=sum(Dlog(:,10)>0);rec.Action1Share=mean(Dlog(:,4)==1);rec.Action2Share=mean(Dlog(:,4)==2);rec.Action3Share=mean(Dlog(:,4)==3);
 assert(I.Decisions==ceil((job.Budget-50)/100)&&~I.PendingAtEnd);
 if strcmp(job.ModePolicy,'q'),assert(I.QUpdates==sum(Dlog(:,13)==0));else,assert(I.QUpdates==0);end
 rec.Status='ok';
catch e,rec.Seconds=toc(started);rec.ObjectiveCalls=calls;rec.OutsideCalls=outside;rec.ErrorID=e.identifier;rec.ErrorMessage=e.message;end
save(fullfile(outDir,'runs',sprintf('job_%04d.mat',job.JobID)),'job','rec','B','T','I','p0');
 function value=capture(x)
  calls=calls+1;outside=outside+double(any(x<lb | x>ub));assert(calls<=job.Budget+1 && outside==0 && all(isfinite(x)));value=CEC2017Function(x,job.FunctionID);assert(isscalar(value) && isfinite(value));
 end
end
