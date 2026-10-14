function [Best,T,info]=HPSO_TVAC_CEC(f,state,~,N,seed)
% Standalone HPSO_TVAC.m (2017 EPSO code package), explicit CEC position clip.
% No inertia term. This is a reference-code profile, not a 2004 table reproduction.
clockStart=tic;rng(seed,'twister');D=size(state.initialPopulation,2);budget=state.maxEvaluations;
lb=state.lowerBound;ub=state.upperBound;assert(N==50&&size(state.initialPopulation,1)==N&&budget>=N);
assert(all(lb==-100)&&all(ub==100));maxGen=ceil(budget/N);
c1=2.5-(1:maxGen)*2/maxGen;c2=.5+(1:maxGen)*2/maxGen;
restart=100-(1:maxGen)*(90)/maxGen;
rangeMin=repmat(lb,N,1);rangeMax=repmat(ub,N,1);span=rangeMax-rangeMin;
pop=rangeMin+span.*rand(N,D);pop=state.initialPopulation;
vel=-.2*span+(.4*span).*rand(N,D); %#ok<NASGU> original unused init RNG draws
fitness=zeros(1,N);fe=0;T=nan(budget,1);Best.Cost=inf;
for i=1:N
 fitness(i)=f(pop(i,:));fe=fe+1;
 if fitness(i)<Best.Cost,Best.Cost=fitness(i);Best.Vector=pop(i,:);end;T(fe)=Best.Cost;
end
[cost,idx]=min(fitness);gbest=pop(idx,:);pbest=pop;pbestCost=fitness;
k=1;iterations=0;zeroResets=0;clips=0;first=NaN;
while fe<budget
 iterations=iterations+1;k=min(maxGen,k+1);
 target=repmat(gbest,N,1);
 vel=(c1(k).*rand(N,D).*(pbest-pop))+(c2(k).*rand(N,D).*(target-pop));
 for i=1:N
  for d=1:D
   if vel(i,d)==0
    if rand(1)<.5,vel(i,d)=rand(1)*restart(k);else,vel(i,d)=-rand(1)*restart(k);end
    zeroResets=zeroResets+1;
   end
   vel(i,d)=sign(vel(i,d))*min(abs(vel(i,d)),100);
  end
 end
 pop=pop+vel;clips=clips+nnz(pop<lb|pop>ub);pop=max(lb,min(ub,pop));
 for i=1:N
  if fe>=budget,break;end
  value=f(pop(i,:));fitness(i)=value;fe=fe+1;
  if value<Best.Cost,Best.Cost=value;Best.Vector=pop(i,:);if isnan(first),first=fe;end;end
  T(fe)=Best.Cost;
  % Preserve original terminal internal break; audited best already includes last FE.
  if fe>=budget,break;end
  if value<pbestCost(i),pbest(i,:)=pop(i,:);pbestCost(i)=value;end
  if pbestCost(i)<cost,gbest=pbest(i,:);cost=pbestCost(i);end
 end
end
info=struct('Algorithm','HPSO-TVAC-CEC-ReferenceProfile','Evaluations',fe,'Seed',seed, ...
 'InitialPopulation',state.initialPopulation,'InitialCost',T(N),'Seconds',toc(clockStart), ...
 'Iterations',iterations,'ZeroVelocityRestarts',zeroResets,'BoundaryClips',clips, ...
 'FirstImprovementEvaluation',first,'InertiaTerm',false,'VelocityCap',100, ...
 'ScheduleGeneration',k);
end
