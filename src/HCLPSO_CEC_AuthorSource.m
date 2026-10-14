function [Best,T,info]=HCLPSO_CEC_AuthorSource(f,state,~,N,seed)
% CEC adapter of HCLPSO_PS_15_35.m from the author's public MATLAB archive.
% Source provenance in docs/HCLPSO_AUTHOR_CORRECTION_20261013.md.
% Interface-only adaptations: supplied p0, RNG seed, exact FE trace/cap,
% final audited best, finite movement guard. Search profile is not NEORL.
clockStart=tic; rng(seed,'twister'); D=size(state.initialPopulation,2);
assert(N==50 && size(state.initialPopulation,1)==N);
lb=state.lowerBound; ub=state.upperBound; budget=state.maxEvaluations;
assert(budget>=N && budget==floor(budget)); g1=15; g2=N-g1;
maxGen=ceil(budget/N); j=0:(1/(N-1)):1; j=j*10;
Pc=ones(D,1)*(0.0+((0.25).*(exp(j)-exp(j(1)))./(exp(j(N))-exp(j(1)))));
Weight=0.99-(1:maxGen)*0.79/maxGen; K=3-(1:maxGen)*1.5/maxGen;
c1=2.5-(1:maxGen)*2/maxGen; c2=0.5+(1:maxGen)*2/maxGen;
rangeMin=repmat(lb,N,1); rangeMax=repmat(ub,N,1); interval=rangeMax-rangeMin;
vMax=interval*0.2; vMin=-vMax;
pos=rangeMin+interval.*rand(N,D); % preserve original initialization RNG consumption
pos=state.initialPopulation; assert(all(isfinite(pos),'all') && all(pos>=lb&pos<=ub,'all'));
vel=vMin+(vMax-vMin).*rand(N,D);
T=nan(budget,1); result=zeros(1,N); fe=0; Best.Cost=inf; first=NaN;
for i=1:N
 result(i)=f(pos(i,:)); fe=fe+1;
 if result(i)<Best.Cost, Best.Cost=result(i); Best.Vector=pos(i,:); end
 T(fe)=Best.Cost;
end
[gbestVal,gidx]=min(result); gbestPos=pos(gidx,:); pbestPos=pos; pbestVal=result;
slope=zeros(N,1); friends=(1:N)'*ones(1,D); friendPos=zeros(N,D);
for i=1:N
 count=N; if i<=g1,count=g1;end
 [friends(i,:),friendPos(i,:)]=refresh(i,count,pbestPos,pbestVal,Pc(:,i)',D);
end
iterations=0; skips=0; refreshCount=0; generationIndex=0;
while fe<budget
 iterations=iterations+1; assert(iterations<=50*maxGen,'HCLPSO:IterationLimit','Movement guard reached.');
 generationIndex=min(maxGen,generationIndex+1); k=generationIndex;
 delta1=(K(k).*rand(g1,D).*(friendPos(1:g1,:)-pos(1:g1,:)));
 v1=Weight(k)*vel(1:g1,:)+delta1;
 v1=((v1<vMin(1:g1,:)).*vMin(1:g1,:))+((v1>vMax(1:g1,:)).*vMax(1:g1,:))+(((v1<vMax(1:g1,:))&(v1>vMin(1:g1,:))).*v1);
 pos1=pos(1:g1,:)+v1;
 temp=repmat(gbestPos,g2,1);
 delta2=(c1(k).*rand(g2,D).*(friendPos(g1+1:end,:)-pos(g1+1:end,:)))+(c2(k).*rand(g2,D).*(temp-pos(g1+1:end,:)));
 v2=Weight(k)*vel(g1+1:end,:)+delta2;
 v2=((v2<vMin(g1+1:end,:)).*vMin(g1+1:end,:))+((v2>vMax(g1+1:end,:)).*vMax(g1+1:end,:))+(((v2<vMax(g1+1:end,:))&(v2>vMin(g1+1:end,:))).*v2);
 pos2=pos(g1+1:end,:)+v2; pos=[pos1;pos2]; vel=[v1;v2];
 for i=1:N
  if fe>=budget,break;end
  if sum(pos(i,:)>rangeMax(i,:))+sum(pos(i,:)<rangeMin(i,:))==0
   result(i)=f(pos(i,:)); fe=fe+1;
   if result(i)<Best.Cost
    Best.Cost=result(i); Best.Vector=pos(i,:); if isnan(first),first=fe;end
   end
   T(fe)=Best.Cost;
   % Original source breaks at the final FE before internal best updates.
   if fe>=budget,break;end
  else
   skips=skips+1;
  end
  if result(i)<pbestVal(i)
   pbestPos(i,:)=pos(i,:); pbestVal(i)=result(i); slope(i)=0;
  else
   slope(i)=slope(i)+1;
  end
  if pbestVal(i)<gbestVal, gbestPos=pbestPos(i,:); gbestVal=pbestVal(i); end
 end
 for i=1:N
  if slope(i)>5
   count=N; if i<=g1,count=g1;end
   [friends(i,:),friendPos(i,:)]=refresh(i,count,pbestPos,pbestVal,Pc(:,i)',D);
   slope(i)=0; refreshCount=refreshCount+1;
  end
 end
end
info=struct('Algorithm','HCLPSO-AuthorSource-CEC-Adapter','Evaluations',fe, ...
 'InitialCost',T(N),'InitialPopulation',state.initialPopulation,'Seed',seed,'Seconds',toc(clockStart), ...
 'Iterations',iterations,'SkippedOutside',skips,'RefreshCount',refreshCount, ...
 'FirstImprovementEvaluation',first,'ExplorationGroup',g1,'ExploitationGroup',g2,'BoundaryClips',0);
end
function [friends,vector]=refresh(i,count,pbest,pbestCost,pc,D)
friends=i*ones(1,D);
a=ceil(count*rand(1,D)); b=ceil(count*rand(1,D));
donor=(pbestCost(a)<pbestCost(b)).*a+(pbestCost(a)>=pbestCost(b)).*b;
toss=ceil(rand(1,D)-pc);
if all(toss==ones(1,D)),order=randperm(D);toss(1,order(1))=0;end
friends=(1-toss).*donor+toss.*friends; vector=zeros(1,D);
for d=1:D,vector(d)=pbest(friends(d),d);end
end
