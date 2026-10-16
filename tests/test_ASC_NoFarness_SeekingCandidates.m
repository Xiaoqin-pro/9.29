function test_ASC_NoFarness_SeekingCandidates
%TEST_ASC_NOFARNESS_SEEKINGCANDIDATES  Correctness audit of the seeking-candidate
%   variants A0-A3 on the frozen ASC-NoFarness search core.
%
% The audit answers four questions before any performance run is trusted:
%   1. does A0 reproduce ASC_NoFarness pointwise, including the RNG stream, the
%      objective evaluation points and the original round log;
%   2. with refineCount = 0 do A1/A2/A3 also collapse exactly onto A0, i.e. is
%      the change really confined to the last `refineCount` candidates;
%   3. does each variant actually route evaluations to its new candidate type,
%      and do the candidate-type counters still add up to the fixed budget;
%   4. are the search framework parameters (Tracing, Jump, screening, adaptive
%      control) unchanged.
%
% Objective evaluations made here are audit calls and are reported separately.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','sc_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

% --- 1. A0 versus the frozen original ------------------------------------
[ptsA0,BA0,TA0,IA0,rsA0]=runOnce('sphere',BUD1,'A0',2);
[ptsOr,BO,TO,IO,rsOr]=runOnceOriginal('sphere',BUD1);
assert(isequal(ptsA0,ptsOr),'A0 changed the objective evaluation points of the original.');
assert(isequal(BA0,BO)&&isequal(TA0,TO),'A0 changed the result or the best-so-far trace.');
assert(isequal(rsA0,rsOr),'A0 changed the global RNG state of the original.');
assert(isequal(IA0.RoundLog(:,1:15),IO.RoundLog(:,1:15)),'A0 changed the original round log.');
checks{end+1}=struct('Check','A0-pointwise-original-including-RNG-and-round-log','Passed',true);

% --- 2. refineCount = 0 collapses every variant onto A0 ------------------
for variant={'A1','A2','A3'}
    [pts,Bv,Tv,Iv]=runOnce('sphere',BUD1,variant{1},0);
    assert(isequal(pts,ptsA0),sprintf('%s with refineCount=0 changed the evaluation points.',variant{1}));
    assert(isequal(Bv,BA0)&&isequal(Tv,TA0),sprintf('%s with refineCount=0 changed the result.',variant{1}));
    assert(all(Iv.CandidateDiagnostics.SeekEval(2:4)==0));
end
checks{end+1}=struct('Check','Zero-refine-count-collapses-A1-A2-A3-onto-A0','Passed',true);

% --- 3. each variant routes evaluations to its own candidate type --------
for spec={ {'A1',2},{'A2',3},{'A3',4} }
    variant=spec{1}{1};expectType=spec{1}{2};
    [~,~,Tv,Iv]=runOnce('sphere',BUD1,variant,2);
    dg=Iv.CandidateDiagnostics;
    assert(dg.SeekEval(expectType)>0, ...
        sprintf('%s never had a refined candidate evaluated.',variant));
    assert(sum(dg.SeekEval(2:4))>0&&dg.SeekEval(1)>0, ...
        sprintf('%s lost either the original or the refined candidates.',variant));
    assert(all(dg.SeekEval(setdiff(2:4,expectType))==0), ...
        sprintf('%s produced an unexpected candidate type.',variant));
    checkBudget(Iv,Tv,BUD1,variant);
end
[~,~,T0,I0]=runOnce('sphere',BUD1,'A0',2);
assert(all(I0.CandidateDiagnostics.SeekEval(2:4)==0)&&I0.CandidateDiagnostics.SeekEval(1)>0);
checkBudget(I0,T0,BUD1,'A0');
checks{end+1}=struct('Check','Each-variant-evaluates-its-own-candidate-type','Passed',true);

% --- 4. odd tail budget --------------------------------------------------
[~,~,TT,IT]=runOnce('flat',1257,'A3',2);
assert(numel(TT)==1257&&IT.Evaluations==1257,'Odd tail budget was not consumed exactly.');
checkBudget(IT,TT,1257,'A3');
checks{end+1}=struct('Check','Odd-tail-budget-exact-count','Passed',true);

% --- 5. grouped candidate path still runs --------------------------------
for variant={'A0','A1','A2','A3'}
    [~,~,~,Ig]=runOnce('sphere',BUD1,variant{1},2,struct('useGroup',true),4711,true);
    assert(Ig.Evaluations==BUD1,'Grouped path lost evaluations.');
end
checks{end+1}=struct('Check','Grouped-path-evaluations-all-variants','Passed',true);

