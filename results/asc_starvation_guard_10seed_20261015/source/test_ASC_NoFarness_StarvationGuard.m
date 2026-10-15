function test_ASC_NoFarness_StarvationGuard
%TEST_ASC_NOFARNESS_STARVATIONGUARD  Correctness audit of the evaluation
%   starvation guard built on the stage-scheduled learning core.
%
% The audit answers four questions before any performance run is trusted:
%   1. with guardRounds = 0 the file is bit-identical to the frozen original
%      when the schedule is C00, and bit-identical to the stage-scheduled file
%      when the schedule is C11 (so the guard can be switched off without
%      changing anything else);
%   2. does the guard actually fire when a particle has waited long enough, and
%      stay silent when it has not;
%   3. does the guard come out of the same fixed evaluation budget, i.e. do the
%      guard, near-centre and far-centre phases still add up to the budget;
%   4. are the search framework parameters and the coverage diagnostics
%      unchanged and consistent.
%
% Objective evaluations made here are audit calls and are reported separately.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','sg_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

% --- 1. guard off: bit-identical to the frozen original ------------------
[ptsG00,BG00,TG00,IG00,rsG00]=runOnce('sphere',BUD1,'C00',0);
[ptsOr,BO,TO,IO,rsOr]=runOnceOriginal('sphere',BUD1);
assert(isequal(ptsG00,ptsOr),'The unguarded C00 path changed the original evaluation points.');
assert(isequal(BG00,BO)&&isequal(TG00,TO),'The unguarded C00 path changed the result or trace.');
assert(isequal(rsG00,rsOr),'The unguarded C00 path changed the global RNG state.');
assert(isequal(IG00.RoundLog(:,1:15),IO.RoundLog(:,1:15)),'The unguarded C00 path changed the round log.');
assert(IG00.Diagnostics.GuardEvaluations==0&&IG00.CogEvaluations==0);
checks{end+1}=struct('Check','Guard-off-C00-bit-identical-to-original','Passed',true);

% --- 2. guard off: bit-identical to the stage-scheduled C11 -------------
[ptsG10,BG10,TG10,IG10]=runOnce('sphere',BUD1,'C11',0);
[ptsS11,BS11,TS11,IS11]=runStage('sphere',BUD1,'C11');
assert(isequal(ptsG10,ptsS11),'Guard-off C11 changed the stage-scheduled evaluation points.');
assert(isequal(BG10,BS11)&&isequal(TG10,TS11),'Guard-off C11 changed the result or trace.');
assert(isequal(IG10.RoundLog(:,1:15),IS11.RoundLog(:,1:15)),'Guard-off C11 changed the round log.');
assert(IG10.Diagnostics.GuardEvaluations==0);
checks{end+1}=struct('Check','Guard-off-C11-bit-identical-to-stage-scheduled-C11','Passed',true);

% --- 3. odd tail budget with the guard switched on ----------------------
[ptsT,~,TT,IT]=runOnce('flat',1257,'C11',20);
assert(numel(TT)==1257&&IT.Evaluations==1257,'Guard run did not consume exactly the budget.');
assert(all(isfinite(TT))&&all(diff(TT)<=0));
checks{end+1}=struct('Check','Guarded-odd-tail-budget-exact-count','Passed',true);

% --- 4. the guard fires only when a particle has waited long enough -----
[~,~,~,ILong]=runOnce('flat',BUD1,'C11',100000);
assert(ILong.Diagnostics.GuardEvaluations==0,'The guard fired although nobody was starving.');
[~,~,~,IShort]=runOnce('flat',BUD1,'C11',20);
assert(IShort.Diagnostics.GuardEvaluations>0,'The guard never fired on a tight threshold.');
[~,~,~,IMid]=runOnce('flat',BUD1,'C11',60);
assert(IMid.Diagnostics.GuardEvaluations>0,'The guard never fired on a moderate threshold.');
assert(IShort.Diagnostics.GuardEvaluations>=IMid.Diagnostics.GuardEvaluations, ...
    'A tighter threshold fired less often than a looser one.');
checks{end+1}=struct('Check','Guard-fires-only-when-starvation-exists','Passed',true);

% --- 5. budget accounting with the guard on -----------------------------
[~,~,~,IG]=runOnce('sphere',BUD1,'C11',20);
checkDiagnostics(IG,[],BUD1,'C11',20);
[~,~,TG2,IG2]=runOnce('sphere',100000,'C00',100);
checkDiagnostics(IG2,TG2,100000,'C00',100);
checks{end+1}=struct('Check','Guarded-budget-accounting-and-diagnostics','Passed',true);

% --- 6. grouped candidate path still runs with the guard ----------------
[~,~,~,IGg]=runOnce('sphere',BUD1,'C11',20,struct('useGroup',true),4711,true);
assert(IGg.Evaluations==BUD1,'Grouped guarded path lost evaluations.');
checks{end+1}=struct('Check','Grouped-guarded-path-evaluations','Passed',true);

