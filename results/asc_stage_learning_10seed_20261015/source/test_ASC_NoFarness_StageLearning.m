function test_ASC_NoFarness_StageLearning
%TEST_ASC_NOFARNESS_STAGELEARNING  Correctness audit of the stage-scheduled
%   verified-exemplar learning candidates (C00/C11/C01/C10).
%
% The audit answers four questions before any performance run is trusted:
%   1. does C00 reproduce ASC_NoFarness pointwise, including the RNG stream,
%      the objective evaluation points and the original round log;
%   2. is the social phase of C01 bit-identical to C00 up to the switch point,
%      and the cognitive phase of C10 bit-identical to C11 (so the four
%      schedules differ only by the learning rule, not by random-stream drift);
%   3. does the Tracing update implement the formula it claims, replayed from
%      an explicit global stream and an explicit cognitive stream;
%   4. do all four schedules stay inside the same budget and bounds, and are the
%      evaluation-branch and evaluation-coverage diagnostics consistent.
%
% Objective evaluations made here are audit calls and are reported separately.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','sl_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

% --- 1. constructing the cognitive stream must not touch the global stream --
rng(4711,'twister');before=rng;
st=RandStream('mt19937ar','Seed',12345);assert(isequal(before,rng));
rand(st,1,4);assert(isequal(before,rng));
checks{end+1}=struct('Check','Cognitive-stream-construction-and-use-leave-global-RNG-untouched','Passed',true);

% --- 2. C00 versus the frozen original, round-aligned budget --------------
[ptsC00,BC00,TC00,IC00,rsC00]=runOnce('sphere',BUD1,'C00');
[ptsOr,BO,TO,IO,rsOr]=runOnceOriginal('sphere',BUD1);
assert(isequal(ptsC00,ptsOr),'C00 changed the objective evaluation points of the original.');
assert(isequal(BC00,BO)&&isequal(TC00,TO),'C00 changed the best solution or the best-so-far trace.');
assert(isequal(rsC00,rsOr),'C00 changed the global RNG state of the original.');
assert(isequal(IC00.RoundLog(:,1:15),IO.RoundLog(:,1:15)),'C00 changed the original round log.');
assert(~IC00.SwitchStarted&&isnan(IC00.SwitchFE)&&IC00.CogEvaluations==0);
checks{end+1}=struct('Check','C00-pointwise-original-including-RNG-and-round-log','Passed',true);

% --- 3. C00 parity with an odd tail budget --------------------------------
[ptsT,~,TT,IT]=runOnce('flat',1257,'C00');
[ptsO,~,~]=runOnceOriginal('flat',1257);
assert(isequal(ptsT,ptsO),'C00 changed the evaluation points on a partial final round.');
assert(numel(TT)==1257&&IT.Evaluations==1257,'Odd tail budget was not consumed exactly.');
checks{end+1}=struct('Check','C00-odd-tail-budget-parity-and-exact-count','Passed',true);

% --- 4. C00 must ignore the schedule parameters ---------------------------
[ptsP,BP,TP]=runOnce('sphere',BUD1,'C00',struct('switchProgress',0.30,'cogSeedOffset',99));
assert(isequal(ptsP,ptsC00)&&isequal(BP,BC00)&&isequal(TP,TC00), ...
    'C00 changed behaviour when the schedule parameters were set.');
checks{end+1}=struct('Check','C00-independent-of-switchProgress-and-cogSeedOffset','Passed',true);

% --- 5. switch-point identity --------------------------------------------
% With budget 1250 and N=50 the switch sits at fe = 650; C01 must equal C00
% below that point and C10 must equal C11 below it, evaluation point by
% evaluation point.
switchFE=N+0.5*(BUD1-N);
[ptsC01,BC01,TC01,IC01]=runOnce('sphere',BUD1,'C01');
[ptsC11,BC11,TC11,IC11]=runOnce('sphere',BUD1,'C11');
[ptsC10,BC10,TC10,IC10]=runOnce('sphere',BUD1,'C10');
k=round(switchFE);
assert(isequal(ptsC01(1:k,:),ptsC00(1:k,:)), ...
    'C01 diverged from C00 before the switch point.');
assert(isequal(TC01(1:k),TC00(1:k)),'C01 best-so-far diverged from C00 before the switch.');
assert(isequal(ptsC10(1:k,:),ptsC11(1:k,:)), ...
    'C10 diverged from C11 before the switch point.');
assert(isequal(TC10(1:k),TC11(1:k)),'C10 best-so-far diverged from C11 before the switch.');
assert(~isequal(ptsC01(k+1:end,:),ptsC00(k+1:end,:)),'C01 never diverged from C00.');
assert(~isequal(ptsC10(k+1:end,:),ptsC11(k+1:end,:)),'C10 never diverged from C11.');
checks{end+1}=struct('Check','C01-equals-C00-and-C10-equals-C11-up-to-the-switch','Passed',true);

