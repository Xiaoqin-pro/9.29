function test_ASC_NoFarness_EliteGaussian
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fullfile(root,'archive','legacy'));
out=fullfile(root,'work','asc_gaussian_validation_20261015');if ~isfolder(out),mkdir(out);end
N=50;D=7;rng(321);p0=-100+200*rand(N,D);mode='sphere';checks={};totalCalls=0;rechecks=0;
s=struct('initialPopulation',p0,'lowerBound',-100*ones(1,D),'upperBound',100*ones(1,D),'maxEvaluations',1250);
points=[];calls=0;
for b=[51 52 59 60 61 91 100 101 1250 2050]
 s.maxEvaluations=b;s.probeVariant='A0';calls=0;points=zeros(b,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);P=points;stream=rng;
 calls=0;points=zeros(b,D);[BO,TO,IO]=ASC_NoFarness(@objective,s,[],N,712);
 assert(calls==b&&isequal(B,BO)&&isequal(T,TO)&&isequal(P,points)&&isequal(stream,rng));
 assert(isequal(I.RoundLog(:,1:15),IO.RoundLog)&&I.ProbeEvaluations==0);
end
checks{end+1}=struct('Check','A0-pointwise-original-Best-T-global-RNG-and-round-log','Passed',true);
for variant={'A1','A2','A3'}
 for b=[51 59 60 61 91 99 100 101 102 109 110 111 151 155 161 2050]
  s.maxEvaluations=b;s.probeVariant=variant{1};calls=0;points=zeros(b,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);
  assert(calls==b&&I.Evaluations==b&&numel(T)==b&&all(diff(T)<=0));
  assert(isequal(T,cummin(sum(points.^2,2)))&&B.Cost==T(end));
  assert(I.ProbeEvaluations==floor(I.Rounds/5)&&sum(I.RoundLog(:,16))==I.ProbeEvaluations);
  assert(sum(I.RoundLog(:,3))+N==b&&all(I.RoundLog(:,17)+I.RoundLog(:,16)==I.RoundLog(:,3)));
  assert(all(points>=s.lowerBound&points<=s.upperBound,'all'));
  checkProbes(I,points);
 end
 checks{end+1}=struct('Check',['Actual-call-count-and-protected-probe-tail-budgets-' variant{1}],'Passed',true);
end
mode='flat';s.maxEvaluations=2050;s.probeVariant='A3';calls=0;points=zeros(2050,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);
assert(calls==2050&&I.Jumps>=1&&all(T==1)&&B.Cost==1);
assert(I.ProbeParentSuccesses==0&&isequal(I.ProbePrePositions,I.ProbePostPositions));
checks{end+1}=struct('Check','Failed-probe-does-not-overwrite-position-or-historical-memory','Passed',true);
% No additional ordinary search-stream consumption before the first probe.
mode='sphere';s.maxEvaluations=2050;s.probeVariant='A0';calls=0;points=zeros(2050,D);[~,~,~]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);base=points;
s.probeVariant='A3';calls=0;points=zeros(2050,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);
assert(isequal(base(1:99,:),points(1:99,:)));cached=points;cachedT=T;cachedB=B;
calls=0;points=zeros(2050,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);assert(isequal(cached,points)&&isequal(cachedB,B)&&isequal(cachedT,T));
checks{end+1}=struct('Check','First-probe-at-FE100-and-seeded-repeatability','Passed',true);
s.probeVariant='A0';s.probeSeed=11;calls=0;points=zeros(2050,D);[B,T,~]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);p=points;
s.probeSeed=987;calls=0;points=zeros(2050,D);[BB,TT,~]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,712);assert(isequal(p,points)&&isequal(B,BB)&&isequal(T,TT));
s=rmfield(s,'probeSeed');checks{end+1}=struct('Check','Disabled-probe-seed-cannot-change-original-trajectory','Passed',true);
% Export actual helper unchanged and independently rebuild its RNG arithmetic.
text=fileread(fullfile(root,'ASC_NoFarness_EliteGaussian.m'));a=strfind(text,'function [y,anchor,dims,sigma,anchorId]=makeEliteProbe');b=strfind(text,'function v=fieldOr');
helper=strrep(text(a:b-1),'makeEliteProbe','asc_probe_fixture');f=fopen(fullfile(out,'asc_probe_fixture.m'),'w');fprintf(f,'%s',helper);fclose(f);addpath(out);
for variant={'A1','A2','A3'}
 a=RandStream('mt19937ar','Seed',882);b=RandStream('mt19937ar','Seed',882);elite=[1 3 7 8 10 13 15 18 24 27];gbest=p0(1,:);progress=.4;k=5;
 [y,anchor,dims,sigma,id]=asc_probe_fixture(variant{1},p0,elite,gbest,200*ones(1,D),-100*ones(1,D),100*ones(1,D),progress,k,.05,.005,a);
 id2=elite(randi(b,numel(elite)));e=p0(id2,:);if strcmp(variant{1},'A2'),e=gbest;id2=0;end
 ds=randperm(b,D,k);sg=.05+(.005-.05)*progress;
 if strcmp(variant{1},'A1'),z=sqrt(3)*(2*rand(b,1,k)-1);else,z=randn(b,1,k);end
 expected=e;expected(ds)=e(ds)+sg*200*z;expected=min(100,max(-100,expected));
 assert(isequal(expected,y)&&isequal(e,anchor)&&isequal(ds,dims)&&sigma==sg&&id==id2&&isequal(a.State,b.State));
 checks{end+1}=struct('Check',['Independent-operator-and-probe-stream-replay-' variant{1}],'Passed',true);
