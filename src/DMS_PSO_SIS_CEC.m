function [Best,T,info]=DMS_PSO_SIS_CEC(f,state,~,N,seed)
% SIS2005 base DMS-PSO paper reconstruction, not DMS-L-PSO author file.
% m3, R5, first90% nominal generations local then global. No local optimizer
% or coordinate-mixing mutation. Shared-prefix initialization, actual FE cap.
clockStart=tic;rng(seed,'twister');D=size(state.initialPopulation,2);budget=state.maxEvaluations;
lb=state.lowerBound;ub=state.upperBound;assert(N==30&&mod(N,3)==0&&size(state.initialPopulation,1)==N&&budget>=N);
groups=N/3;gsize=3;R=5;nominal=max(1,ceil((budget-N)/N));localLimit=floor(.9*nominal);
rangeMin=repmat(lb,N,1);rangeMax=repmat(ub,N,1);span=rangeMax-rangeMin;mv=.2*span;
pop=rangeMin+span.*rand(N,D);pop=state.initialPopulation;
e=zeros(N,1);T=nan(budget,1);fe=0;Best.Cost=inf;
for i=1:N
 e(i)=f(pop(i,:));fe=fe+1;if e(i)<Best.Cost,Best.Cost=e(i);Best.Vector=pop(i,:);end;T(fe)=Best.Cost;
end
vel=-mv+2.*mv.*rand(N,D);pbest=pop;pbestCost=e;
order=randperm(N);ids=reshape(order,gsize,groups)';membership=zeros(1,N);
gbest=zeros(groups,D);groupCost=zeros(1,groups);
for g=1:groups
 membership(ids(g,:))=g;[groupCost(g),ix]=min(pbestCost(ids(g,:)));gbest(g,:)=pbest(ids(g,ix),:);
end
initialGroups=ids;gen=0;skips=0;regroups=0;first=NaN;globalStartFE=NaN;
% Optional small-test audit records consume no randomness.
audit=isfield(state,'auditPSO')&&state.auditPSO;phaseLog=[];groupLog={};
while gen<localLimit&&fe<budget
 gen=gen+1;if audit,phaseLog(end+1,:)=[gen,fe,0];end %#ok<AGROW>
 for i=1:N
  if fe>=budget,break;end
  aa=1.49445.*rand(1,D).*(pbest(i,:)-pop(i,:))+1.49445.*rand(1,D).*(gbest(membership(i),:)-pop(i,:));
  inertia=.9-.7*min(gen,nominal)/nominal;
  vel(i,:)=inertia.*vel(i,:)+aa;
  vel(i,:)=(vel(i,:)>mv(i,:)).*mv(i,:)+(vel(i,:)<=mv(i,:)).*vel(i,:);
  vel(i,:)=(vel(i,:)<(-mv(i,:))).*(-mv(i,:))+(vel(i,:)>=(-mv(i,:))).*vel(i,:);
  pop(i,:)=pop(i,:)+vel(i,:);
  if any(pop(i,:)<lb|pop(i,:)>ub),skips=skips+1;continue;end
  e(i)=f(pop(i,:));fe=fe+1;
  tmp=(pbestCost(i)<e(i));pbest(i,:)=tmp.*pbest(i,:)+(1-tmp).*pop(i,:);pbestCost(i)=tmp.*pbestCost(i)+(1-tmp).*e(i);
  if pbestCost(i)<groupCost(membership(i)),groupCost(membership(i))=pbestCost(i);gbest(membership(i),:)=pbest(i,:);end
  if e(i)<Best.Cost,Best.Cost=e(i);Best.Vector=pop(i,:);if isnan(first),first=fe;end;end;T(fe)=Best.Cost;
 end
 if mod(gen,R)==0
  order=randperm(N);ids=reshape(order,gsize,groups)';
  for g=1:groups
   membership(ids(g,:))=g;[groupCost(g),ix]=min(pbestCost(ids(g,:)));gbest(g,:)=pbest(ids(g,ix),:);
  end
  regroups=regroups+1;if audit,groupLog{end+1}=ids;end %#ok<AGROW>
 end
end
[globalCost,ix]=min(groupCost);globalBest=gbest(ix,:);
while fe<budget
 if isnan(globalStartFE),globalStartFE=fe;end
 gen=gen+1;assert(gen<=50*nominal,'DMS:IterationLimit','Movement guard reached.');
 if audit,phaseLog(end+1,:)=[gen,fe,1];end %#ok<AGROW>
 for i=1:N
  if fe>=budget,break;end
  aa=1.49445.*rand(1,D).*(pbest(i,:)-pop(i,:))+1.49445.*rand(1,D).*(globalBest-pop(i,:));
  inertia=.9-.7*min(gen,nominal)/nominal;
  vel(i,:)=inertia.*vel(i,:)+aa;
  vel(i,:)=(vel(i,:)>mv(i,:)).*mv(i,:)+(vel(i,:)<=mv(i,:)).*vel(i,:);
  vel(i,:)=(vel(i,:)<(-mv(i,:))).*(-mv(i,:))+(vel(i,:)>=(-mv(i,:))).*vel(i,:);
  pop(i,:)=pop(i,:)+vel(i,:);
  if any(pop(i,:)<lb|pop(i,:)>ub),skips=skips+1;continue;end
  e(i)=f(pop(i,:));fe=fe+1;
  tmp=(pbestCost(i)<e(i));pbest(i,:)=tmp.*pbest(i,:)+(1-tmp).*pop(i,:);pbestCost(i)=tmp.*pbestCost(i)+(1-tmp).*e(i);
  if pbestCost(i)<globalCost,globalCost=pbestCost(i);globalBest=pbest(i,:);end
  if e(i)<Best.Cost,Best.Cost=e(i);Best.Vector=pop(i,:);if isnan(first),first=fe;end;end;T(fe)=Best.Cost;
 end
end
info=struct('Algorithm','DMS-PSO-SIS2005-PaperReconstruction','Seed',seed, ...
 'Evaluations',fe,'InitialPopulation',state.initialPopulation,'InitialCost',T(N), ...
 'Seconds',toc(clockStart),'Iterations',gen,'SkippedOutside',skips,'BoundaryClips',0, ...
 'RegroupCount',regroups,'RegroupPeriod',R,'SubgroupSize',gsize,'GroupCount',groups, ...
 'NominalGenerations',nominal,'LocalGenerationLimit',localLimit,'GlobalStartFE',globalStartFE, ...
 'FirstImprovementEvaluation',first,'InitialGroups',initialGroups,'PhaseLog',phaseLog, ...
 'GroupLog',{groupLog},'LocalSearchEnabled',false,'CoordinateMixingEnabled',false,'InertiaStart',.9,'InertiaEnd',.2,'Acceleration',1.49445);
end
