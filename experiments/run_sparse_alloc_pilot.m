function run_sparse_alloc_pilot
% Causal pilot for sparse Seeking-credit allocation.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy'));
cd(fullfile(root,'data','cec2017'));
fids=[1 3 6 9 12 13 22 30]; seeds=101:105; policies={'continue','switch','random','q'};
D=30; N=50; budget=60000; workers=4; batchSize=4; seedBase=20271012;
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
out=fullfile(root,'results','cec',['sparse_alloc_pilot_' stamp]); mkdir(out);
jobs=struct('FunctionID',{},'Seed',{},'Policy',{},'InitSeed',{},'SearchSeed',{}); k=0;
for fid=fids
    for seed=seeds
        for p=1:numel(policies)
            k=k+1; jobs(k)=struct('FunctionID',fid,'Seed',seed,'Policy',policies{p},...
                'InitSeed',seedBase+fid*1000+seed,'SearchSeed',seedBase+fid*1000+seed+100000);
        end
    end
end
pool=gcp('nocreate'); if isempty(pool), parpool('local',workers); elseif pool.NumWorkers~=workers, delete(pool); parpool('local',workers); end
records=cell(numel(jobs),1); diagnostics=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); br=cell(numel(batch),1); bd=br;
    parfor j=1:numel(batch), [br{j},bd{j}]=runJob(batch(j),D,N,budget); end
    records(first:last)=br; diagnostics(first:last)=bd;
    writetable(struct2table([records{1:last}]),fullfile(out,'raw_runs.csv'));
    writetable(vertcat(diagnostics{1:last}),fullfile(out,'allocation_diagnostics.csv'));
    fprintf('Completed %d/%d, output=%s\n',last,numel(jobs),out);
end
save(fullfile(out,'protocol.mat'),'jobs','fids','seeds','D','N','budget','policies');
fid=fopen(fullfile(root,'work','sparse_alloc_latest.txt'),'w'); fprintf(fid,'%s',out); fclose(fid);
fprintf('FINISHED %s\n',out);
end

function [record,diag]=runJob(job,D,N,budget)
rng(job.InitSeed,'twister'); pop0=-100+200*rand(N,D); calls=0; bias=100*job.FunctionID;
state=struct('initialPopulation',pop0,'lowerBound',-100*ones(1,D),...
    'upperBound',100*ones(1,D),'maxEvaluations',budget,'policy',job.Policy);
[Best,T,info]=ASE_CSO_SparseAlloc(@objective,state,[],N,job.SearchSeed);
recheck=abs(CEC2017Function(Best.Vector,job.FunctionID)-Best.Cost);
assert(calls==budget && info.Evaluations==budget && numel(T)==budget);
assert(recheck==0 && all(isfinite(T)) && all(diff(T)<=0) && info.MaxParentEvaluations<=2);
record=struct('FunctionID',job.FunctionID,'Function',sprintf('F%02d',job.FunctionID),...
    'Seed',job.Seed,'Policy',job.Policy,'Dimension',D,'Population',N,'Budget',budget,...
    'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'FinalError',Best.Cost-bias,...
    'Error20FE',T(round(.2*budget))-bias,'Error60FE',T(round(.6*budget))-bias,...
    'Error80FE',T(round(.8*budget))-bias,'Evaluations',info.Evaluations,'ObjectiveCalls',calls,...
    'Seconds',info.Seconds,'BestRecheckAbsDiff',recheck,'MeanParentCoverage',info.MeanParentCoverage,...
    'MeanConcentration',info.MeanConcentration,'MaxParentEvaluations',info.MaxParentEvaluations,...
    'ContinueActions',info.ContinueActions,'SwitchActions',info.SwitchActions,...
    'TraceSuccesses',info.TraceSuccesses,'TraceRollbacks',info.TraceRollbacks,'Status','ok');
diag=table(repmat(job.FunctionID,4,1),repmat(job.Seed,4,1),repmat(string(job.Policy),4,1),info.QVisits(:),...
    'VariableNames',{'FunctionID','Seed','Policy','QVisits'});
diag.QState=(1:4)'; diag.QContinue=zeros(4,1); diag.QSwitch=zeros(4,1);
if strcmp(job.Policy,'q'), diag.QContinue=info.QTable(:,1); diag.QSwitch=info.QTable(:,2); end
    function value=objective(x), calls=calls+1; value=CEC2017Function(x,job.FunctionID); end
end
