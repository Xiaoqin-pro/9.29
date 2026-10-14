function test_HPSO_DMS_baselines
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
work=fullfile(root,'work','pso_baselines_audit_20261013');addpath(work);
checks=[0,0];calls=0;points=[];lb=[];ub=[];f=[];budget=0;N=0;state=[];seed=0;D=0;
for D=[7,50]
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(610);pool=lb+rand(50,D).*(ub-lb);
 for method=1:2
  N=50;if method==2,N=30;end
  for budget=[N,N+1,N+17,600,2000,6000]
   for seed=[611,612]
    state=struct('initialPopulation',pool(1:N,:),'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditPSO',true);
    f=@(x)sum(x.^2);oneCase;
   end
  end
 end
end
% Constant objective exercises equal-cost pbest and forced zero restarts.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);
for method=1:2
 N=50;if method==2,N=30;end;budget=6000;seed=613;
 state=struct('initialPopulation',100*ones(N,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditPSO',true);
 f=@(x)1;oneCase;
end
% Independent first-generation HPSO fixture, with no inertia and explicit cap.
N=50;D=7;lb=-100*ones(1,D);ub=100*ones(1,D);budget=100;seed=614;
p0=100*ones(N,D);p0(1,:)=0;
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
rng(seed,'twister');rand(N,D);rand(N,D);a=rand(N,D);b=rand(N,D);
manual=.5*a.*zeros(N,D)+2.5*b.*(-p0);zero=0;
for i=1:N
 for d=1:D
  if manual(i,d)==0
   if rand<.5,manual(i,d)=rand*10;else,manual(i,d)=-rand*10;end;zero=zero+1;
  end
  manual(i,d)=sign(manual(i,d))*min(abs(manual(i,d)),100);
 end
end
expected=max(lb,min(ub,p0+manual));f=@(x)sum(x.^2);calls=0;points=zeros(budget,D);
[~,~,I]=HPSO_TVAC_CEC(@capture,state,[],N,seed);
assert(isequal(points(N+1:2*N,:),expected)&&I.ZeroVelocityRestarts==zero&&~I.InertiaTerm);
assert(max(abs(manual),[],'all')==100);
% Explicit restart + position-boundary witness at the upper boundary.
state.initialPopulation=100*ones(N,D);f=@(x)1;calls=0;points=zeros(budget,D);
[~,~,I]=HPSO_TVAC_CEC(@capture,state,[],N,seed);assert(I.ZeroVelocityRestarts==N*D&&I.BoundaryClips>0);
% Independent first-generation DMS local-best/membership fixture.
N=30;D=7;budget=6000;seed=615;lb=-100*ones(1,D);ub=100*ones(1,D);
rng(616);p0=.001*rand(N,D);state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditPSO',true);
rng(seed,'twister');rand(N,D);V=-40+80*rand(N,D);order=randperm(N);groups=reshape(order,3,10)';
membership=zeros(1,N);targets=zeros(10,D);cost=sum(p0.^2,2);
for g=1:10,membership(groups(g,:))=g;[~,ix]=min(cost(groups(g,:)));targets(g,:)=p0(groups(g,ix),:);end
expected=zeros(N,D);
for i=1:N
 a=rand(1,D);b=rand(1,D);delta=1.49445.*a.*zeros(1,D)+1.49445.*b.*(targets(membership(i),:)-p0(i,:));
 paperWeight=.9-.7/ceil((budget-N)/N);v=paperWeight.*V(i,:)+delta;v=max(-40,min(40,v));expected(i,:)=p0(i,:)+v;
 assert(sum(expected(i,:).^2)>cost(i)); % guarantees no async best change in this fixture
end
f=@(x)sum(x.^2);calls=0;points=zeros(budget,D);
[~,~,I]=DMS_PSO_SIS_CEC(@capture,state,[],N,seed);
assert(isequal(I.InitialGroups,groups)&&isequal(points(N+1:2*N,:),expected));
assert(I.RegroupCount==floor(I.LocalGenerationLimit/5));
assert(I.InertiaStart==.9&&I.InertiaEnd==.2&&I.Acceleration==1.49445);
assert(isequal(I.PhaseLog(I.PhaseLog(:,3)==0,1),(1:I.LocalGenerationLimit)'));
assert(I.PhaseLog(find(I.PhaseLog(:,3)==1,1),1)==I.LocalGenerationLimit+1);
for j=1:numel(I.GroupLog),ids=I.GroupLog{j};assert(isequal(sort(ids(:)),(1:N)')&&isequal(size(ids),[10,3]));end
% D50 true CEC witnesses: finite objectives for all29; two100k profiles per method.
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
for fid=[1,3:30],assert(isfinite(CEC2017Function(zeros(1,D),fid)));end
rng(617);pool=lb+rand(50,D).*(ub-lb);
for method=1:2
 N=50;if method==2,N=30;end
 for fid=[6,13]
  for budget=[600,100000]
   seed=618;state=struct('initialPopulation',pool(1:N,:),'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditPSO',true);
   f=@(x)CEC2017Function(x,fid);oneCase;
  end
 end
end
fid=fopen(fullfile(work,'preflight.json'),'w');fprintf(fid,'%s',jsonencode( ...
 struct('HPSOExactOraclePairs',checks(1),'DMSPaperCoreOraclePairs',checks(2), ...
 'DMSPaperInertiaWitness',true,'IndependentHPSOStepWitness',true,'ZeroRestartAndClipWitness',true,'IndependentDMSStepWitness',true, ...
 'DMSGroupsRegroupAndSwitchWitness',true,'D50FiniteFunctions',29,'Full100kCasesPerMethod',2, ...
 'DMSIdentity','SIS2005 paper reconstruction, not an exact original-paper table reproduction', ...
 'HPSOIdentity','2017 standalone reference plus explicit CEC position clip', ...
 'SourceHashes',struct('HPSO',SourceFileSHA256(fullfile(root,'src','HPSO_TVAC_CEC.m')), ...
 'DMS',SourceFileSHA256(fullfile(root,'src','DMS_PSO_SIS_CEC.m'))),'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS HPSO exact%d DMS paper-core exact%d plus independent behavior/100k witnesses\n',checks(1),checks(2));
 function oneCase
  calls=0;points=zeros(budget,D);
  if method==1,[Bo,To,Io]=HPSO_ReferenceOracle(@capture,state,[],N,seed);
  else,[Bo,To,Io]=DMS_PaperCoreOracle(@capture,state,[],N,seed);end
  Po=points;Ro=rng;calls=0;points=zeros(budget,D);
  if method==1,[B,T,I]=HPSO_TVAC_CEC(@capture,state,[],N,seed);
  else,[B,T,I]=DMS_PSO_SIS_CEC(@capture,state,[],N,seed);end
  flags=[Bo.Cost==B.Cost,isequal(Bo.Vector,B.Vector),isequal(To,T),isequal(Po,points),isequal(Ro,rng),Io.Iterations==I.Iterations];
  assert(all(flags),'Mismatch method%d D%d budget%d seed%d flags%s',method,D,budget,seed,mat2str(flags));
  assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0));
  assert(abs(f(B.Vector)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
  checks(method)=checks(method)+1;
 end
 function value=capture(x)
  calls=calls+1;assert(calls<=budget&&all(x>=lb&x<=ub)&&all(isfinite(x)));points(calls,:)=x;value=f(x);
 end
end
