function run_sparse_alloc_q_sweep
% Coarse Q hyperparameter sweep. Every batch is checkpointed to CSV.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy'));
cd(fullfile(root,'data','cec2017'));
fids=[1 3 6 9 12 22]; seeds=101:103; alphas=[.1 .3]; gammas=[.7 .9 .99]; epsilons=[.05 .10];
D=30; N=50; budget=60000; workers=4; batchSize=4; seedBase=20271012;
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss')); out=fullfile(root,'results','cec',['sparse_alloc_q_sweep_' stamp]); mkdir(out);
jobs=struct('FunctionID',{},'Seed',{},'Alpha',{},'Gamma',{},'Epsilon',{},'InitSeed',{},'SearchSeed',{}); k=0;
for fid=fids, for seed=seeds, for a=1:numel(alphas), for g=1:numel(gammas), for e=1:numel(epsilons)
    k=k+1; jobs(k)=struct('FunctionID',fid,'Seed',seed,'Alpha',alphas(a),'Gamma',gammas(g),'Epsilon',epsilons(e),...
        'InitSeed',seedBase+fid*1000+seed,'SearchSeed',seedBase+fid*1000+seed+100000);
end,end,end,end,end
pool=gcp('nocreate'); if isempty(pool), parpool('local',workers); elseif pool.NumWorkers~=workers, delete(pool); parpool('local',workers); end
records=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); br=cell(numel(batch),1);
    parfor j=1:numel(batch), br{j}=runJob(batch(j),D,N,budget); end
    records(first:last)=br; writetable(struct2table([records{1:last}]),fullfile(out,'raw_runs.csv'));
    fprintf('Completed %d/%d, output=%s\n',last,numel(jobs),out);
end
save(fullfile(out,'protocol.mat'),'jobs','fids','seeds','alphas','gammas','epsilons','D','N','budget');
fid=fopen(fullfile(root,'work','sparse_alloc_q_sweep_latest.txt'),'w'); fprintf(fid,'%s',out); fclose(fid);
fprintf('FINISHED %s\n',out);
end

function record=runJob(job,D,N,budget)
rng(job.InitSeed,'twister'); pop0=-100+200*rand(N,D); calls=0; bias=100*job.FunctionID;
state=struct('initialPopulation',pop0,'lowerBound',-100*ones(1,D),'upperBound',100*ones(1,D),...
    'maxEvaluations',budget,'policy','q','alpha',job.Alpha,'gamma',job.Gamma,'epsilon',job.Epsilon);
[Best,T,info]=ASE_CSO_SparseAlloc(@objective,state,[],N,job.SearchSeed);
recheck=abs(CEC2017Function(Best.Vector,job.FunctionID)-Best.Cost);
assert(calls==budget && info.Evaluations==budget && numel(T)==budget && recheck==0);
assert(all(isfinite(T)) && all(diff(T)<=0) && info.MaxParentEvaluations<=2);
record=struct('FunctionID',job.FunctionID,'Function',sprintf('F%02d',job.FunctionID),'Seed',job.Seed,...
    'Alpha',job.Alpha,'Gamma',job.Gamma,'Epsilon',job.Epsilon,'Dimension',D,'Population',N,'Budget',budget,...
    'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'FinalError',Best.Cost-bias,...
    'Error20FE',T(round(.2*budget))-bias,'Error60FE',T(round(.6*budget))-bias,...
    'Error80FE',T(round(.8*budget))-bias,'Evaluations',info.Evaluations,'ObjectiveCalls',calls,'Seconds',info.Seconds,...
    'BestRecheckAbsDiff',recheck,'MeanParentCoverage',info.MeanParentCoverage,'MeanConcentration',info.MeanConcentration,...
    'MaxParentEvaluations',info.MaxParentEvaluations,'ContinueActions',info.ContinueActions,'SwitchActions',info.SwitchActions,...
    'QVisits1',info.QVisits(1),'QVisits2',info.QVisits(2),'QVisits3',info.QVisits(3),'QVisits4',info.QVisits(4),...
    'QCont1',info.QTable(1,1),'QSwitch1',info.QTable(1,2),'QCont2',info.QTable(2,1),'QSwitch2',info.QTable(2,2),...
    'QCont3',info.QTable(3,1),'QSwitch3',info.QTable(3,2),'QCont4',info.QTable(4,1),'QSwitch4',info.QTable(4,2),...
    'Status','ok');
    function value=objective(x), calls=calls+1; value=CEC2017Function(x,job.FunctionID); end
end
