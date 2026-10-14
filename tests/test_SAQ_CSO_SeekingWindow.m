function test_SAQ_CSO_SeekingWindow
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
out=fullfile(root,'work','saq_seeking_window_validation_20261014');if ~isfolder(out),mkdir(out);end
N=50;D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(123);p0=lb+rand(N,D).*(ub-lb);
mode='sphere';points=[];checks=cell(0,1);
s=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1250,...
 'policy','base','acceptance','greedy','audit',true,'progressWindowFE',10,'progressThreshold',1e6);
for budget=[50 51 52 55 59 61 151 152 159 161 1250]
 s.maxEvaluations=budget;points=[];[B,T,I]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);actual=points;
 points=[];[BR,TR,IR]=SAQ_CSO_EliteProbeTeacherReward(@objective,s,[],N,456);
 assert(isequal(B,BR)&&isequal(T,TR)&&isequal(actual,points));assert(I.Evaluations==budget);
 assert(isequaln(I.RoundLog(:,1:4),IR.RoundLog(:,1:4)));
end
checks{end+1}=struct('Check','Base-pointwise-identical-to-Fixed6-including-tail-budgets','Passed',true);
mode='flat';
for policy={'rule','random','q'}
 s.policy=policy{1};s.maxEvaluations=1250;points=[];
 [B,T,I]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);
 assert(size(points,1)==1250&&numel(T)==1250&&all(T==1)&&B.Cost==1);
 assert(all(points>=lb&points<=ub,'all')&&I.MaxParentEvaluations<=2);
 assert(I.EscapeEvaluations>0&&I.EscapeEvaluations==sum(I.WindowLog(:,19)));
 assert(I.TracingEvaluations+I.SeekingEvaluations+N==1250);
 verifyRewards(I);
 for k=1:I.EscapeEvaluations
  d=I.EscapeLog(k,4);other=setdiff(1:D,d);
  assert(isequal(I.EscapePoints(k,other),I.EscapeBases(k,other)));
  assert(I.EscapeLog(k,6)==1&&I.EscapeLog(k,9)==0&&I.EscapeLog(k,10)==0);
 end
 assert(isequal(I.RealPopulation,p0)&&isequal(I.PersonalBest,p0));
 if strcmp(policy{1},'rule')
  assert(max(I.WindowLog(:,19))>1&&all(I.WindowLog(I.WindowLog(:,10)==2,19)>0));
  active=I.RoundLog(:,5)==1;assert(all(I.RoundLog(active,4)==4));
 end
 if strcmp(policy{1},'q'),replayQ(I);else,assert(I.QUpdates==0);end
 checks{end+1}=struct('Check',['Window-generation-reward-counting-and-memory-' policy{1}],'Passed',true);
end
for budget=[50 51 52 55 59 61 151 152 155 159 161]
 s.policy='rule';s.maxEvaluations=budget;points=[];[~,T,I]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);
 assert(size(points,1)==budget&&numel(T)==budget);verifyRewards(I);
end
checks{end+1}=struct('Check','Escape-partial-budget-boundaries','Passed',true);
mode='sphere';s.policy='rule';s.maxEvaluations=1250;points=[];
[~,~,I]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);
assert(max(abs(sum(I.RealPopulation.^2,2)-I.Fitness))<1e-9);
assert(max(abs(sum(I.PersonalBest.^2,2)-I.PersonalBestCost))<1e-9);
verifyRewards(I);checks{end+1}=struct('Check','Real-and-personal-best-fitness-consistent','Passed',true);
s.policy='q';s.progressWindowFE=1e9;points=[];[~,T,I]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);p=points;
s.policySeed=555;s.probeSeed=999;points=[];[~,T2,I2]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);
assert(isequal(p,points)&&isequal(T,T2)&&I.QUpdates==0&&I2.EscapeEvaluations==0);
checks{end+1}=struct('Check','Masked-escape-and-independent-RNG','Passed',true);
s.lowerBound=zeros(1,D);s.upperBound=zeros(1,D);s.initialPopulation=zeros(N,D);s.progressWindowFE=10;
points=[];[~,~,I]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);assert(I.EscapeEvaluations==0&&I.QUpdates==0);
checks{end+1}=struct('Check','Zero-width-domain-has-no-escape-action','Passed',true);
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
report=struct('AllPassed',true,'Checks',numel(checks),'EngineSHA256',sha(fullfile(root,'src','SAQ_CSO_SeekingWindow.m')),...
 'OriginalEngineSHA256',sha(fullfile(root,'src','SAQ_CSO_EliteProbeTeacherReward.m')),'MATLABVersion',version);
fid=fopen(fullfile(out,'validation.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
disp(struct2table([checks{:}]));disp('Seeking window validation passed.');
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
function replayQ(I)
Q=zeros(size(I.QTable));visits=zeros(size(Q));u=I.UpdateLog;
for k=1:size(u,1)
 ps=u(k,1);pa=u(k,2);reward=u(k,3);boot=0;
 if u(k,5)==0
  nextWindow=find(I.WindowLog(:,1)==u(k,7),1);allowed=1;
  if I.WindowLog(nextWindow,8)>0,allowed=[1 2];end
  boot=I.Gamma^((u(k,7)-u(k,6))/100)*max(Q(u(k,4),allowed));
 end
 Q(ps,pa)=Q(ps,pa)+I.Alpha*(reward+boot-Q(ps,pa));visits(ps,pa)=visits(ps,pa)+1;
end
assert(max(abs(Q-I.QTable),[],'all')<1e-12&&isequal(visits,I.QVisits));
assert(u(end,5)==1&&u(end,4)==0);
end
function digest=sha(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
