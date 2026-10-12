function [Best,T,info]=CLPSO_CEC_AuthorSource(f,state,~,N,seed)
% CEC adapter of the exact public CLPSO_new_func mechanics, not the paper parameterization.
% Source P-N-Suganthan/CODES/2006-IEEE-TEC-CLPSO.zip, commit recorded in audit.
% Differences restricted to supplied initial population, deterministic RNG, hard actual FE cap,
% FE-indexed trace, finite movement guard, and repeating the last valid inertia generation.
clockStart=tic;pop=state.initialPopulation;D=size(pop,2);lb=state.lowerBound;ub=state.upperBound;budget=state.maxEvaluations;assert(size(pop,1)==N&&N>=4&&budget>=N);
rng(seed,'twister');rand(N,D); % retain original initialization RNG draws before supplied p0 override
t=0:1/(N-1):1;t=5.*t;Pc=(.5*(exp(t)-exp(t(1)))/(exp(t(N))-exp(t(1))))';gap=5;c=1.49445;vmax=.2*(ub-lb);
fitness=zeros(N,1);T=nan(budget,1);Best.Cost=inf;
for i=1:N,fitness(i)=f(pop(i,:));if fitness(i)<Best.Cost,Best.Cost=fitness(i);Best.Vector=pop(i,:);end;T(i)=Best.Cost;end
fe=N;V=-repmat(vmax,N,1)+2*repmat(vmax,N,1).*rand(N,D);pbest=pop;cost=fitness;stay=zeros(N,1);exemplar=repmat((1:N)',1,D);
for i=1:N,exemplar(i,:)=drawExemplar(i,exemplar(i,:),cost,Pc(i),N,D);end
maxGen=ceil(budget/N);generationIndex=1;iterations=0;refresh=0;outside=0;limit=50*maxGen;first=NaN;
while fe<budget
 iterations=iterations+1;assert(iterations<=limit,'CLPSO:IterationLimit','Author-source adapter exceeded declared movement guard.');generationIndex=min(maxGen,generationIndex+1);w=.9-generationIndex*(.7/maxGen);
 for i=1:N
  if fe>=budget,break;end
  if stay(i)>=gap,stay(i)=0;exemplar(i,:)=drawExemplar(i,i*ones(1,D),cost,Pc(i),N,D);refresh=refresh+1;end
  target=pbest(sub2ind(size(pbest),exemplar(i,:),1:D));
  aa=c*rand(1,D).*(target-pop(i,:));rand(1,D); % source consumes a zero gbest contribution RNG vector
  V(i,:)=w*V(i,:)+aa;V(i,:)=max(-vmax,min(vmax,V(i,:)));pop(i,:)=pop(i,:)+V(i,:);
  if any(pop(i,:)<lb | pop(i,:)>ub),outside=outside+1;continue;end
  value=f(pop(i,:));fe=fe+1;
  if cost(i)<=value,stay(i)=stay(i)+1;else,pbest(i,:)=pop(i,:);cost(i)=value;end
  % Public source accumulates failures until refresh; improvement does not reset stay.
  if value<Best.Cost,Best.Cost=value;Best.Vector=pop(i,:);if isnan(first),first=fe;end;end
  T(fe)=Best.Cost;
 end
end
info=struct('Algorithm','CLPSO-AuthorSource-CEC-Adapter','Evaluations',fe,'InitialCost',T(N),'InitialPopulation',state.initialPopulation,'Seed',seed,'Seconds',toc(clockStart),'Iterations',iterations,'SkippedOutside',outside,'BoundaryClips',0,'RefreshCount',refresh,'FirstImprovementEvaluation',first,'Pc',Pc,'InertiaGeneration',generationIndex);
end
function donors=drawExemplar(i,donors,cost,Pc,N,D)
randperm(D); % original ai mask uses m=0, but still draws a random permutation
one=ceil(N*rand(1,D));two=ceil(N*rand(1,D));chooseFirst=(cost(one)<cost(two))';selected=chooseFirst.*one+(~chooseFirst).*two;
mask=ceil(rand(1,D)-1+Pc);if all(mask==0),order=randperm(D);mask(order(1))=1;end
donors=mask.*selected+(1-mask).*donors;
end
