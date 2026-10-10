root = 'C:\repo_929';
addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy')); addpath(fullfile(root,'work','external_baselines')); cd(fullfile(root,'data','cec2017'));
if isempty(gcp('nocreate')), parpool('local',4); end
pctRunOnAll("addpath('C:\\repo_929\\src'); addpath('C:\\repo_929\\archive\\legacy'); addpath('C:\\repo_929\\work\\external_baselines'); cd('C:\\repo_929\\data\\cec2017');");
funcIds=[1 3:30]; seeds=101:110; N=40; D=30; budget=60000; lb=-100*ones(1,D); ub=100*ones(1,D);
outDir=fullfile(root,'results','external_nrlpso_paperaligned_29f_10seed_20261010');
if ~exist(outDir,'dir'), mkdir(outDir); end
checkpointDir=fullfile(outDir,'checkpoints'); if ~exist(checkpointDir,'dir'), mkdir(checkpointDir); end
nTasks=numel(funcIds)*numel(seeds); results=cell(nTasks,1);
q=parallel.pool.DataQueue; afterEach(q,@(~) progressTick());
parfor t=1:nTasks
  [fi,si]=ind2sub([numel(funcIds),numel(seeds)],t); fid=funcIds(fi); seed=seeds(si);
  f=@(x) CEC2017Function(x,fid);
  rng(seed,'twister'); pop=lb+(ub-lb).*rand(N,D);
  state=struct('initialPopulation',pop,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
  t0=tic; finalCost=NaN; evals=NaN; status='ok'; mut=NaN; calls=NaN; alphaMin=NaN; alphaMax=NaN; inertiaMin=NaN; inertiaMax=NaN; actionCounts=zeros(1,4); errId=''; errMsg='';
  try
    [B,~,I]=NRLPSO_CEC_PaperAligned(f,state,[],seed);
    finalCost=B.Cost; evals=I.Evaluations; mut=I.MutationEvaluations; calls=I.MutationCalls; alphaMin=I.AlphaMin; alphaMax=I.AlphaMax; inertiaMin=I.InertiaMin; inertiaMax=I.InertiaMax; actionCounts=I.ActionCounts;
    if evals~=budget || ~isfinite(finalCost), status='invalid'; end
  catch ME
    status='error'; errId=ME.identifier; errMsg=ME.message;
  end
  record=struct('method','NRLPSO-PaperAligned','function_id',fid,'seed',seed,'final_cost',finalCost,'seconds',toc(t0),'evaluations',evals,'mutation_evaluations',mut,'mutation_calls',calls,'alpha_min',alphaMin,'alpha_max',alphaMax,'inertia_min',inertiaMin,'inertia_max',inertiaMax,'action_1',actionCounts(1),'action_2',actionCounts(2),'action_3',actionCounts(3),'action_4',actionCounts(4),'status',status,'error_id',errId,'error_message',errMsg,'protocol','D30_FE60000_NP40_k8_c2_1p9_same_seed_distinct_population');
  results{t}=record; send(q,t);
end
raw=repmat(results{1},nTasks,1); for t=1:nTasks, raw(t)=results{t}; end
rawTable=struct2table(raw); writetable(rawTable,fullfile(outDir,'raw_runs.csv')); writetable(rawTable,fullfile(outDir,'raw_runs_typed.csv'));
summary=table();
for fid=funcIds
  mask=rawTable.function_id==fid & rawTable.status=="ok"; vals=rawTable.final_cost(mask); times=rawTable.seconds(mask);
  summary=[summary; table(fid,mean(vals),median(vals),std(vals),mean(times),numel(vals),'VariableNames',{'function_id','mean_final_cost','median_final_cost','std_final_cost','mean_seconds','n'})]; %#ok<AGROW>
end
writetable(summary,fullfile(outDir,'summary.csv'));
copyfile(fullfile(root,'work','external_baselines','NRLPSO_CEC_PaperAligned.m'),fullfile(outDir,'NRLPSO_CEC_PaperAligned.m'));
fid=fopen(fullfile(outDir,'PROTOCOL.txt'),'w'); fprintf(fid,'Corrected paper-aligned NRLPSO independent reproduction\nD=30, FE=60000, functions F1,F3-F30, seeds 101:110, NP=40, k=8, c2=1.9, 4 workers.\nThis is not an official author implementation. It uses distinct NP=40 initial populations, so old NP=50 results are exploratory and not paired.\n'); fclose(fid);
fprintf('DONE %d tasks / %d runs\n',nTasks,nTasks);
function progressTick()
 persistent done; if isempty(done), done=0; end; done=done+1; if mod(done,10)==0 || done==1, fprintf('completed %d tasks\n',done); end
end