% --- 6. real CEC2017 objectives ------------------------------------------
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for variant={'A0','A1','A2','A3'}
        cecID=fid;currentMode='cec';
        s=makeState(lb+rand(N,D).*(ub-lb),BUD1,variant{1},2,262015000+fid*10000+6401);
        calls=0;recPoints=zeros(BUD1,D);
        [Bc,Tc,Ic]=ASC_NoFarness_SeekingCandidates(@objective,s,[],N,262026401);
        assert(calls==BUD1&&Ic.Evaluations==BUD1&&numel(Tc)==BUD1);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        checkBudget(Ic,Tc,BUD1,variant{1});
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions-four-variants','Passed',true);

% --- 7. headline claim: full 100k A0 parity ------------------------------
currentMode='cec';cecID=1;BUD2=100000;
rng(262026401,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,'A0',2,262026401);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_SeekingCandidates(@objective,s,[],N,262026401);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262026401);
assert(isequal(BF,BO2)&&isequal(TF,TO2),'Full-budget A0 changed the final answer or the trace.');
assert(isequal(pF,recPoints),'Full-budget A0 changed the objective evaluation points.');
assert(isequal(rngStateF,rng),'Full-budget A0 changed the global RNG state.');
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15)),'Full-budget A0 changed the round log.');
assert(calls==100000,'Full-budget original did not consume exactly 100k evaluations.');
checkBudget(IF,TF,BUD2,'A0');
checks{end+1}=struct('Check','Full100k-A0-original-pointwise-and-RNG-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_SeekingCandidates.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,variant,refineCount,initSeed)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'seekVariant',variant,'seekRefineCount',refineCount);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,variant,refineCount,extra,initSeed,skipReset)
        if nargin<5,extra=struct();end
        if nargin<6,initSeed=4711;end
        if nargin<7,skipReset=false;end
        currentMode=modeName;
        if ~skipReset,rng(initSeed,'twister');end
        pop0=lb+rand(N,D).*(ub-lb);
        s=makeState(pop0,budget,variant,refineCount,initSeed);
        fn=fieldnames(extra);
        for k=1:numel(fn),s.(fn{k})=extra.(fn{k});end
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_SeekingCandidates(@objective,s,[],N,initSeed);
        ptsOut=recPoints;rngState=rng;
    end

    function [ptsOut,B,T,I,rngState]=runOnceOriginal(modeName,budget)
        currentMode=modeName;rng(4711,'twister');
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',lb+rand(N,D).*(ub-lb));
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness(@objective,s,[],N,4711);
        ptsOut=recPoints;rngState=rng;
    end

    function checkBudget(I,T,budget,variant)
        dg=I.CandidateDiagnostics;
        P=I.Parameters;
        assert(strcmp(I.SeekVariant,variant)&&strcmp(I.Variant,['ASC-NoFarness-' variant]));
        assert(sum(dg.SeekEval)+dg.TraceEval+dg.OtherEval==budget-N, ...
            'Candidate-type evaluation counts do not add up to the budget.');
        assert(dg.TraceEval>0,'The Tracing branch never earned an evaluation.');
        assert(all(dg.SeekEval>=0)&&all(dg.SeekImpPbest<=dg.SeekEval));
        assert(all(dg.SeekImpGlobal<=dg.SeekEval));
        assert(all(dg.SeekDistSum>=0));
        assert(all(dg.SeekEval==0|dg.SeekDistSum>0), ...
            'An evaluated candidate type carries no distance record.');
        % the search framework must be untouched by this study
        assert(P.seekEliteGain==0&&P.traceBoostGain==0,'A search term was switched on.');
        assert(P.useJump&&P.jumpFraction==0.50&&P.jumpGens==20);
        assert(~P.useGroup&&~P.useOBL&&~P.useGaussBest&&~strcmp(P.seekNoise,'gaussian'));
        assert(P.evaluationsPerRound==10&&P.perOwnerCap==2);
        assert(P.inertiaStart==0.90&&P.inertiaEnd==0.40);
        assert(P.radiusMin==0.020&&P.radiusMax==0.200&&P.seekCandidateCount==4);
        assert(P.seekDimFraction==0.20&&P.eliteFraction==0.20);
        assert(numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0));
    end

    function value=objective(x)
        calls=calls+1;totalCalls=totalCalls+1;
        assert(calls<=size(recPoints,1),'Objective was called more often than budgeted.');
        assert(all(isfinite(x))&&all(x>=lb&x<=ub),'Objective received an invalid point.');
        recPoints(calls,:)=x;
        if strcmp(currentMode,'sphere')
            value=sum(x.^2);
        elseif strcmp(currentMode,'flat')
            value=1;
        else
            value=CEC2017Function(x,cecID);
        end
    end
end

function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);
m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);
d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
