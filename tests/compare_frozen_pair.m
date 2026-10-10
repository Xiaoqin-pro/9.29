function row=compare_frozen_pair(D,functionId,repeat,budget,useCEC)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root); setup_project(true);
previous=pwd; cleanup=onCleanup(@()cd(previous)); %#ok<NASGU>
if useCEC
    cd(fullfile(root,'data','cec2017')); clear cec17_func
    objective=@(x)CEC2017Function(x,functionId);
else
    objective=@(x)sum(x.^2);
end
initSeed=20271004+repeat; searchSeed=initSeed+100000;
rng(initSeed,'twister'); pop=-100+200*rand(50,D);
state=reference_frozen_state(pop,budget);
inputs=zeros(budget,D); count=0;
[oldBest,oldT,oldInfo]=DSS_RLCSO(@recordObjective,state,0,50,searchSeed);
oldRng=rng; oldInputs=inputs; oldCount=count;
inputs=zeros(budget,D); count=0;
[newBest,newT,newInfo]=ASE_CSO(@recordObjective,state,0,50,searchSeed);
newRng=rng;
assert(oldCount==budget && count==budget,'True FE mismatch');
assert(isequaln(oldInputs,inputs),'Evaluated candidate sequence mismatch');
assert(isequaln(oldBest,newBest),'Best mismatch');
assert(isequaln(oldT,newT),'Complete convergence trajectory mismatch');
assert(isequaln(oldRng,newRng),'Final RNG state mismatch');
fields={'Evaluations','InitialCost','InitialPopulation', ...
    'FirstImprovementEvaluation','SeekingEvaluations','TracingEvaluations', ...
    'CandidateEvaluations','EvaluationsPerRound','TargetTracingEvaluations', ...
    'ActualTracingEvaluations','TargetSeekingEvaluations','ActualSeekingEvaluations', ...
    'BudgetFillRate','ModeAllocationError','SeekingParentCoverage', ...
    'SeekingConcentration','SeekingMaxParentEvaluations', ...
    'SeekingGlobalImprovementCounts','TracingGlobalImprovementCounts', ...
    'SeekingGlobalGain','TracingGlobalGain'};
for k=1:numel(fields)
    key=fields{k};
    assert(isequaln(oldInfo.(key),newInfo.(key)),'Diagnostic mismatch: %s',key);
end
assert(all(isfinite(newT)) && all(diff(newT)<=0));
assert(all(newInfo.ModeAllocationError==0,'all'));
assert(all(newInfo.SeekingMaxParentEvaluations<=2));
row=table(D,functionId,repeat,budget,true,oldInfo.Seconds,newInfo.Seconds, ...
    'VariableNames',{'Dimension','Function','Seed','FE','Passed','ReferenceSeconds','FrozenSeconds'});
fprintf('PASS D=%d F=%d seed=%d FE=%d\n',D,functionId,repeat,budget);
    function value=recordObjective(x)
        count=count+1;
        assert(count<=budget,'Objective called beyond FE budget');
        inputs(count,:)=x;
        value=objective(x);
    end
end