end
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));mode='cec';D=50;
for fid=[1 6 9 12 13 21 24 27]
 cecID=fid;rng(261013000+fid*10000+6001);s.initialPopulation=-100+200*rand(N,D);s.lowerBound=-100*ones(1,D);s.upperBound=100*ones(1,D);s.maxEvaluations=1250;
 for variant={'A0','A1','A2','A3'}
  s.probeVariant=variant{1};calls=0;points=zeros(1250,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,262026001);
  assert(calls==1250&&I.Evaluations==1250&&all(diff(T)<=0));v=CEC2017Function(B.Vector,cecID);rechecks=rechecks+1;assert(v==B.Cost);checkProbes(I,points);
 end
end
checks{end+1}=struct('Check','Eight-CEC-functions-all-four-modes-budget-bounds-Best','Passed',true);
% Full-budget parity with unmodified ASC.
cecID=1;s.maxEvaluations=100000;s.probeVariant='A0';calls=0;points=zeros(100000,D);[B,T,I]=ASC_NoFarness_EliteGaussian(@objective,s,[],N,262026001);p=points;stream=rng;
calls=0;points=zeros(100000,D);[BO,TO,IO]=ASC_NoFarness(@objective,s,[],N,262026001);assert(isequal(B,BO)&&isequal(T,TO)&&isequal(p,points)&&isequal(stream,rng)&&calls==100000);
checks{end+1}=struct('Check','Full100k-A0-original-pointwise-and-RNG-equivalence','Passed',true);
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks),'EngineSHA256',sha(fullfile(root,'ASC_NoFarness_EliteGaussian.m')),...
 'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')),'ValidationObjectiveCalls',totalCalls,'BestRecheckCalls',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);disp(struct2table([checks{:}]));
 function value=objective(x)
  calls=calls+1;totalCalls=totalCalls+1;assert(calls<=size(points,1));assert(all(isfinite(x))&&all(x>=s.lowerBound&x<=s.upperBound));points(calls,:)=x;
  if strcmp(mode,'sphere'),value=sum(x.^2);elseif strcmp(mode,'flat'),value=1;else,value=CEC2017Function(x,cecID);end
 end
end
function checkProbes(I,points)
L=I.ProbeLog;D=size(points,2);k=min(5,D);
assert(size(L,1)==I.ProbeEvaluations&&all(I.ProbeAnchorEligible));
if isempty(L),return;end
assert(isequal(I.ProbePoints,points(L(:,1),:)));
assert(all(mod(L(:,2),5)==0)&&all(L(:,13)+1==I.RoundLog(L(:,2),3)));
assert(all(L(:,3)>=1&L(:,3)<=50)&&all(L(:,5)>=.005-1e-12&L(:,5)<=.05+1e-12));
for j=1:size(L,1)
 dims=I.ProbeDimensions(j,:);assert(numel(unique(dims))==k);other=setdiff(1:D,dims);
 assert(isequal(I.ProbePoints(j,other),I.ProbeAnchors(j,other)));
 if L(j,10),assert(isequal(I.ProbePostPositions(j,:),I.ProbePoints(j,:))&&all(I.ProbePostVelocity(j,:)==0)&&L(j,14)==L(j,7));
 else,assert(isequal(I.ProbePrePositions(j,:),I.ProbePostPositions(j,:))&&L(j,14)==L(j,6));end
end
assert(all((L(:,7)<L(:,6))==L(:,10))&&all((L(:,7)<L(:,8))==L(:,11)));
end
function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