% --- 7. real CEC2017 objectives ----------------------------------------
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for spec={ {'C00',0},{'C11',0},{'C00',50},{'C11',50} }
        schedule=spec{1}{1};guard=spec{1}{2};
        cecID=fid;currentMode='cec';
        s=makeState(lb+rand(N,D).*(ub-lb),BUD1,schedule,262015000+fid*10000+6301,guard);
        calls=0;recPoints=zeros(BUD1,D);
        [Bc,Tc,Ic]=ASC_NoFarness_StarvationGuard(@objective,s,[],N,262026301);
        assert(calls==BUD1&&Ic.Evaluations==BUD1&&numel(Tc)==BUD1);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        if guard==0
            assert(Ic.Diagnostics.GuardEvaluations==0);
        end
        checkDiagnostics(Ic,Tc,BUD1,schedule,guard);
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions-four-guarded-conditions','Passed',true);

% --- 8. headline claim: full 100k unguarded parity ----------------------
currentMode='cec';cecID=1;BUD2=100000;
rng(262026301,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,'C00',262026301,0);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_StarvationGuard(@objective,s,[],N,262026301);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262026301);
assert(isequal(BF,BO2)&&isequal(TF,TO2),'Full-budget unguarded C00 changed the answer or trace.');
assert(isequal(pF,recPoints),'Full-budget unguarded C00 changed the evaluation points.');
assert(isequal(rngStateF,rng),'Full-budget unguarded C00 changed the global RNG state.');
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15)),'Full-budget unguarded C00 changed the round log.');
assert(calls==100000&&IF.Diagnostics.GuardEvaluations==0);
checkDiagnostics(IF,TF,BUD2,'C00',0);
checks{end+1}=struct('Check','Full100k-unguarded-C00-original-pointwise-and-RNG-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_StarvationGuard.m')), ...
    'StageSHA256',sha(fullfile(root,'ASC_NoFarness_StageLearning.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,schedule,initSeed,guard)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'learnSchedule',schedule,'guardRounds',guard);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,schedule,guard,extra,initSeed,skipReset)
        if nargin<5,extra=struct();end
        if nargin<6,initSeed=4711;end
        if nargin<7,skipReset=false;end
        currentMode=modeName;
        if ~skipReset,rng(initSeed,'twister');end
        pop0=lb+rand(N,D).*(ub-lb);
        s=makeState(pop0,budget,schedule,initSeed,guard);
        fn=fieldnames(extra);
        for k=1:numel(fn),s.(fn{k})=extra.(fn{k});end
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_StarvationGuard(@objective,s,[],N,initSeed);
        ptsOut=recPoints;rngState=rng;
    end

    function [ptsOut,B,T,I]=runStage(modeName,budget,schedule)
        currentMode=modeName;rng(4711,'twister');
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',lb+rand(N,D).*(ub-lb),'learnSchedule',schedule);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_StageLearning(@objective,s,[],N,4711);
        ptsOut=recPoints;
    end

    function [ptsOut,B,T,I,rngState]=runOnceOriginal(modeName,budget)
        currentMode=modeName;rng(4711,'twister');
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',lb+rand(N,D).*(ub-lb));
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness(@objective,s,[],N,4711);
        ptsOut=recPoints;rngState=rng;
    end

    function checkDiagnostics(I,T,budget,schedule,guard)
        dg=I.Diagnostics;
        assert(strcmp(I.LearnSchedule,schedule)&&I.GuardRounds==guard);
        assert(size(I.DiagLog,1)==I.Rounds&&size(I.DiagLog,2)==12);
        assert(dg.EvalTrace+dg.EvalSeek==budget-N,'Branch counts do not add up.');
        assert(dg.EvalNear+dg.EvalFar+dg.GuardEvaluations==budget-N, ...
            'The guard changed the total number of evaluations.');
        assert(dg.ImpPbestNear+dg.ImpPbestFar+dg.ImpPbestGuard ...
            ==dg.ImpPbestTrace+dg.ImpPbestSeek,'Personal-best improvements do not add up.');
        assert(dg.ImpGlobalNear+dg.ImpGlobalFar+dg.ImpGlobalGuard ...
            ==dg.ImpGlobalTrace+dg.ImpGlobalSeek,'Global improvements do not add up.');
        assert(dg.GapN==budget-N&&dg.GapMax>=1);
        assert(dg.JumpVictims==sum(dg.JumpVictimPending)+dg.JumpVictimRecovered);
        assert(dg.CovRounds==I.Rounds&&dg.SpreadRounds==I.Rounds);
        assert(dg.WinCovN==floor((budget-N)/1000));
        assert(dg.CoverageOver100<=dg.CoverageOver50+1e-12);
        assert(dg.PbestSpread>0&&dg.PbestSpread<1);
        if guard==0
            assert(dg.GuardEvaluations==0&&dg.ImpPbestGuard==0&&dg.ImpGlobalGuard==0, ...
                'A disabled guard still spent an evaluation.');
        end
        if ~isempty(T)
            initDrops=sum(diff(T(1:N))<0);
            assert(dg.ImpGlobalTrace+dg.ImpGlobalSeek==sum(diff(T)<0)-initDrops, ...
                'Global improvements do not match the best-so-far trace.');
        end
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
