function test_SAQ_CSO_FourOperator
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
out=fullfile(root,'work','saq_four_operator_validation_20261014');if ~isfolder(out),mkdir(out);end
N=50;D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(123);p0=lb+rand(N,D).*(ub-lb);
mode='sphere';points=[];checks=cell(0,1);
s=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1250,...
 'policy','base','acceptance','greedy','audit',true);
for budget=[50 51 52 55 59 61 151 159 161 1250]
 s.maxEvaluations=budget;points=[];[B,T,I]=SAQ_CSO_FourOperator(@objective,s,[],N,456);actual=points;
 points=[];[BR,TR,~]=SAQ_CSO_SeekingWindow(@objective,s,[],N,456);
 assert(isequal(B,BR)&&isequal(T,TR)&&isequal(actual,points));assert(I.Evaluations==budget);
end
checks{end+1}=struct('Check','Base-pointwise-Fixed6-equivalence-and-tail-budgets','Passed',true);
% Independent replay of all three candidate formulas using seeded streams.
x=p0(1,:);realX=p0(2,:);best=p0(3,:);progress=.6;
for action=2:4
 a=RandStream('mt19937ar','Seed',334);b=RandStream('mt19937ar','Seed',334);
 [actual,meta]=SAQ_SeekingOperator(action,x,realX,best,p0,1,lb,ub,progress,a);
 expected=x;k=max(1,round(.2*D));
 if action==2
  peers=2:N;order=randperm(b,numel(peers),2);r=peers(order(1));t=peers(order(2));dims=randperm(b,D,k);
  noise=.025*(ub(dims)-lb(dims))*(1-progress).*(2*rand(b,1,k)-1);
  expected(dims)=x(dims)+.5*(p0(r,dims)-p0(t,dims))+noise;
  assert(meta(1)==r&&meta(2)==t&&r~=t&&r~=1&&t~=1);
 elseif action==3
  d=randi(b,D);expected=best;expected(d)=best(d)+(ub(d)-lb(d))*(1-.9*progress)*randn(b);
 else
  dims=randperm(b,D,k);expected=realX;expected(dims)=lb(dims)+ub(dims)-realX(dims);
 end
 width=ub-lb;folded=mod(expected-lb,2*width);expected=lb+width-abs(folded-width);
 assert(isequal(actual,expected)&&isequal(a.State,b.State));
 checks{end+1}=struct('Check',sprintf('Independent-action-%d-formula-and-RNG-replay',action),'Passed',true);
end
mode='flat';
for policy={'base','rule','random','q'}
 s.policy=policy{1};s.maxEvaluations=4050;points=[];
 [B,T,I]=SAQ_CSO_FourOperator(@objective,s,[],N,456);
 assert(size(points,1)==4050&&numel(T)==4050&&all(T==1)&&B.Cost==1);
 assert(all(points>=lb&points<=ub,'all')&&I.MaxParentEvaluations<=2);
 assert(I.EscapeEvaluations==sum(I.WindowLog(:,19))&&sum(I.OperatorFE)==I.SeekingEvaluations);
 assert(I.TracingEvaluations+I.SeekingEvaluations+N==4050);
 assert(isequal(I.RealPopulation,p0)&&isequal(I.PersonalBest,p0));
 verify(I);
 if ~strcmp(policy{1},'base'),assert(I.EscapeEvaluations>0);end
 if strcmp(policy{1},'q'),assert(I.QUpdates==size(I.WindowLog,1));else,assert(I.QUpdates==0);end
 checks{end+1}=struct('Check',['State-reward-Q-and-counting-' policy{1}],'Passed',true);
end
s.policy='q';mode='sphere';s.maxEvaluations=2050;points=[];[~,~,I]=SAQ_CSO_FourOperator(@objective,s,[],N,456);verify(I);
assert(max(abs(sum(I.RealPopulation.^2,2)-I.Fitness))<1e-9);
assert(max(abs(sum(I.PersonalBest.^2,2)-I.PersonalBestCost))<1e-9);
checks{end+1}=struct('Check','Q-sphere-real-and-personal-best-fitness-consistent','Passed',true);
for budget=[50 51 52 55 59 61 151 152 155 159 161]
 s.maxEvaluations=budget;points=[];[~,T,I]=SAQ_CSO_FourOperator(@objective,s,[],N,456);
 assert(size(points,1)==budget&&numel(T)==budget);verify(I);
end
checks{end+1}=struct('Check','Q-partial-budget-boundaries','Passed',true);
s.lowerBound=zeros(1,D);s.upperBound=zeros(1,D);s.initialPopulation=zeros(N,D);s.maxEvaluations=1250;
points=[];[~,~,I]=SAQ_CSO_FourOperator(@objective,s,[],N,456);assert(I.EscapeEvaluations==0&&I.QUpdates==0);verify(I);
checks{end+1}=struct('Check','Zero-width-domain-masks-invalid-actions','Passed',true);
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
report=struct('AllPassed',true,'Checks',numel(checks),'EngineSHA256',sha(fullfile(root,'src','SAQ_CSO_FourOperator.m')),...
 'OperatorSHA256',sha(fullfile(root,'src','SAQ_SeekingOperator.m')),'MATLABVersion',version);
fid=fopen(fullfile(out,'validation.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
disp(struct2table([checks{:}]));disp('Four operator validation passed.');
 function value=objective(x)
  points(end+1,:)=x;if strcmp(mode,'flat'),value=1;else,value=sum(x.^2);end
 end
end
function verify(I)
w=I.WindowLog;stall=0;Q=zeros(9,4);visits=zeros(9,4);u=I.UpdateLog;
for k=1:size(w,1)
 if k>1
  improved=max(0,w(k-1,13)-w(k-1,15))>=I.ProgressThreshold*w(k-1,6);
  if improved,stall=0;else,stall=stall+1;end
 end
 assert(w(k,5)==stall);stag=1+double(stall>0)+double(stall>=10);
 assert(w(k,3)==3*(w(k,4)-1)+stag&&w(k,7)==double(stag==3));
 assert(w(k,10)>=1&&w(k,10)<=4);
 improved=max(0,w(k,13)-w(k,15))>=I.ProgressThreshold*w(k,6);expected=-1;
 if improved,expected=10;elseif stag==3&&w(k,10)>=3&&w(k,19)>0,expected=.5;end
 assert(w(k,16)==expected);
end
for k=1:size(u,1)
 ps=u(k,1);pa=u(k,2);boot=0;
 if u(k,5)==0
  next=find(w(:,1)==u(k,7),1);allowed=1;if w(next,8)>0,allowed=1:4;end
  boot=.9^((u(k,7)-u(k,6))/100)*max(Q(u(k,4),allowed));
 end
 Q(ps,pa)=Q(ps,pa)+.1*(u(k,3)+boot-Q(ps,pa));visits(ps,pa)=visits(ps,pa)+1;
end
assert(max(abs(Q-I.QTable),[],'all')<1e-12&&isequal(visits,I.QVisits));
if ~isempty(u),assert(u(end,5)==1&&u(end,4)==0);end
end
function digest=sha(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
