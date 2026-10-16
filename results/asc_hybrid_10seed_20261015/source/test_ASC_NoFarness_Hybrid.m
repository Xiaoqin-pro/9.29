function test_ASC_NoFarness_Hybrid
%TEST_ASC_NOFARNESS_HYBRID  Correctness audit of the two-mechanism hybrid.
%
%   1. M0 (C00 + A0) reproduces ASC_NoFarness pointwise, including full 100k;
%   2. each mechanism is bit-identical to its own earlier screen when the other
%      is switched off (C11/C01 against the stage-scheduled file, A2 against the
%      seeking-candidate file), so neither combination step changed a formula;
%   3. both mechanisms really are active in M3, and the switches really do turn
%      them off;
%   4. budget, candidate-type accounting and the cognitive stage log stay
%      consistent.
%
% Objective evaluations made here are audit calls and are reported separately.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','hy_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

% --- 1. M0 versus the frozen original ------------------------------------
[ptsM0,BM0,TM0,IM0,rsM0]=runOnce('sphere',BUD1,'C00','A0');
[ptsOr,BO,TO,IO,rsOr]=runOnceOriginal('sphere',BUD1);
assert(isequal(ptsM0,ptsOr),'M0 changed the objective evaluation points of the original.');
assert(isequal(BM0,BO)&&isequal(TM0,TO),'M0 changed the result or the best-so-far trace.');
assert(isequal(rsM0,rsOr),'M0 changed the global RNG state of the original.');
assert(isequal(IM0.RoundLog(:,1:15),IO.RoundLog(:,1:15)),'M0 changed the original round log.');
assert(~IM0.SwitchStarted&&IM0.CogEvaluations==0);
checks{end+1}=struct('Check','M0-pointwise-original-including-RNG-and-round-log','Passed',true);

% --- 2. each mechanism still matches its own earlier screen ---------------
for cs={'C11','C01'}
    [pts,Bv,Tv,Iv]=runOnce('sphere',BUD1,cs{1},'A0');
    [ptsS,BS,TS,IS]=runStage('sphere',BUD1,cs{1});
    assert(isequal(pts,ptsS),sprintf('%s+A0 no longer matches the stage-scheduled %s.',cs{1},cs{1}));
    assert(isequal(Bv,BS)&&isequal(Tv,TS));
    assert(isequal(Iv.RoundLog(:,1:15),IS.RoundLog(:,1:15)));
end
for spec={ {'A2',3},{'A1',2} }
    [pts,Bv,Tv,Iv]=runOnce('sphere',BUD1,'C00',spec{1}{1});
    [ptsS,BS,TS,IS]=runSeek('sphere',BUD1,spec{1}{1});
    assert(isequal(pts,ptsS),sprintf('C00+%s no longer matches the seeking-candidate %s.',spec{1}{1},spec{1}{1}));
    assert(isequal(Bv,BS)&&isequal(Tv,TS));
end
checks{end+1}=struct('Check','Each-mechanism-matches-its-earlier-screen','Passed',true);

% --- 3. both mechanisms active in M3, off in M0 --------------------------
[ptsM3,BM3,TM3,IM3]=runOnce('sphere',BUD1,'C01','A2');
dg3=IM3.CandidateDiagnostics;
assert(dg3.SeekEval(3)>0,'M3 never evaluated a pbest-centred candidate.');
assert(all(dg3.SeekEval([2 4])==0),'M3 produced an unexpected candidate type.');
assert(IM3.CogEvaluations>0&&IM3.SwitchStarted,'M3 never used the cognitive direction.');
assert(IM3.SwitchFE>N,'M3 should switch after the first round.');
assert(~isequal(TM3,TM0)&&~isequal(BM3,BM0),'M3 collapsed onto the baseline.');
dg0=IM0.CandidateDiagnostics;
assert(all(dg0.SeekEval(2:4)==0)&&dg0.SeekEval(1)>0);
checks{end+1}=struct('Check','Both-mechanisms-active-in-M3-and-off-in-M0','Passed',true);

% --- 4. a switched-off mechanism collapses onto the other one ------------
[ptsA,~,TA,~]=runOnce('sphere',BUD1,'C01','A0');
[ptsB,~,TB,~]=runOnce('sphere',BUD1,'C01','A2',struct('seekRefineCount',0));
assert(isequal(ptsA,ptsB)&&isequal(TA,TB),'seekRefineCount=0 did not collapse A2 onto A0.');
checks{end+1}=struct('Check','Zero-refine-count-collapses-A2-onto-A0','Passed',true);

% --- 5. budget, accounting and odd tail ----------------------------------
for spec={ {'C00','A0'},{'C01','A0'},{'C00','A2'},{'C01','A2'} }
    [~,~,Tv,Iv]=runOnce('sphere',BUD1,spec{1}{1},spec{1}{2});
    checkBudget(Iv,Tv,BUD1,spec{1}{1},spec{1}{2});
end
[~,~,TT,IT]=runOnce('flat',1257,'C01','A2');
assert(numel(TT)==1257&&IT.Evaluations==1257,'Odd tail budget was not consumed exactly.');
checkBudget(IT,TT,1257,'C01','A2');
checks{end+1}=struct('Check','Budget-accounting-and-odd-tail-budget','Passed',true);

