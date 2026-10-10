root = 'C:\repo_929';
addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy')); addpath(fullfile(root,'work','external_baselines')); cd(fullfile(root,'data','cec2017'));
if isempty(gcp('nocreate')), parpool('local',4); end
pctRunOnAll("addpath('C:\\repo_929\\src'); addpath('C:\\repo_929\\archive\\legacy'); addpath('C:\\repo_929\\work\\external_baselines'); cd('C:\\repo_929\\data\\cec2017');");
funcIds=[1 3:30]; seeds=101:110; N=50; D=30; budget=60000; lb=-100*ones(1,D); ub=100*ones(1,D);
outDir=fullfile(root,'results','external_threeway_29f_10seed_20261010'); if ~exist(outDir,'dir'), mkdir(outDir); end
csvPath=fullfile(outDir,'raw_runs.csv');
if exist(csvPath,'file'), delete(csvPath); end
nTasks=numel(funcIds)*numel(seeds); methods={'ASE-CSO','CLPSO','NRLPSO'};
results=cell(nTasks,1);
q=parallel.pool.DataQueue; completed=0; afterEach(q,@(~) progressTick());
parfor t=1:nTasks
  [fi,si]=ind2sub([numel(funcIds),numel(seeds)],t); fid=funcIds(fi); seed=seeds(si);
  f=@(x) CEC2017Function(x,fid);
  rng(seed,'twister'); pop=lb+(ub-lb).*rand(N,D);
  state=struct('initialPopulation',pop,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
  local=repmat(struct('method','','function_id',0,'seed',0,'final_cost',NaN,'seconds',NaN,'evaluations',NaN,'mutation_evaluations',NaN,'status','','protocol','D30_FE60000_same_population'),numel(methods),1);
  for m=1:numel(methods)
    method=methods{m}; t0=tic; mut=0; evals=NaN; status='ok'; finalCost=NaN;
    try
      switch method
        case 'ASE-CSO', [B,~,I]=ASE_CSO(f,state,[],N,seed);
        case 'CLPSO', [B,~,I]=CLPSO_CEC(f,state,[],N,seed);
        case 'NRLPSO', [B,~,I]=NRLPSO_CEC(f,state,N,seed); mut=I.MutationEvaluations;
      end
      finalCost=B.Cost; evals=I.Evaluations;
      if evals~=budget || ~isfinite(finalCost), status='invalid'; end
    catch ME
      status=['error:' ME.identifier];
    end
    local(m)=struct('method',method,'function_id',fid,'seed',seed,'final_cost',finalCost,'seconds',toc(t0),'evaluations',evals,'mutation_evaluations',mut,'status',status,'protocol','D30_FE60000_same_population');
  end
  results{t}=local;
  send(q,t);
end
raw=repmat(results{1},nTasks,1);
for t=1:nTasks, raw((t-1)*numel(methods)+1:t*numel(methods))=results{t}; end
rawTable=struct2table(raw); writetable(rawTable,csvPath); writetable(rawTable,fullfile(outDir,'raw_runs_typed.csv'));
summary=table();
for mi=1:numel(methods)
  for fid=funcIds
    mask=rawTable.method==string(methods{mi}) & rawTable.function_id==fid & rawTable.status=="ok";
    vals=rawTable.final_cost(mask); times=rawTable.seconds(mask);
    summary=[summary; table(string(methods{mi}),fid,mean(vals),median(vals),std(vals),mean(times),numel(vals),'VariableNames',{'method','function_id','mean_final_cost','median_final_cost','std_final_cost','mean_seconds','n'})]; %#ok<AGROW>
  end
end
writetable(summary,fullfile(outDir,'summary.csv'));
fprintf('DONE %d tasks x %d methods = %d runs\n',nTasks,numel(methods),nTasks*numel(methods));
function progressTick()
  persistent done
  if isempty(done), done=0; end
  done=done+1;
  if mod(done,10)==0 || done==1, fprintf('completed %d tasks\n',done); end
end
