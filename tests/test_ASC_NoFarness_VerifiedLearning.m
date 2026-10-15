function test_ASC_NoFarness_VerifiedLearning
%TEST_ASC_NOFARNESS_VERIFIEDLEARNING  Correctness audit of the verified-exemplar
%   learning candidates (B0/B1/B2) built on the frozen ASC-NoFarness core.
%
% The audit answers three questions before any performance run is trusted:
%   1. does B0 reproduce ASC_NoFarness pointwise, including the RNG stream,
%      the objective evaluation points and the original round log;
%   2. does the Tracing update implement the formula it claims to implement,
%      replayed independently from an explicit random stream;
%   3. do B1/B2 stay inside the same budget and bounds, and are the new
%      evaluation-branch diagnostics internally consistent.
%
% Objective evaluations made here are audit calls.  They are not part of any
% performance budget and are reported separately.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','vl_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);

% --- 1. B0 versus the frozen original, at a round-aligned budget ----------
[ptsB0,BB0,TB0,IB0,rsB0]=runOnce('sphere',1250,'B0');
[ptsOr,BO,TO,IO,rsOr]=runOnceOriginal('sphere',1250);
assert(isequal(ptsB0,ptsOr),'B0 changed the objective evaluation points of the original.');
assert(isequal(BB0,BO)&&isequal(TB0,TO),'B0 changed the best solution or the best-so-far trace.');
assert(isequal(rsB0,rsOr),'B0 changed the global RNG state of the original.');
assert(isequal(IB0.RoundLog(:,1:15),IO.RoundLog(:,1:15)),'B0 changed the original round log.');
assert(isequal(IB0.RoundLogColumns,IO.RoundLogColumns),'B0 changed the round-log schema.');
checks{end+1}=struct('Check','B0-pointwise-original-including-RNG-and-round-log','Passed',true);

% --- 2. B0 parity with an odd tail budget --------------------------------
[ptsT,BT,TT,IT]=runOnce('flat',1257,'B0');
[ptsO,~,~]=runOnceOriginal('flat',1257);
assert(isequal(ptsT,ptsO),'B0 changed the evaluation points on a partial final round.');
assert(numel(TT)==1257&&IT.Evaluations==1257,'Odd tail budget was not consumed exactly.');
checks{end+1}=struct('Check','B0-odd-tail-budget-parity-and-exact-count','Passed',true);

% --- 3. B0 must ignore the learning parameters entirely ------------------
[ptsP,BP,TP]=runOnce('sphere',1250,'B0',struct('cognitiveShare',0.95,'exploreFraction',0.90));
assert(isequal(ptsP,ptsB0)&&isequal(BP,BB0)&&isequal(TP,TB0), ...
    'B0 changed behaviour when the learning parameters were set.');
checks{end+1}=struct('Check','B0-independent-of-cognitiveShare-and-exploreFraction','Passed',true);

% --- 4. Tracing update replayed from an explicit random stream -----------
exportFixture();
for variant={'B0','B1','B2'}
    replayTracing(variant{1});
end
checks{end+1}=struct('Check','Independent-Tracing-formula-replay-B0-B1-B2','Passed',true);

% --- 5. B1/B2 budgets, bounds, traces and diagnostics --------------------
for variant={'B1','B2'}
    [ptsP,Bv,Tv,Iv]=runOnce('sphere',1250,variant{1});
    assert(numel(Tv)==1250&&Iv.Evaluations==1250&&all(isfinite(Tv))&&all(diff(Tv)<=0));
    assert(all(isfinite(Bv.Vector))&&all(Bv.Vector>=lb&Bv.Vector<=ub));
    assert(all(all(ptsP>=lb))&&all(all(ptsP<=ub)),'Candidate left the box.');
    checkDiagnostics(Iv,Tv,1250,variant{1});
end
checks{end+1}=struct('Check','B1-B2-budget-bounds-monotone-trace-and-diagnostics','Passed',true);

