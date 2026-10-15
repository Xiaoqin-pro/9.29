function test_ASC_JumpControls
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fullfile(root,'archive','legacy'));
out=fullfile(root,'work','asc_jump_validation_20261015');if ~isfolder(out),mkdir(out);end
N=50;D=7;rng(937);p0=-100+200*rand(N,D);mode='sphere';points=zeros(1,D);calls=0;totalCalls=0;rechecks=0;
s=struct('initialPopulation',p0,'lowerBound',-100*ones(1,D),'upperBound',100*ones(1,D),'maxEvaluations',2050);checks={};
% Explicit Original condition has precisely the default algorithm behaviour.
points=zeros(s.maxEvaluations,D);calls=0;[B,T,I]=ASC_NoFarness(@objective,s,[],N,718);P=points;
q=s;q.useJump=true;q.jumpFraction=.50;points=zeros(q.maxEvaluations,D);calls=0;[BB,TT,II]=ASC_NoFarness(@objective,q,[],N,718);
assert(isequal(B,BB)&&isequal(T,TT)&&isequal(P,points)&&isequal(I.RoundLog,II.RoundLog));
checks{end+1}=struct('Check','Explicit-original-parameters-identical-to-default','Passed',true);
for c=1:3
 q=s;q.useJump=c~=2;q.jumpFraction=.5;if c==3,q.jumpFraction=.1;end
 for budget=[51 52 59 60 61 1049 1050 1051 2050]
  q.maxEvaluations=budget;points=zeros(budget,D);calls=0;[B,T,I]=ASC_NoFarness(@objective,q,[],N,718);
  assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget);assert(all(isfinite(T))&&all(diff(T)<=0));
  assert(all(points>=q.lowerBound&points<=q.upperBound,'all'));
  assert(isequal(T,cummin(sum(points.^2,2)))&&B.Cost==min(sum(points.^2,2)));
  assert(sum(I.RoundLog(:,3))+N==budget&&all(I.RoundLog(:,2)-I.RoundLog(:,1)==I.RoundLog(:,3)));
  if c==2,assert(I.Jumps==0);end
 end
 checks{end+1}=struct('Check',sprintf('Condition-%d-tail-budgets-bounds-observed-best',c),'Passed',true);
end
% Forced stationary landscape: no improvements -> exactly two 1000FE triggers.
mode='flat';prefix=cell(3,1);traces=cell(3,1);log=cell(3,1);
for c=1:3
 q=s;q.useJump=c~=2;q.jumpFraction=.5;if c==3,q.jumpFraction=.1;end
 points=zeros(q.maxEvaluations,D);calls=0;[B,T,I]=ASC_NoFarness(@objective,q,[],N,718);
 assert(calls==2050&&all(T==1)&&B.Cost==1);prefix{c}=points(1:1050,:);traces{c}=points;log{c}=I.RoundLog;
 if c==2,assert(I.Jumps==0);else,assert(I.Jumps==2&&isequal(I.RoundLog(I.RoundLog(:,10)>0,2),[1050;2050]));end
end
assert(isequal(prefix{1},prefix{2})&&isequal(prefix{1},prefix{3}));
assert(~isequal(traces{1},traces{2})&&~isequal(traces{1},traces{3}));
q=s;q.useJump=false;q.jumpFraction=.1;points=zeros(q.maxEvaluations,D);calls=0;[~,~,I]=ASC_NoFarness(@objective,q,[],N,718);
assert(isequal(points,traces{2})&&isequal(I.RoundLog,log{2}));
checks{end+1}=struct('Check','Same-first-1050-points-and-correct-Jump-trigger','Passed',true);
checks{end+1}=struct('Check','Jump-disabled-makes-jumpFraction-behaviourally-neutral','Passed',true);
q=s;q.useJump=true;q.jumpFraction=.1;points=zeros(q.maxEvaluations,D);calls=0;[~,~,I]=ASC_NoFarness(@objective,q,[],N,718);
assert(isequal(points,traces{3})&&isequal(I.RoundLog,log{3}));
checks{end+1}=struct('Check','Light-Jump-repeatability','Passed',true);
% Small real-CEC runs; no function-specific parameter changes.
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017'));mode='cec';D=50;
for fid=[1 6 9 27]
 cecID=fid;rng(261013000+fid*10000+5001);q=s;q.initialPopulation=-100+200*rand(N,D);q.lowerBound=-100*ones(1,D);q.upperBound=100*ones(1,D);q.maxEvaluations=1250;
 for c=1:3
  q.useJump=c~=2;q.jumpFraction=.5;if c==3,q.jumpFraction=.1;end
  points=zeros(q.maxEvaluations,D);calls=0;[B,T,I]=ASC_NoFarness(@objective,q,[],N,262018001);
  assert(calls==1250&&I.Evaluations==1250&&all(diff(T)<=0));v=CEC2017Function(B.Vector,fid);rechecks=rechecks+1;assert(v==B.Cost);
 end
 checks{end+1}=struct('Check',sprintf('CEC-F%d-all-three-budget-and-best-recheck',fid),'Passed',true);
end
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
report=struct('Passed',true,'Checks',numel(checks),'EngineSHA256',sha(fullfile(root,'ASC_NoFarness.m')), ...
 'ValidationObjectiveCalls',totalCalls,'ValidationBestRechecks',rechecks,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');fprintf(f,'%s',jsonencode(report,PrettyPrint=true));fclose(f);disp(struct2table([checks{:}]));
 function v=objective(x)
  calls=calls+1;totalCalls=totalCalls+1;assert(calls<=size(points,1));
  assert(all(isfinite(x))&&all(x>=qBounds('lower')&x<=qBounds('upper')));points(calls,:)=x;
  switch mode,case 'sphere',v=sum(x.^2);case 'flat',v=1;case 'cec',v=CEC2017Function(x,cecID);end
 end
 function b=qBounds(side)
  if strcmp(side,'lower'),b=-100;else,b=100;end
 end
end
function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
