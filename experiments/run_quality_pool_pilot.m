function run_quality_pool_pilot(seedStart,seedEnd)
% Predeclared D30 mechanism pilot. Save completed runs every four jobs.
if nargin<1, seedStart=101; end
if nargin<2, seedEnd=103; end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy'));
cd(fullfile(root,'data','cec2017'));
fids=[1 3 6 9 12 13 22 30]; seeds=seedStart:seedEnd;
methods={'geometry','random','reserved','credit'};
D=30; N=50; budget=60000; seedBase=20271012;
out=fullfile(root,'results','cec',['ase_quality_pool_pilot_s' num2str(seedStart) '_' num2str(seedEnd) '_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
mkdir(out); mkdir(fullfile(out,'source'));
copyfile(fullfile(root,'src','ASE_CSO_QualityPool.m'),fullfile(out,'source'));
copyfile([mfilename('fullpath') '.m'],fullfile(out,'source'));
copyfile(fullfile(root,'experiments','QUALITY_POOL_PLAN.md'),fullfile(out,'README.md'));
jobs=struct('FunctionID',{},'Seed',{},'Method',{},'InitSeed',{},'SearchSeed',{}); k=0;
for fid=fids
    for seed=seeds
        for m=1:numel(methods)
            k=k+1;
            jobs(k)=struct('FunctionID',fid,'Seed',seed,'Method',methods{m},...
                'InitSeed',seedBase+fid*1000+seed,'SearchSeed',seedBase+fid*1000+seed+100000);
        end
    end
end
pool=gcp('nocreate');
if isempty(pool), parpool('local',4);
elseif pool.NumWorkers~=4, delete(pool); parpool('local',4); end
records=cell(numel(jobs),1); sources=cell(numel(jobs),1); histories=cell(numel(jobs),1);
curves=cell(numel(jobs),1);
for first=1:4:numel(jobs)
    last=min(first+3,numel(jobs)); batch=jobs(first:last);
    br=cell(numel(batch),1); bs=br; bh=br; bc=br;
    parfor j=1:numel(batch)
        [br{j},bs{j},bh{j},bc{j}]=runJob(batch(j),D,N,budget);
    end
    records(first:last)=br; sources(first:last)=bs; histories(first:last)=bh; curves(first:last)=bc;
    writetable(struct2table([records{1:last}]),fullfile(out,'raw_runs.csv'));
    writetable(vertcat(sources{1:last}),fullfile(out,'source_diagnostics.csv'));
    writetable(vertcat(histories{1:last}),fullfile(out,'source_checkpoints.csv'));
    writetable(vertcat(curves{1:last}),fullfile(out,'convergence.csv'));
    fprintf('Completed %d/%d; output: %s\n',last,numel(jobs),out);
end
save(fullfile(out,'protocol.mat'),'jobs','fids','seeds','D','N','budget','seedBase');
fid=fopen(fullfile(root,'work','quality_pool_latest.txt'),'w'); fprintf(fid,'%s',out); fclose(fid);
fprintf('FINISHED %s\n',out);
end

function [record,sourceTable,historyTable,curveTable]=runJob(job,D,N,budget)
rng(job.InitSeed,'twister'); initial=-100+200*rand(N,D);
state=struct('initialPopulation',initial,'lowerBound',-100*ones(1,D),...
    'upperBound',100*ones(1,D),'maxEvaluations',budget,'selection',job.Method);
calls=0; bias=100*job.FunctionID;
[Best,T,info]=ASE_CSO_QualityPool(@objective,state,[],N,job.SearchSeed);
recheck=abs(CEC2017Function(Best.Vector,job.FunctionID)-Best.Cost);
assert(calls==budget && info.Evaluations==budget && numel(T)==budget,'FE mismatch');
assert(all(isfinite(T)) && all(diff(T)<=0),'Invalid convergence trace');
assert(recheck==0 && info.MaxParentEvaluations<=2,'Best or parent cap mismatch');
assert(info.CachedFallbackEvaluations==0,'Unexpected shortage of fresh candidates');
record=struct('FunctionID',job.FunctionID,'Function',sprintf('F%02d',job.FunctionID),...
    'Seed',job.Seed,'Dimension',D,'Method',['Quality-' job.Method],'Population',N,...
    'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'Budget',budget,...
    'FinalCost',Best.Cost,'FinalError',Best.Cost-bias,...
    'Error20FE',T(round(.2*budget))-bias,'Error60FE',T(round(.6*budget))-bias,...
    'Error80FE',T(round(.8*budget))-bias,'Evaluations',info.Evaluations,'ObjectiveCalls',calls,...
    'Seconds',info.Seconds,'BestRecheckAbsDiff',recheck,'TraceFinite',true,'TraceMonotone',true,...
    'SeekingEvaluations',info.SeekingEvaluations,'TracingEvaluations',info.TracingEvaluations,...
    'Rounds',info.Rounds,'MeanParentCoverage',info.MeanParentCoverage,...
    'MeanConcentration',info.MeanConcentration,'MaxParentEvaluations',info.MaxParentEvaluations,...
    'TraceSuccesses',info.TraceSuccesses,'TraceRollbacks',info.TraceRollbacks,...
    'SeekRollbacks',info.SeekRollbacks,'ExplorationReservations',info.ExplorationReservations,'Status','ok');
names={'Cognitive','Elite','CoordinateExemplar','Range'};
s=struct('FunctionID',{},'Seed',{},'Method',{},'Source',{},'Generated',{},'Eligible',{},...
    'Evaluated',{},'ParentSuccesses',{},'GlobalBestWins',{},'SumNormalizedParentGain',{},...
    'SumGlobalGain',{},'FinalCredit',{},'ZeroDirections',{},'CreditSelected',{});
h=struct('FunctionID',{},'Seed',{},'Method',{},'Source',{},'FE',{},'Generated',{},...
    'Eligible',{},'Evaluated',{},'ParentSuccesses',{},'GlobalBestWins',{},...
    'SumNormalizedParentGain',{},'SumGlobalGain',{},'Credit',{},'ZeroDirections',{}); k=0;
for source=1:4
    s(source)=struct('FunctionID',job.FunctionID,'Seed',job.Seed,'Method',record.Method,...
        'Source',names{source},'Generated',info.Generated(source),'Eligible',info.Eligible(source),...
        'Evaluated',info.SourceEvaluations(source),'ParentSuccesses',info.SourceSuccesses(source),...
        'GlobalBestWins',info.SourceGlobalWins(source),'SumNormalizedParentGain',info.SourceLocalGain(source),...
        'SumGlobalGain',info.SourceGlobalGain(source),'FinalCredit',info.FinalCredit(source),...
        'ZeroDirections',info.ZeroDirections(source),'CreditSelected',info.CreditSelected(source));
    checkpointFE=round(budget*[.2 .6 .8 1]);
    for cp=1:4
        k=k+1; v=squeeze(info.SourceHistory(cp,source,:));
        h(k)=struct('FunctionID',job.FunctionID,'Seed',job.Seed,'Method',record.Method,...
            'Source',names{source},'FE',checkpointFE(cp),...
            'Generated',v(1),'Eligible',v(2),'Evaluated',v(3),'ParentSuccesses',v(4),...
            'GlobalBestWins',v(5),'SumNormalizedParentGain',v(6),'SumGlobalGain',v(7),...
            'Credit',v(8),'ZeroDirections',v(9));
    end
end
sourceTable=struct2table(s); historyTable=struct2table(h);
nodes=unique([N round(budget*(.01:.01:1))]);
curveTable=table(repmat(job.FunctionID,numel(nodes),1),repmat(job.Seed,numel(nodes),1),...
    repmat(string(record.Method),numel(nodes),1),nodes',T(nodes)-bias,...
    'VariableNames',{'FunctionID','Seed','Method','FE','Error'});
    function value=objective(x)
        calls=calls+1;
        value=CEC2017Function(x,job.FunctionID);
    end
end