% --- 6. switch bookkeeping ------------------------------------------------
assert(IC11.SwitchStarted&&IC11.SwitchFE==N,'C11 should be cognitive from the first round.');
assert(IC10.SwitchStarted&&IC10.SwitchFE==N,'C10 should be cognitive from the first round.');
assert(IC01.SwitchStarted&&IC01.SwitchFE==switchFE, ...
    'C01 did not switch on the expected round boundary.');
assert(sum(IC00.StageLog)==0,'C00 ran a cognitive round.');
assert(all(IC11.StageLog==1),'C11 skipped a cognitive round.');
assert(all(IC01.StageLog(1:(IC01.SwitchFE-N)/10)==0),'C01 used cognition early.');
assert(all(IC01.StageLog((IC01.SwitchFE-N)/10+1:end)==1), ...
    'C01 did not stay cognitive after switching.');
assert(all(IC10.StageLog(1:(switchFE-N)/10)==1),'C10 was not cognitive at the start.');
assert(all(IC10.StageLog((switchFE-N)/10+1:end)==0),'C10 did not return to social learning.');
checks{end+1}=struct('Check','Stage-switch-bookkeeping','Passed',true);

% --- 7. Tracing update replayed from explicit streams --------------------
exportFixture();
replayTracing(false);
replayTracing(true);
checks{end+1}=struct('Check','Independent-Tracing-formula-replay-social-and-cognitive','Passed',true);

% --- 8. all four schedules: budget, bounds, trace, diagnostics -----------
for schedule={'C00','C11','C01','C10'}
    [pts,Bv,Tv,Iv]=runOnce('sphere',BUD1,schedule{1});
    assert(numel(Tv)==BUD1&&Iv.Evaluations==BUD1&&all(isfinite(Tv))&&all(diff(Tv)<=0));
    assert(all(isfinite(Bv.Vector))&&all(Bv.Vector>=lb&Bv.Vector<=ub));
    assert(all(all(pts>=lb))&&all(all(pts<=ub)),'Candidate left the box.');
    checkDiagnostics(Iv,Tv,BUD1,schedule{1});
end
checks{end+1}=struct('Check','All-four-schedules-budget-bounds-trace-and-diagnostics','Passed',true);

% --- 9. grouped candidate path still runs in every schedule -------------
for schedule={'C00','C11','C01','C10'}
    [~,~,~,Ig]=runOnce('sphere',BUD1,schedule{1},struct('useGroup',true),4711,true);
    assert(Ig.Evaluations==BUD1,'Grouped path lost evaluations.');
end
checks{end+1}=struct('Check','Grouped-path-evaluations-all-schedules','Passed',true);

% --- 10. real CEC2017 objectives, every schedule, short budget ----------
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for schedule={'C00','C11','C01','C10'}
        cecID=fid;currentMode='cec';
        s=makeState(lb+rand(N,D).*(ub-lb),BUD1,schedule{1},262015000+fid*10000+6201);
        calls=0;recPoints=zeros(BUD1,D);
        [Bc,Tc,Ic]=ASC_NoFarness_StageLearning(@objective,s,[],N,262026201);
        assert(calls==BUD1&&Ic.Evaluations==BUD1&&numel(Tc)==BUD1);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        checkDiagnostics(Ic,Tc,BUD1,schedule{1});
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions-all-four-schedules','Passed',true);

