root='C:\repo_929'; addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy')); cd(fullfile(root,'data','cec2017'));
if isempty(gcp('nocreate')), parpool('local',4); end
pctRunOnAll("addpath('C:\\repo_929\\src'); addpath('C:\\repo_929\\archive\\legacy'); cd('C:\\repo_929\\data\\cec2017');");
funcIds=[1 3:30]; seeds=101:110; D=30; Nbase=50; Nnrl=40; budget=60000; lb=-100*ones(1,D); ub=100*ones(1,D); methods={'ASE-CSO','CLPSO','NRLPSO-PaperAligned'}; nTasks=numel(funcIds)*numel(seeds); nMethods=numel(methods);
outDir=fullfile(root,'results','external_threeway_detailed_29f_10seed_20261010'); if ~exist(outDir,'dir'),mkdir(outDir);end
nTasksTotal=nTasks; results=cell(nTasksTotal,1); q=parallel.pool.DataQueue; afterEach(q,@(~) progressTick());
parfor t=1:nTasksTotal
 [fi,si]=ind2sub([numel(funcIds),numel(seeds)],t); fid=funcIds(fi); seed=seeds(si);
 rng(seed,'twister'); pop50=lb+(ub-lb).*rand(Nbase,D); pop40=pop50(1:Nnrl,:);
 local=repmat(blankRecord(),nMethods,1);
 for m=1:nMethods
  method=methods{m}; if strcmp(method,'NRLPSO-PaperAligned'), pop0=pop40; N=Nnrl; else, pop0=pop50; N=Nbase; end
  state=struct('initialPopulation',pop0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
  counter=CountingObjective(@(x) CEC2017Function(x,fid)); f=@(x) counter.evaluate(x); t0=tic; status='ok'; errId=''; errMsg=''; B=[]; T=[]; I=[];
  try
   switch method
    case 'ASE-CSO', [B,T,I]=ASE_CSO(f,state,[],N,seed);
    case 'CLPSO', [B,T,I]=CLPSO_CEC(f,state,[],N,seed);
    case 'NRLPSO-PaperAligned', [B,T,I]=NRLPSO_CEC_PaperAligned(f,state,[],seed);
   end
   callsRun=counter.Calls; evals=I.Evaluations; recheck=f(B.Vector); callsAfter=counter.Calls;
   finiteTrace=~isempty(T) && numel(T)>=budget && all(isfinite(T(1:budget)));
   monotoneTrace=finiteTrace && all(diff(T(1:budget))<=1e-8*max(1,max(abs(T(1:budget)))));
   bestConsistent=abs(recheck-B.Cost)<=1e-7*max(1,abs(B.Cost));
   callConsistent=(callsRun==budget); if strcmp(method,'NRLPSO-PaperAligned'), callConsistent=callConsistent && isfield(I,'ObjectiveCalls') && I.ObjectiveCalls==callsRun; end
   if evals~=budget || callsRun~=budget || callsAfter~=budget+1 || ~isfinite(B.Cost) || ~finiteTrace || ~monotoneTrace || ~bestConsistent || ~callConsistent, status='invalid'; end
  catch ME
   callsRun=counter.Calls; callsAfter=counter.Calls; evals=NaN; recheck=NaN; finiteTrace=false; monotoneTrace=false; bestConsistent=false; callConsistent=false; status='error'; errId=ME.identifier; errMsg=ME.message;
  end
  rec=blankRecord(); rec.method=method; rec.function_id=fid; rec.seed=seed; rec.dimension=D; rec.budget=budget; rec.population=N; rec.initial_population_shared_prefix=(N==Nnrl); rec.final_cost=getCost(B); rec.best_recheck_cost=recheck; rec.best_recheck_absdiff=abs(recheck-rec.final_cost); rec.seconds=toc(t0); rec.evaluations=getField(I,'Evaluations'); rec.objective_calls_run=callsRun; rec.objective_calls_after_recheck=callsAfter; rec.postrun_recheck_calls=callsAfter-callsRun; rec.call_audit=(callsRun==budget && callsAfter==budget+1); rec.trace_finite=finiteTrace; rec.trace_monotone=monotoneTrace; rec.best_consistent=bestConsistent; rec.status=status; rec.error_id=errId; rec.error_message=errMsg; rec.protocol='D30_FE60000_seed101_110_N50_ASE_CLPSO_N40_NRLPSO_shared_prefix';
  if ~isempty(T) && numel(T)>=budget, rec.trace_fe_50=T(50); rec.trace_fe_6000=T(6000); rec.trace_fe_18000=T(18000); rec.trace_fe_30000=T(30000); rec.trace_fe_45000=T(45000); rec.trace_fe_60000=T(60000); else, rec.trace_fe_50=NaN; rec.trace_fe_6000=NaN; rec.trace_fe_18000=NaN; rec.trace_fe_30000=NaN; rec.trace_fe_45000=NaN; rec.trace_fe_60000=NaN; end
  if strcmp(method,'NRLPSO-PaperAligned') && ~isempty(I), rec.mutation_evaluations=getField(I,'MutationEvaluations'); rec.mutation_calls=getField(I,'MutationCalls'); rec.mutation_out_of_bounds=getField(I,'MutationOutOfBounds'); rec.alpha_min=getField(I,'AlphaMin'); rec.alpha_max=getField(I,'AlphaMax'); rec.inertia_min=getField(I,'InertiaMin'); rec.inertia_max=getField(I,'InertiaMax'); rec.action_1=getField(I,'ActionCounts'); ac=getField(I,'ActionCounts'); if numel(ac)==4, rec.action_1=ac(1);rec.action_2=ac(2);rec.action_3=ac(3);rec.action_4=ac(4);end; end
  local(m)=rec;
 end
 results{t}=local; send(q,t);
end
raw=repmat(results{1}(1),nTasks*nMethods,1); z=1; for t=1:nTasks, for m=1:nMethods, raw(z)=results{t}(m); z=z+1; end, end
rawTable=struct2table(raw); writetable(rawTable,fullfile(outDir,'detailed_raw_runs.csv')); writetable(rawTable,fullfile(outDir,'detailed_raw_runs_typed.csv'));
summary=table();
for mi=1:nMethods
 for fid=funcIds
  mask=rawTable.method==string(methods{mi}) & rawTable.function_id==fid & rawTable.status=="ok"; vals=rawTable.final_cost(mask); times=rawTable.seconds(mask); summary=[summary;table(string(methods{mi}),fid,mean(vals),median(vals),std(vals),mean(times),numel(vals),sum(mask),'VariableNames',{'method','function_id','mean_final_cost','median_final_cost','std_final_cost','mean_seconds','valid_n','records_n'})]; %#ok<AGROW>
 end
end
writetable(summary,fullfile(outDir,'detailed_summary_by_function.csv'));
checks=rawTable(:,{'method','function_id','seed','population','evaluations','objective_calls_run','objective_calls_after_recheck','call_audit','trace_finite','trace_monotone','best_consistent','status'}); writetable(checks,fullfile(outDir,'audit_checks.csv'));
copyfile(fullfile(root,'src','ASE_CSO.m'),fullfile(outDir,'ASE_CSO.m')); copyfile(fullfile(root,'archive','legacy','CLPSO_CEC.m'),fullfile(outDir,'CLPSO_CEC.m')); copyfile(fullfile(root,'src','NRLPSO_CEC_PaperAligned.m'),fullfile(outDir,'NRLPSO_CEC_PaperAligned.m'));
fid=fopen(fullfile(outDir,'README.md'),'w'); fprintf(fid,'# Detailed three-algorithm comparison\n\nD30, CEC2017 F1 and F3-F30, 60000 FE, seeds 101-110, four MATLAB workers. ASE-CSO and CLPSO use NP=50; paper-aligned NRLPSO uses NP=40, so this is an FE-matched comparison with a shared 40-point prefix, not identical populations. Each algorithm has an independent objective-call counter and one post-run Best recheck excluded from the budget.\n\nMethods: ASE-CSO, CLPSO, NRLPSO-PaperAligned. NRLPSO is an independent reproduction, not an official author implementation.\n'); fclose(fid);
fprintf('DONE %d tasks x %d methods = %d runs\n',nTasks,nMethods,nTasks*nMethods);
function rec=blankRecord()
rec=struct('method','','function_id',NaN,'seed',NaN,'dimension',NaN,'budget',NaN,'population',NaN,'initial_population_shared_prefix',false,'final_cost',NaN,'best_recheck_cost',NaN,'best_recheck_absdiff',NaN,'seconds',NaN,'evaluations',NaN,'objective_calls_run',NaN,'objective_calls_after_recheck',NaN,'postrun_recheck_calls',NaN,'call_audit',false,'trace_finite',false,'trace_monotone',false,'best_consistent',false,'trace_fe_50',NaN,'trace_fe_6000',NaN,'trace_fe_18000',NaN,'trace_fe_30000',NaN,'trace_fe_45000',NaN,'trace_fe_60000',NaN,'mutation_evaluations',NaN,'mutation_calls',NaN,'mutation_out_of_bounds',NaN,'alpha_min',NaN,'alpha_max',NaN,'inertia_min',NaN,'inertia_max',NaN,'action_1',NaN,'action_2',NaN,'action_3',NaN,'action_4',NaN,'status','','error_id','','error_message','','protocol','');
end
function v=getField(S,name), if isstruct(S) && isfield(S,name), v=S.(name); else, v=NaN; end, end
function v=getCost(B), if isempty(B), v=NaN; else, v=B.Cost; end, end
function progressTick(), persistent done; if isempty(done), done=0; end; done=done+1; if mod(done,10)==0 || done==1, fprintf('completed %d tasks\n',done); end, end

