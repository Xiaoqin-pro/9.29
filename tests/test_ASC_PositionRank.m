function test_ASC_PositionRank
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fullfile(root,'archive','legacy'));
out=fullfile(root,'work','asc_position_rank_validation_20261015');if ~isfolder(out),mkdir(out);end
N=50;D=7;rng(111);p0=-100+200*rand(N,D);lb=-100*ones(1,D);ub=100*ones(1,D);
s=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1250,'positionRankRule','sum');
points=[];mode='sphere';checks=cell(0,1);auditCalls=0;
for budget=[51 52 59 60 61 1250 2050]
 s.maxEvaluations=budget;points=[];[B,T,I]=ASC_NoFarness(@objective,s,[],N,321);old=points;points=[];
 [BB,TT,II]=ASC_NoFarness_PositionRank(@objective,s,[],N,321);
 assert(isequal(old,points)&&isequal(B,BB)&&isequal(T,TT));assert(isequal(I.RoundLog,II.RoundLog(:,1:15)));
 assert(size(points,1)==budget&&II.Evaluations==budget&&all(isfinite(T))&&all(diff(T)<=0));
end
checks{end+1}=struct('Check','Sum-mode-pointwise-original-equivalence-all-tail-budgets','Passed',true);
for rule={'sum','either'}
 s.maxEvaluations=3050;s.positionRankRule=rule{1};points=[];[B,T,I]=ASC_NoFarness_PositionRank(@objective,s,[],N,321);captured=points;
 assert(size(captured,1)==3050&&all(captured>=lb&captured<=ub,'all'));
 assert(B.Cost==min(sum(captured.^2,2))&&all(diff(T)<=0));
 assert(I.TracingEvaluations+I.SeekingEvaluations+N==3050);
 assert(sum(I.RoundLog(:,16))==I.TracingEvaluations&&sum(I.RoundLog(:,17))==I.SeekingEvaluations);
 assert(I.MaxOwnerEvaluations<=2);
 points=[];[BB,TT,II]=ASC_NoFarness_PositionRank(@objective,s,[],N,321);assert(isequal(B,BB)&&isequal(T,TT)&&isequal(captured,points));
 checks{end+1}=struct('Check',['Counted-bounds-best-archive-repeatability-' rule{1}],'Passed',true);
end
% Actual helper, materialized unchanged under a callable name for a hand-checkable fixture.
text=fileread(fullfile(root,'ASC_NoFarness_PositionRank.m'));start=strfind(text,'function [sel,newRow]=geometryScreen');stop=strfind(text,'function p=ascDefaults');
fixture=strrep(text(start(1):stop(1)-1),'geometryScreen','asc_rank_fixture');f=fopen(fullfile(out,'asc_rank_fixture.m'),'w');fprintf(f,'%s',fixture);fclose(f);addpath(out);
pool=[2;9;1;8];owner=[1;1;2;2];
[sa,xa]=asc_rank_fixture(pool,owner,0,0,2,2,1,'sum');[sb,xb]=asc_rank_fixture(pool,owner,0,0,2,2,1,'either');
assert(isequal(sa,sb)&&isequal(xa,[1;3])&&isequal(xb,[2;3]));
checks{end+1}=struct('Check','Rank-cancellation-fixture-changes-position-only-keeps-evaluation-set','Passed',true);
% Group velocity memory must propagate, and group modes remain finite/budgeted.
s.maxEvaluations=2050;s.useGroup=true;s.groupScreen='global';s.seekProbFixed=0;s.useAdaptiveProb=false;points=[];
[B,T,I]=ASC_NoFarness_PositionRank(@objective,s,[],N,321);assert(size(points,1)==2050&&all(isfinite(T))&&I.TracingEvaluations==2000);
assert(contains(text,'groupBestVec,groupCentre,role,vel]=')&&contains(text,'bestVec,centre,role,vel]=generateGroupCandidates'));
checks{end+1}=struct('Check','Group-velocity-wiring-and-full-Tracing-budget-path','Passed',true);
mode='flat';s=rmfield(s,{'useGroup','groupScreen','seekProbFixed','useAdaptiveProb'});points=[];
[B,T,I]=ASC_NoFarness_PositionRank(@objective,s,[],N,321);assert(I.Jumps>=1&&B.Cost==1&&all(T==1)&&size(points,1)==2050);
checks{end+1}=struct('Check','Flat-objective-jump-keeps-global-archive-and-budget','Passed',true);
oldpwd=pwd;cleanup=onCleanup(@()cd(oldpwd));cd(fullfile(root,'data','cec2017'));mode='cec';D=50;
rng(261013000+10000+3001);s.initialPopulation=-100+200*rand(N,D);s.lowerBound=-100*ones(1,D);s.upperBound=100*ones(1,D);s.maxEvaluations=1250;
for fid=[1 6 13 27]
 cecID=fid;s.positionRankRule='sum';points=[];[B,T,I]=ASC_NoFarness(@objective,s,[],N,262026001);p=points;points=[];
 [BB,TT,II]=ASC_NoFarness_PositionRank(@objective,s,[],N,262026001);assert(isequal(B,BB)&&isequal(T,TT)&&isequal(p,points));
 s.positionRankRule='either';points=[];[B,T,I]=ASC_NoFarness_PositionRank(@objective,s,[],N,262026001);
 assert(size(points,1)==1250&&I.Evaluations==1250&&all(diff(T)<=0));
 v=CEC2017Function(B.Vector,fid);auditCalls=auditCalls+1;assert(abs(v-B.Cost)<=1e-10*max(1,abs(v)));
 checks{end+1}=struct('Check',sprintf('CEC-F%d-original-parity-and-improved-budget',fid),'Passed',true);
end
% Full 100k original, sum equivalent, and improved candidate.
cecID=1;s.maxEvaluations=100000;s.positionRankRule='sum';points=[];[B,T,I]=ASC_NoFarness(@objective,s,[],N,262026001);p=points;points=[];
[BB,TT,II]=ASC_NoFarness_PositionRank(@objective,s,[],N,262026001);assert(isequal(B,BB)&&isequal(T,TT)&&isequal(p,points));
s.positionRankRule='either';points=[];[B,T,I]=ASC_NoFarness_PositionRank(@objective,s,[],N,262026001);
assert(size(points,1)==100000&&I.Evaluations==100000&&all(diff(T)<=0));v=CEC2017Function(B.Vector,1);auditCalls=auditCalls+1;assert(v==B.Cost);
checks{end+1}=struct('Check','Full-100k-original-parity-and-candidate-FE-best-recheck','Passed',true);
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
rep=struct('Passed',true,'Checks',numel(checks),'OriginalSHA256',sha(fullfile(root,'ASC_NoFarness.m')),...
 'ImprovedSHA256',sha(fullfile(root,'ASC_NoFarness_PositionRank.m')),'ExtraObjectiveRechecks',auditCalls,'MATLAB',version);
f=fopen(fullfile(out,'validation.json'),'w');fprintf(f,'%s',jsonencode(rep,PrettyPrint=true));fclose(f);disp(struct2table([checks{:}]));
 function value=objective(x)
  assert(all(isfinite(x))&&all(x>=s.lowerBound&x<=s.upperBound));points(end+1,:)=x;
  switch mode,case 'sphere',value=sum(x.^2);case 'flat',value=1;case 'cec',value=CEC2017Function(x,cecID);end
 end
end
function d=sha(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);m=java.security.MessageDigest.getInstance('SHA-256');m.update(bytes);d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