% --- 6. the new modes really do change the search path -------------------
[~,B1v,T1v]=runOnce('sphere',1250,'B1');
[~,B2v,T2v]=runOnce('sphere',1250,'B2');
assert(~isequal(T1v,TB0),'B1 did not change the search path at all.');
assert(~isequal(T2v,T1v),'B2 did not change the search path at all.');
assert(~isequal(B2v.Vector,B1v.Vector)||B2v.Cost~=B1v.Cost,'B2 collapsed onto B1.');
checks{end+1}=struct('Check','B1-and-B2-change-the-search-path','Passed',true);

% --- 7. the grouped candidate path still runs in every mode -------------
for variant={'B0','B1','B2'}
    [~,~,~,Ig]=runOnce('sphere',1250,variant{1},struct('useGroup',true),4711,true);
    assert(Ig.Evaluations==1250,'Grouped path lost evaluations.');
end
checks{end+1}=struct('Check','Grouped-path-evaluations-all-modes','Passed',true);

% --- 8. real CEC2017 objectives, every mode, short budget ----------------
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27]
    for variant={'B0','B1','B2'}
        cecID=fid;currentMode='cec';
        s=makeState(lb+rand(N,D).*(ub-lb),1250,variant{1},262015000+fid*10000+6101);
        calls=0;recPoints=zeros(1250,D);
        [Bc,Tc,Ic]=ASC_NoFarness_VerifiedLearning(@objective,s,[],N,262026101);
        assert(calls==1250&&Ic.Evaluations==1250&&numel(Tc)==1250);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        checkDiagnostics(Ic,Tc,1250,variant{1});
    end
end
checks{end+1}=struct('Check','Eight-CEC-functions-all-three-modes','Passed',true);