% --- 11. headline claim: full 100k C00 parity ---------------------------
currentMode='cec';cecID=1;BUD2=100000;
rng(262026201,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,'C00',262026201);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_StageLearning(@objective,s,[],N,262026201);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262026201);
assert(isequal(BF,BO2)&&isequal(TF,TO2),'Full-budget C00 changed the final answer or trace.');
assert(isequal(pF,recPoints),'Full-budget C00 changed the objective evaluation points.');
assert(isequal(rngStateF,rng),'Full-budget C00 changed the global RNG state.');
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15)),'Full-budget C00 changed the round log.');
assert(calls==100000,'Full-budget original did not consume exactly 100k evaluations.');
checkDiagnostics(IF,TF,BUD2,'C00');
checks{end+1}=struct('Check','Full100k-C00-original-pointwise-and-RNG-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_StageLearning.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,schedule,initSeed)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'learnSchedule',schedule);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,schedule,extra,initSeed,skipReset)
        if nargin<4,extra=struct();end
        if nargin<5,initSeed=4711;end
        if nargin<6,skipReset=false;end
        currentMode=modeName;
        if ~skipReset,rng(initSeed,'twister');end
        pop0=lb+rand(N,D).*(ub-lb);
        s=makeState(pop0,budget,schedule,initSeed);
        fn=fieldnames(extra);
        for k=1:numel(fn),s.(fn{k})=extra.(fn{k});end
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_StageLearning(@objective,s,[],N,initSeed);
        ptsOut=recPoints;rngState=rng;
    end

    function [ptsOut,B,T,I,rngState]=runOnceOriginal(modeName,budget)
        currentMode=modeName;
        rng(4711,'twister');
        s=makeState(lb+rand(N,D).*(ub-lb),budget,'C00',4711);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness(@objective,s,[],N,4711);
        ptsOut=recPoints;rngState=rng;
    end

    function checkDiagnostics(I,T,budget,schedule)
        dg=I.Diagnostics;
        assert(strcmp(I.LearnSchedule,schedule)&&strcmp(I.Variant,['ASC-NoFarness-' schedule]));
        assert(size(I.DiagLog,1)==I.Rounds&&size(I.DiagLog,2)==12);
        assert(numel(I.StageLog)==I.Rounds);
        assert(dg.EvalTrace+dg.EvalSeek==budget-N,'Branch counts do not add up.');
        assert(dg.EvalNear+dg.EvalFar==budget-N,'Geometry-phase counts do not add up.');
        assert(dg.ImpPbestNear+dg.ImpPbestFar==dg.ImpPbestTrace+dg.ImpPbestSeek);
        initDrops=sum(diff(T(1:N))<0);
        assert(dg.ImpGlobalTrace+dg.ImpGlobalSeek==sum(diff(T)<0)-initDrops, ...
            'Global improvements do not match the best-so-far trace.');
        assert(dg.ImpGlobalNear+dg.ImpGlobalFar==dg.ImpGlobalTrace+dg.ImpGlobalSeek);
        assert(dg.GapN==budget-N&&dg.GapMax>=1);
        assert(dg.JumpVictims==sum(dg.JumpVictimPending)+dg.JumpVictimRecovered, ...
            'Jump victim accounting is inconsistent.');
        assert(abs(sum(I.DiagLog(:,1))-dg.EvalTrace)<1e-9);
        % stage bookkeeping
        cognitiveRounds=I.StageLog==1;
        assert(abs(I.CogEvaluations-sum(I.RoundLog(cognitiveRounds,3)))<1e-9, ...
            'Cognitive evaluation count does not match the stage log.');
        if strcmp(schedule,'C00')
            assert(~I.SwitchStarted&&I.CogEvaluations==0);
        elseif strcmp(schedule,'C11')||strcmp(schedule,'C10')
            assert(I.SwitchStarted&&I.SwitchFE==N);
        else
            assert(I.SwitchStarted&&I.SwitchFE>N);
        end
        % coverage diagnostics
        assert(dg.CovRounds==I.Rounds&&dg.SpreadRounds==I.Rounds);
        assert(dg.WinCovN==floor((budget-N)/1000),'Unexpected number of coverage windows.');
        assert(dg.CoverageOver50>=0&&dg.CoverageOver50<=1);
        assert(dg.CoverageOver100>=0&&dg.CoverageOver100<=(1+1e-12));
        assert(dg.CoverageOver100<=dg.CoverageOver50+1e-12);
        assert(dg.WindowCoverage>0&&dg.WindowCoverage<=1);
        assert(dg.PbestSpread>0&&dg.PbestSpread<1);
    end

    function exportFixture
        text=fileread(fullfile(root,'ASC_NoFarness_StageLearning.m'));
        a=strfind(text,'function trialVelocity=tracingVelocity');
        b=strfind(text,'function v=fieldOr');
        assert(~isempty(a)&&~isempty(b)&&a<b,'Could not locate the Tracing helper.');
        helper=strrep(text(a:b-1),'tracingVelocity','sl_tracing_fixture');
        f=fopen(fullfile(out,'sl_tracing_fixture.m'),'w');
        fprintf(f,'%s',helper);fclose(f);addpath(out);
    end

    function replayTracing(useCog)
        Dt=20;
        x=(1:Dt)*1.5;
        pb=x+3;
        vel=0.4*ones(1,Dt);
        elite=x+7;
        inertia=0.7;seed=4711;cogSeed=999;
        p=struct('cognitiveShare',0.50);
        c1=2*p.cognitiveShare;c2=2*(1-p.cognitiveShare);
        cs=RandStream('mt19937ar','Seed',cogSeed);
        rng(seed,'twister');
        got=sl_tracing_fixture(p,inertia,vel,x,pb,elite,Dt,useCog,cs);
        spentGlobal=rng;spentCog=cs.State;
        % replay the global stream and the cognitive stream independently
        rng(seed,'twister');
        cs2=RandStream('mt19937ar','Seed',cogSeed);
        if useCog
            rSocial=rand(1,Dt);
            rCog=rand(cs2,1,Dt);
            expected=inertia*vel+c1*rCog.*(pb-x)+c2*rSocial.*(elite-x);
        else
            expected=inertia*vel+2*rand(1,Dt).*(elite-x);
        end
        assert(isequal(got,expected),'Tracing replay mismatch.');
        assert(isequal(spentGlobal,rng),'The social draw pattern changed.');
        assert(isequal(spentCog,cs2.State),'The cognitive stream drawing pattern changed.');
        if useCog
            % the cognitive branch must consume exactly one global draw per
            % particle and round, like the social-only branch
            rng(seed,'twister');rand(1,Dt);refGlobal=rng;
            assert(isequal(spentGlobal,refGlobal), ...
                'The cognitive branch consumed a different number of global draws.');
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
