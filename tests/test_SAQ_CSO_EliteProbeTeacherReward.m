function test_SAQ_CSO_EliteProbeTeacherReward
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
out=fullfile(root,'work','saq_teacher_reward_validation_20261014');if ~isfolder(out),mkdir(out);end
N=50;D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(123);p0=lb+rand(N,D).*(ub-lb);
mode='sphere';points=[];checks=cell(0,1);
s=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1250,...
 'policy','q','acceptance','replace','audit',true,'progressWindowFE',10,'progressThreshold',1e6);
for policy={'base','rule','random','q'}
 for budget=[50 51 59 160 1250]
  s.policy=policy{1};s.maxEvaluations=budget;s.rewardScheme='legacy';points=[];
  [B,T,I]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);oldPoints=points;points=[];
  [BR,TR,IR]=SAQ_CSO_EliteProbeTeacherReward(@objective,s,[],N,456);
  assert(isequal(B,BR)&&isequal(T,TR)&&isequal(points,oldPoints));
  for field={'WindowLog','ProbeLog','UpdateLog','QTable','QVisits','RealPopulation','PersonalBest','Velocity'}
   assert(isequaln(I.(field{1}),IR.(field{1})));
  end
 end
 checks{end+1}=struct('Check',['Legacy-exact-equivalence-' policy{1}],'Passed',true);
end
s.progressThreshold=1e-8;
for policy={'base','rule','random'}
 s.policy=policy{1};s.rewardScheme='teacher';s.maxEvaluations=1250;points=[];
 [B,T,I]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);oldPoints=points;points=[];
 [BR,TR,IR]=SAQ_CSO_EliteProbeTeacherReward(@objective,s,[],N,456);
 assert(isequal(B,BR)&&isequal(T,TR)&&isequal(points,oldPoints));
 verifyRewards(IR);assert(any(IR.WindowLog(:,16)==10));
 checks{end+1}=struct('Check',['Teacher-nonlearning-search-unchanged-' policy{1}],'Passed',true);
end
mode='flat';s.progressThreshold=1e-4;s.policy='q';s.rewardScheme='teacher';s.maxEvaluations=5050;points=[];
[B,T,I]=SAQ_CSO_EliteProbeTeacherReward(@objective,s,[],N,456);
assert(size(points,1)==5050&&I.Evaluations==5050&&all(T==1)&&B.Cost==1);
assert(I.ProbeEvaluations>0&&I.ProbeWritebacks==I.ProbeEvaluations);
assert(all(I.ProbeAfterVelocity==0,'all')&&all(I.Fitness==1)&&all(I.PersonalBestCost==1));
assert(all(points>=lb & points<=ub,'all')&&I.MaxParentEvaluations<=2);
verifyRewards(I);assert(any(I.WindowLog(:,16)==.5)&&any(I.WindowLog(:,16)==-1));
assert(~any(I.WindowLog(I.WindowLog(:,19)==0,16)==.5));
assert(~any(I.WindowLog(I.WindowLog(:,7)==0,16)==.5));
checks{end+1}=struct('Check','Flat-probes-rewarded-only-if-executed-and-low-progress','Passed',true);
Q=zeros(size(I.QTable));visits=zeros(size(Q));u=I.UpdateLog;
for k=1:size(u,1)
 ps=u(k,1);pa=u(k,2);reward=u(k,3);
 if u(k,5)==1,boot=0;else
  nextWindow=find(I.WindowLog(:,1)==u(k,7),1);assert(~isempty(nextWindow));allowed=1;
  if I.WindowLog(nextWindow,8)>0,allowed=[1 2];end
  boot=.9^((u(k,7)-u(k,6))/100)*max(Q(u(k,4),allowed));
 end
 Q(ps,pa)=Q(ps,pa)+.1*(reward+boot-Q(ps,pa));visits(ps,pa)=visits(ps,pa)+1;
end
assert(max(abs(Q-I.QTable),[],'all')<1e-12&&isequal(visits,I.QVisits));
assert(u(end,5)==1&&u(end,4)==0);
checks{end+1}=struct('Check','Teacher-Q-independent-replay-and-terminal-bootstrap','Passed',true);
for budget=[50 51 52 55 59 61 151 152 155 159 161]
 s.maxEvaluations=budget;points=[];[~,T,I]=SAQ_CSO_EliteProbeTeacherReward(@objective,s,[],N,456);
 assert(size(points,1)==budget&&numel(T)==budget&&I.Evaluations==budget);verifyRewards(I);
end
checks{end+1}=struct('Check','Teacher-partial-round-budget-boundaries','Passed',true);
s.maxEvaluations=1250;s.progressWindowFE=1e9;points=[];
[~,~,I]=SAQ_CSO_EliteProbeTeacherReward(@objective,s,[],N,456);
assert(I.QUpdates==0&&I.ProbeEvaluations==0&&all(I.WindowLog(:,16)==-1));
checks{end+1}=struct('Check','Infeasible-probe-cannot-earn-shaping-reward','Passed',true);
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
report=struct('AllPassed',true,'Checks',numel(checks),'EngineSHA256',sha(fullfile(root,'src','SAQ_CSO_EliteProbeTeacherReward.m')),...
 'OriginalEngineSHA256',sha(fullfile(root,'src','SAQ_CSO_EliteProbe.m')),'MATLABVersion',version);
fid=fopen(fullfile(out,'validation.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
disp(struct2table([checks{:}]));disp('Teacher reward correctness validation passed.');
 function value=objective(x)
  points(end+1,:)=x;if strcmp(mode,'flat'),value=1;else,value=sum(x.^2);end
 end
end
function verifyRewards(I)
w=I.WindowLog;
for k=1:size(w,1)
 gain=max(0,w(k,13)-w(k,15));expected=-1;
 if gain>=I.ProgressThreshold*w(k,6),expected=10;elseif w(k,7)>0&&w(k,19)>0,expected=.5;end
 assert(w(k,16)==expected);
end
end
function digest=sha(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