% --- 9. the headline claim: full 100k B0 parity --------------------------
currentMode='cec';cecID=1;
rng(262026101,'twister');s=makeState(lb+rand(N,D).*(ub-lb),100000,'B0',262026101);
calls=0;recPoints=zeros(100000,D);
[BF,TF,IF]=ASC_NoFarness_VerifiedLearning(@objective,s,[],N,262026101);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(100000,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262026101);
assert(isequal(BF,BO2)&&isequal(TF,TO2),'Full-budget B0 changed the final answer or trace.');
assert(isequal(pF,recPoints),'Full-budget B0 changed the objective evaluation points.');
assert(isequal(rngStateF,rng),'Full-budget B0 changed the global RNG state.');
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15)),'Full-budget B0 changed the round log.');
assert(calls==100000,'Full-budget original did not consume exactly 100k evaluations.');
checkDiagnostics(IF,TF,100000,'B0');
checks{end+1}=struct('Check','Full100k-B0-original-pointwise-and-RNG-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_VerifiedLearning.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,variant,initSeed)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'learnMode',variant);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,variant,extra,initSeed,skipReset)
        if nargin<4,extra=struct();end
        if nargin<5,initSeed=4711;end
        if nargin<6,skipReset=false;end
        currentMode=modeName;
        if ~skipReset,rng(initSeed,'twister');end
        pop0=lb+rand(N,D).*(ub-lb);
        s=makeState(pop0,budget,variant,initSeed);
        fn=fieldnames(extra);
        for k=1:numel(fn),s.(fn{k})=extra.(fn{k});end
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_VerifiedLearning(@objective,s,[],N,initSeed);
        ptsOut=recPoints;rngState=rng;
    end

    function [ptsOut,B,T,I,rngState]=runOnceOriginal(modeName,budget)
        currentMode=modeName;
        rng(4711,'twister');
        s=makeState(lb+rand(N,D).*(ub-lb),budget,'B0',4711);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness(@objective,s,[],N,4711);
        ptsOut=recPoints;rngState=rng;
    end

    function checkDiagnostics(I,T,budget,variant)
        dg=I.Diagnostics;
        assert(size(I.DiagLog,1)==I.Rounds&&size(I.DiagLog,2)==12);
        assert(dg.EvalTrace+dg.EvalSeek==budget-N,'Branch counts do not add up.');
        assert(dg.EvalNear+dg.EvalFar==budget-N,'Geometry-phase counts do not add up.');
        assert(dg.ImpPbestTrace+dg.ImpPbestSeek<=budget-N);
        assert(dg.ImpPbestNear+dg.ImpPbestFar==dg.ImpPbestTrace+dg.ImpPbestSeek);
        % The best-so-far trace also drops during the initialisation sweep,
        % which happens before the diagnostics start counting.
        initDrops=sum(diff(T(1:N))<0);
        assert(dg.ImpGlobalTrace+dg.ImpGlobalSeek==sum(diff(T)<0)-initDrops, ...
            'Global improvements do not match the best-so-far trace.');
        assert(dg.ImpGlobalNear+dg.ImpGlobalFar==dg.ImpGlobalTrace+dg.ImpGlobalSeek);
        assert(abs(sum(I.DiagLog(:,1))-dg.EvalTrace)<1e-9);
        assert(abs(sum(I.DiagLog(:,2))-dg.EvalSeek)<1e-9);
        assert(abs(sum(I.DiagLog(:,4))-dg.EvalFar)<1e-9);
        assert(abs(sum(I.DiagLog(:,9))-dg.ImpGlobalTrace)<1e-9);
        assert(dg.GapN==budget-N,'Per-particle evaluation gap was not recorded.');
        assert(dg.GapMax>=1&&dg.GapSum>=dg.GapN);
        assert(dg.JumpVictims==sum(dg.JumpVictimPending)+dg.JumpVictimRecovered, ...
            'Jump victim accounting is inconsistent.');
        assert(strcmp(I.LearnMode,variant)&&strcmp(I.Variant,['ASC-NoFarness-' variant]));
    end

    function exportFixture
        text=fileread(fullfile(root,'ASC_NoFarness_VerifiedLearning.m'));
        a=strfind(text,'function trialVelocity=tracingVelocity');
        b=strfind(text,'function v=fieldOr');
        assert(~isempty(a)&&~isempty(b)&&a<b,'Could not locate the Tracing helper.');
        helper=strrep(text(a:b-1),'tracingVelocity','vl_tracing_fixture');
        f=fopen(fullfile(out,'vl_tracing_fixture.m'),'w');
        fprintf(f,'%s',helper);fclose(f);addpath(out);
    end

    function replayTracing(variant)
        Dt=20;
        x=(1:Dt)*1.5;
        pb=[x+3;x+4;x+5;x+6;x+7;x+8];
        vel=[0.1*ones(1,Dt);0.2*ones(1,Dt);0.3*ones(1,Dt); ...
             0.4*ones(1,Dt);0.5*ones(1,Dt);0.6*ones(1,Dt)];
        eliteIdx=[1 3 5];
        eliteVector=pb(2,:);
        inertia=0.7;seed=4711;
        p=struct('learnMode',variant,'cognitiveShare',0.40,'exploreFraction',0.30);
        c1=2*p.cognitiveShare;c2=2*(1-p.cognitiveShare);
        switch variant
            case 'B0'
                v_i=vel(1,:);pb_i=pb(1,:);exploreFlag=false;
            case 'B1'
                v_i=vel(2,:);pb_i=pb(2,:);exploreFlag=false;
            case 'B2'
                v_i=vel(3,:);pb_i=pb(3,:);exploreFlag=true;
        end
        rng(seed,'twister');
        got=vl_tracing_fixture(p,inertia,v_i,x,pb_i,eliteVector,eliteIdx,exploreFlag,pb,Dt);
        spent=rng;
        rng(seed,'twister');
        if strcmp(variant,'B0')
            expected=inertia*v_i+2*rand(1,Dt).*(eliteVector-x);
        else
            if strcmp(variant,'B2')
                rows=eliteIdx(randi(numel(eliteIdx),1,Dt));
                ex=reshape(pb(sub2ind(size(pb),rows(:),(1:Dt)')),1,Dt);
            else
                ex=eliteVector;
            end
            expected=inertia*v_i+c1*rand(1,Dt).*(pb_i-x)+c2*rand(1,Dt).*(ex-x);
        end
        assert(isequal(got,expected),sprintf('%s Tracing replay mismatch.',variant));
        assert(isequal(spent,rng),sprintf('%s consumed an unexpected number of random values.',variant));
        if ~strcmp(variant,'B0')
            rng(seed,'twister');
            base=inertia*v_i+2*rand(1,Dt).*(eliteVector-x);
            assert(~isequal(got,base),sprintf('%s reproduced the original update.',variant));
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
