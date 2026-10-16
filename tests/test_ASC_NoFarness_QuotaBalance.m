function test_ASC_NoFarness_QuotaBalance
%TEST_ASC_NOFARNESS_QUOTABALANCE  Audit of the quota-split variant.
%
% nearShare = 0.5 must reproduce ASC_NoFarness pointwise (evaluation points,
% best solution, best-so-far trace, global RNG state and the original round
% log), so the split is the only difference the experiment measures.  A
% different share must change the search, and the budget must stay fixed.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','qb_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

[ptsH,BH,TH,IH,rsH]=runOnce('sphere',BUD1,0.50);
[ptsO,BO,TO,IO,rsO]=runOnceOriginal('sphere',BUD1);
assert(isequal(ptsH,ptsO),'nearShare=0.5 changed the evaluation points.');
assert(isequal(BH,BO)&&isequal(TH,TO),'nearShare=0.5 changed the result or trace.');
assert(isequal(rsH,rsO),'nearShare=0.5 changed the global RNG state.');
assert(isequal(IH.RoundLog(:,1:15),IO.RoundLog(:,1:15)),'nearShare=0.5 changed the round log.');
checks{end+1}=struct('Check','NearShare-half-is-bit-identical-to-original','Passed',true);

for sh=[0.70 0.85]
    [pts,Bv,Tv,Iv]=runOnce('sphere',BUD1,sh);
    assert(~isequal(pts,ptsO),sprintf('nearShare=%.2f did not change the search.',sh));
    assert(numel(Tv)==BUD1&&Iv.Evaluations==BUD1&&all(diff(Tv)<=0));
    assert(Iv.NearShare==sh&&Iv.Parameters.nearShare==sh);
end
checks{end+1}=struct('Check','Other-shares-change-the-search-and-keep-the-budget','Passed',true);

old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for sh=[0.50 0.70 0.85]
        cecID=fid;currentMode='cec';
        rng(262015000+fid*10000+7101,'twister');
        s=makeState(lb+rand(N,D).*(ub-lb),BUD1,sh,262015000+fid*10000+7101);
        calls=0;recPoints=zeros(BUD1,D);
        [Bc,Tc,Ic]=ASC_NoFarness_QuotaBalance(@objective,s,[],N,262027101);
        assert(calls==BUD1&&Ic.Evaluations==BUD1);
        rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
        assert(Ic.NearShare==sh);
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions-three-shares','Passed',true);

currentMode='cec';cecID=1;BUD2=100000;
rng(262027101,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,0.50,262027101);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_QuotaBalance(@objective,s,[],N,262027101);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262027101);
assert(isequal(BF,BO2)&&isequal(TF,TO2)&&isequal(pF,recPoints)&&isequal(rngStateF,rng));
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15))&&calls==100000);
checks{end+1}=struct('Check','Full100k-half-share-original-pointwise-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_QuotaBalance.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,share,initSeed)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'nearShare',share);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,share)
        currentMode=modeName;rng(4711,'twister');
        s=makeState(lb+rand(N,D).*(ub-lb),budget,share,4711);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_QuotaBalance(@objective,s,[],N,4711);
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
