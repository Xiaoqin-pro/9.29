function test_ASC_NoFarness_DimWise
%TEST_ASC_NOFARNESS_DIMWISE  Correctness audit of the dimension-wise exemplar
%   variant on top of the hybrid search core.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','dw_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

[ptsM0,BM0,TM0,IM0,rsM0]=runOnce('sphere',BUD1,'C00','A0');
[ptsOr,BO,TO,IO,rsOr]=runOnceOriginal('sphere',BUD1);
assert(isequal(ptsM0,ptsOr)&&isequal(BM0,BO)&&isequal(TM0,TO));
assert(isequal(rsM0,rsOr)&&isequal(IM0.RoundLog(:,1:15),IO.RoundLog(:,1:15)));
checks{end+1}=struct('Check','M0-pointwise-original-including-RNG-and-round-log','Passed',true);

for spec={ {'C00','A2'},{'C01','A3'},{'C00','A0'} }
    [ptsA,BA,TA,IA]=runOnce('sphere',BUD1,spec{1}{1},spec{1}{2});
    [ptsH,BH,TH,IH]=runHybrid('sphere',BUD1,spec{1}{1},spec{1}{2});
    assert(isequal(ptsA,ptsH)&&isequal(BA,BH)&&isequal(TA,TH), ...
        sprintf('%s+%s no longer matches the hybrid implementation.',spec{1}{1},spec{1}{2}));
end
checks{end+1}=struct('Check','Existing-variants-still-match-the-hybrid','Passed',true);

[~,~,TD,ID]=runOnce('sphere',BUD1,'C01','A4');
dg=ID.CandidateDiagnostics;
assert(dg.SeekEval(5)>0,'The dimension-wise candidate never got evaluated.');
assert(all(dg.SeekEval([2 3 4])==0),'An unexpected candidate type was evaluated.');
assert(dg.SeekEval(1)>0,'The original candidates disappeared.');
assert(ID.CogEvaluations>0,'The cognitive direction was never used.');
checkBudget(ID,TD,BUD1,'C01','A4');
checks{end+1}=struct('Check','Dimension-wise-variant-is-active','Passed',true);

for spec={ {'C00','A0'},{'C01','A4'} }
    [~,~,Tv,Iv]=runOnce('sphere',BUD1,spec{1}{1},spec{1}{2});
    checkBudget(Iv,Tv,BUD1,spec{1}{1},spec{1}{2});
end
checks{end+1}=struct('Check','Budget-and-diagnostics-consistent','Passed',true);

old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for spec={ {'C00','A0'},{'C01','A4'} }
        cecID=fid;currentMode='cec';
        s=makeState(lb+rand(N,D).*(ub-lb),BUD1,spec{1}{1},spec{1}{2},262015000+fid*10000+7001);
        calls=0;recPoints=zeros(BUD1,D);
        [Bc,Tc,Ic]=ASC_NoFarness_DimWise(@objective,s,[],N,262027001);
        assert(calls==BUD1&&Ic.Evaluations==BUD1);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        checkBudget(Ic,Tc,BUD1,spec{1}{1},spec{1}{2});
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions','Passed',true);

currentMode='cec';cecID=1;BUD2=100000;
rng(262027001,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,'C00','A0',262027001);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_DimWise(@objective,s,[],N,262027001);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262027001);
assert(isequal(BF,BO2)&&isequal(TF,TO2)&&isequal(pF,recPoints)&&isequal(rngStateF,rng));
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15))&&calls==100000);
checks{end+1}=struct('Check','Full100k-M0-original-pointwise-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_DimWise.m')), ...
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

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,cogSchedule,seekVariant)
        currentMode=modeName;rng(4711,'twister');
        pop0=lb+rand(N,D).*(ub-lb);
        s=makeState(pop0,budget,cogSchedule,seekVariant,4711);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_DimWise(@objective,s,[],N,4711);
        ptsOut=recPoints;rngState=rng;
    end

    function [ptsOut,B,T,I]=runHybrid(modeName,budget,cogSchedule,seekVariant)
        currentMode=modeName;rng(4711,'twister');
        s=makeState(lb+rand(N,D).*(ub-lb),budget,cogSchedule,seekVariant,4711);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_Hybrid(@objective,s,[],N,4711);
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
        dg=I.CandidateDiagnostics;P=I.Parameters;
        assert(strcmp(I.CogSchedule,cogSchedule)&&strcmp(I.SeekVariant,seekVariant));
        assert(sum(dg.SeekEval)+dg.TraceEval+dg.OtherEval==budget-N);
        assert(dg.TraceEval>0&&all(dg.SeekEval>=0));
        assert(all(dg.SeekEval==0|dg.SeekDistSum>0));
        assert(numel(I.StageLog)==I.Rounds);
        cognitived=I.StageLog==1;
        assert(abs(I.CogEvaluations-sum(I.RoundLog(cognitived,3)))<1e-9);
        if strcmp(cogSchedule,'C00')
            assert(~I.SwitchStarted&&I.CogEvaluations==0);
        else
            assert(I.SwitchStarted&&I.SwitchFE>N&&I.CogEvaluations>0);
            k=(I.SwitchFE-N)/10;
            assert(~any(cognitived(1:k))&&all(cognitived(k+1:end)));
        end
        if strcmp(seekVariant,'A0')
            assert(all(dg.SeekEval(2:5)==0));
        elseif strcmp(seekVariant,'A4')
            assert(dg.SeekEval(5)>0&&all(dg.SeekEval(2:4)==0));
        end
        assert(P.seekEliteGain==0&&P.traceBoostGain==0&&P.useJump);
        assert(P.evaluationsPerRound==10&&P.perOwnerCap==2);
        assert(numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0));
    end

    function value=objective(x)
        calls=calls+1;totalCalls=totalCalls+1;
        assert(calls<=size(recPoints,1));
        assert(all(isfinite(x))&&all(x>=lb&x<=ub));
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
