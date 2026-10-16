function test_ASC_NoFarness_QuotaCog
%TEST_ASC_NOFARNESS_QUOTACOG  Audit of the quota + cognition variant.
%
% The default configuration (cogSchedule = C00, nearShare = 0.5, seekVariant =
% A0) must reproduce ASC_NoFarness pointwise, and each mechanism must be
% switchable on its own so the two can be ablated independently.

root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,'-begin');addpath(fullfile(root,'data','cec2017'),'-begin');
addpath(fullfile(root,'archive','legacy'),'-begin');
out=fullfile(root,'work','qc_validation_20261015');
if ~isfolder(out),mkdir(out);end
N=50;D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
checks={};totalCalls=0;rechecks=0;
currentMode='sphere';cecID=1;calls=0;recPoints=zeros(N,D);
BUD1=1250;

[pts0,B0,T0,I0,rs0]=runOnce('sphere',BUD1,'C00',0.50);
[ptsO,BO,TO,IO,rsO]=runOnceOriginal('sphere',BUD1);
assert(isequal(pts0,ptsO)&&isequal(B0,BO)&&isequal(T0,TO));
assert(isequal(rs0,rsO)&&isequal(I0.RoundLog(:,1:15),IO.RoundLog(:,1:15)));
checks{end+1}=struct('Check','Default-configuration-is-bit-identical-to-original','Passed',true);

[~,~,TC,IC]=runOnce('sphere',BUD1,'C01',0.50);
assert(IC.CogEvaluations>0&&IC.SwitchStarted,'The cognitive direction never engaged.');
assert(~isequal(TC,T0),'Enabling cognition did not change the search.');
[~,~,TQ,IQ]=runOnce('sphere',BUD1,'C00',0.85);
assert(IQ.NearShare==0.85&&~isequal(TQ,T0),'Changing the quota split did not change the search.');
[~,~,TB,IB]=runOnce('sphere',BUD1,'C01',0.85);
assert(IB.CogEvaluations>0&&IB.NearShare==0.85);
checks{end+1}=struct('Check','Each-mechanism-switches-on-independently','Passed',true);

old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));
for fid=[1 6 9 12 13 21 24 27 3 4 17 29]
    for spec={'C00','C01'}
        for share=[0.50 0.85]
            cecID=fid;currentMode='cec';
            rng(262015000+fid*10000+7201,'twister');
            s=makeState(lb+rand(N,D).*(ub-lb),BUD1,spec{1},share,262015000+fid*10000+7201);
            calls=0;recPoints=zeros(BUD1,D);
            [Bc,Tc,Ic]=ASC_NoFarness_QuotaCog(@objective,s,[],N,262027201);
            assert(calls==BUD1&&Ic.Evaluations==BUD1);
            rechecks=rechecks+1;assert(CEC2017Function(Bc.Vector,cecID)==Bc.Cost);
            assert(abs(Ic.NearShare-share)<1e-12&&strcmp(Ic.CogSchedule,spec{1}));
            assert(numel(Tc)==BUD1&&all(isfinite(Tc))&&all(diff(Tc)<=0));
        end
    end
end
checks{end+1}=struct('Check','Twelve-CEC-functions-four-configurations','Passed',true);

currentMode='cec';cecID=1;BUD2=100000;
rng(262027201,'twister');s=makeState(lb+rand(N,D).*(ub-lb),BUD2,'C00',0.50,262027201);
calls=0;recPoints=zeros(BUD2,D);
[BF,TF,IF]=ASC_NoFarness_QuotaCog(@objective,s,[],N,262027201);
pF=recPoints;rngStateF=rng;
calls=0;recPoints=zeros(BUD2,D);[BO2,TO2,IO2]=ASC_NoFarness(@objective,s,[],N,262027201);
assert(isequal(BF,BO2)&&isequal(TF,TO2)&&isequal(pF,recPoints)&&isequal(rngStateF,rng));
assert(isequal(IF.RoundLog(:,1:15),IO2.RoundLog(:,1:15))&&calls==100000);
checks{end+1}=struct('Check','Full100k-default-configuration-pointwise-equivalence','Passed',true);

writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks), ...
    'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_QuotaCog.m')), ...
    'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
    'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');
fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));
disp(rep);

    function s=makeState(pop0,budget,cogSchedule,share,initSeed)
        s=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',budget, ...
            'initialPopulation',pop0,'cogSchedule',cogSchedule,'nearShare',share, ...
            'seekVariant','A0','seekRefineCount',2);
        rng(initSeed,'twister');
    end

    function [ptsOut,B,T,I,rngState]=runOnce(modeName,budget,cogSchedule,share)
        currentMode=modeName;rng(4711,'twister');
        s=makeState(lb+rand(N,D).*(ub-lb),budget,cogSchedule,share,4711);
        calls=0;recPoints=zeros(budget,D);
        [B,T,I]=ASC_NoFarness_QuotaCog(@objective,s,[],N,4711);
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