% --- 6. grouped candidate path -------------------------------------------
for spec={ {'C00','A0'},{'C01','A2'} }
    [~,~,~,Ig]=runOnce('sphere',BUD1,spec{1}{1},spec{1}{2},struct('useGroup',true),4711,true);
    assert(Ig.Evaluations==BUD1,'Grouped path lost evaluations.');
end
checks{end+1}=struct('Check','Grouped-path-evaluations','Passed',true);

% --- 7. real CEC2017 objectives ------------------------------------------
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for spec={ {'C00','A0'},{'C01','A0'},{'C00','A2'},{'C01','A2'} }
        cecID=fid;currentMode='cec';
        s=makeState(lb+rand(N,D).*(ub-lb),BUD1,spec{1}{1},spec{1}{2},262015000+fid*10000+6501);
        calls=0;recPoints=zeros(BUD1,D);
        [Bc,Tc,Ic]=ASC_NoFarness_Hybrid(@objective,s,[],N,262026501);
        assert(calls==BUD1&&Ic.Evaluations==BUD1&&numel(Tc)==BUD1);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        checkBudget(Ic,Tc,BUD1,spec{1}{1},spec{1}{2});
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions-four-hybrid-conditions','Passed',true);

% --- 8. full 100k M0 parity ----------------------------------------------
currentMode='cec';cecID=1;BUD2=100000;
rng(262026501,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,'C00','A0',262026501);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_Hybrid(@objective,s,[],N,262026501);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262026501);
assert(isequal(BF,BO2)&&isequal(TF,TO2),'Full-budget M0 changed the final answer or trace.');
assert(isequal(pF,recPoints),'Full-budget M0 changed the objective evaluation points.');
assert(isequal(rngStateF,rng),'Full-budget M0 changed the global RNG state.');
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15)),'Full-budget M0 changed the round log.');
assert(calls==100000);
checkBudget(IF,TF,BUD2,'C00','A0');
checks{end+1}=struct('Check','Full100k-M0-original-pointwise-and-RNG-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_Hybrid.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,cogSchedule,seekVariant,initSeed)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'cogSchedule',cogSchedule, ...
            'seekVariant',seekVariant,'seekRefineCount',2);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,cogSchedule,seekVariant,extra,initSeed,skipReset)
        if nargin<5,extra=struct();end
        if nargin<6,initSeed=4711;end
        if nargin<7,skipReset=false;end
        currentMode=modeName;
        if ~skipReset,rng(initSeed,'twister');end
        pop0=lb+rand(N,D).*(ub-lb);
        s=makeState(pop0,budget,cogSchedule,seekVariant,initSeed);
        fn=fieldnames(extra);
        for k=1:numel(fn),s.(fn{k})=extra.(fn{k});end
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_Hybrid(@objective,s,[],N,initSeed);
        ptsOut=recPoints;rngState=rng;
    end

    function [ptsOut,B,T,I]=runStage(modeName,budget,cogSchedule)
        currentMode=modeName;rng(4711,'twister');
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',lb+rand(N,D).*(ub-lb),'learnSchedule',cogSchedule);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_StageLearning(@objective,s,[],N,4711);
        ptsOut=recPoints;
    end

    function [ptsOut,B,T,I]=runSeek(modeName,budget,seekVariant)
        currentMode=modeName;rng(4711,'twister');
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',lb+rand(N,D).*(ub-lb),'seekVariant',seekVariant, ...
            'seekRefineCount',2);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_SeekingCandidates(@objective,s,[],N,4711);
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

    function checkBudget(I,T,budget,cogSchedule,seekVariant)
        dg=I.CandidateDiagnostics;
        P=I.Parameters;
        assert(strcmp(I.CogSchedule,cogSchedule)&&strcmp(I.SeekVariant,seekVariant));
        assert(sum(dg.SeekEval)+dg.TraceEval+dg.OtherEval==budget-N, ...
            'Candidate-type counts do not add up to the budget.');
        assert(dg.TraceEval>0);
        assert(all(dg.SeekEval==0|dg.SeekDistSum>0));
        assert(numel(I.StageLog)==I.Rounds);
        cognitiveRounds=I.StageLog==1;
        assert(abs(I.CogEvaluations-sum(I.RoundLog(cognitiveRounds,3)))<1e-9, ...
            'The cognitive evaluation count does not match the stage log.');
        if strcmp(cogSchedule,'C00')
            assert(~I.SwitchStarted&&I.CogEvaluations==0);
        elseif strcmp(cogSchedule,'C11')
            assert(I.SwitchStarted&&I.SwitchFE==N&&all(cognitiveRounds));
        else
            assert(I.SwitchStarted&&I.SwitchFE>N);
            k=(I.SwitchFE-N)/10;
            assert(~any(cognitiveRounds(1:k))&&all(cognitiveRounds(k+1:end)));
        end
        if strcmp(seekVariant,'A0')
            assert(all(dg.SeekEval(2:4)==0));
        else
            assert(dg.SeekEval(3)>0&&all(dg.SeekEval([2 4])==0));
        end
        assert(P.seekEliteGain==0&&P.traceBoostGain==0);
        assert(P.useJump&&~P.useGroup&&~P.useOBL&&~P.useGaussBest);
        assert(P.evaluationsPerRound==10&&P.perOwnerCap==2&&P.seekCandidateCount==4);
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
