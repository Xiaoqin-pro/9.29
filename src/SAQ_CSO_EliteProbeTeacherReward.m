function [Best,T,info]=SAQ_CSO_EliteProbeTeacherReward(f,state,~,N,seed)
% Isolated reward-only candidate. Original engine remains frozen.
% Teacher shaping: effective gain +10; executed low-progress probe +0.5; else -1.
% Independent policy/probe RNGs do not consume the ordinary search stream.
pop=state.initialPopulation;D=size(pop,2);lb=reshape(state.lowerBound,1,[]);ub=reshape(state.upperBound,1,[]);
budget=state.maxEvaluations;policy=fieldOr(state,'policy','rule');acceptance=fieldOr(state,'acceptance','replace');
episodeFE=100;lookback=fieldOr(state,'progressWindowFE',1000);threshold=fieldOr(state,'progressThreshold',1e-4);
policySeed=fieldOr(state,'policySeed',mod(seed+3000001,2^32));probeSeed=fieldOr(state,'probeSeed',mod(seed+6000001,2^32));
audit=fieldOr(state,'audit',false);alpha=.1;gamma=.9;epsilon=.1;
rewardScheme=fieldOr(state,'rewardScheme','teacher');
assert(ismember(rewardScheme,{'legacy','teacher'}));
assert(N==50 && size(pop,1)==N && numel(lb)==D && numel(ub)==D);
assert(ismember(policy,{'base','rule','random','q'}) && ismember(acceptance,{'greedy','replace'}));
assert(budget>=N && budget==floor(budget) && all(lb<=ub) && all(isfinite(pop),'all'));
assert(all(pop>=lb & pop<=ub,'all') && lookback>0 && threshold>0 && isfinite(threshold));
policyRng=RandStream('mt19937ar','Seed',policySeed);probeRng=RandStream('mt19937ar','Seed',probeSeed);
rng(seed,'twister');SMP=5;seekDimCount=max(1,round(.20*D));
V=.01*(2*rand(N,D)-1).*(ub-lb);Vmax=.2*(ub-lb);
fitness=zeros(N,1);T=nan(budget,1);fe=0;Best=struct('Cost',inf,'Vector',pop(1,:));
if audit,evalPoints=nan(budget,D);evalLog=nan(budget,5);else,evalPoints=[];evalLog=[];end
for i=1:N
 value=f(pop(i,:));assert(isfinite(value));fitness(i)=value;fe=fe+1;
 if value<Best.Cost,Best.Cost=value;Best.Vector=pop(i,:);end
 T(fe)=Best.Cost;
 if audit,evalPoints(fe,:)=pop(i,:);evalLog(fe,:)=[fe,0,i,value,Best.Cost];end
end
realPop=pop;personalBest=pop;personalBestCost=fitness;seekBuffer=zeros(N*SMP,D);
initialScale=iqr(fitness);scaleFloor=max(initialScale*1e-12,realmin);
maxWindows=max(1,ceil((budget-N)/episodeFE));maxRounds=max(1,ceil((budget-N)/10));
windowLog=zeros(maxWindows,23);windowFE=zeros(maxWindows,1);windowBest=zeros(maxWindows,1);windowScale=zeros(maxWindows,1);
probeLog=zeros(maxWindows,16);probePoints=zeros(maxWindows,D);probeOldReal=zeros(maxWindows,D);probeOldPB=zeros(maxWindows,D);
probeOldV=zeros(maxWindows,D);probeAfterReal=zeros(maxWindows,D);probeAfterPB=zeros(maxWindows,D);probeAfterV=zeros(maxWindows,D);
roundLog=zeros(maxRounds,5);Q=zeros(6,2);QVisits=zeros(6,2);updateLog=zeros(maxWindows,8);
nextDecision=N;windows=0;probes=0;rounds=0;updates=0;traceFE=0;seekFE=0;lastImprovementFE=N;maxParentEvaluations=0;
pending=false;prevTrain=false;prevState=1;prevAction=1;prevBest=Best.Cost;prevScale=max(initialScale,scaleFloor);prevFE=N;
actionCounts=zeros(1,2);
while fe<budget
 rounds=rounds+1;roundBefore=fe;progress=(fe-N)/max(1,budget-N);roundQuota=min(10,budget-fe);
 center=mean(pop,1);roundBest=Best.Vector;trial=pop;trialVelocity=V;tracing=false(N,1);
 eliteCount=max(2,ceil(.20*N));[~,eliteOrder]=sort(personalBestCost);elitePool=eliteOrder(1:eliteCount);
 for i=1:N
  eliteIndex=elitePool(randi(eliteCount));eliteVector=personalBest(eliteIndex,:);
  if rand<.40
   tracing(i)=true;baseInertia=1.0;
   trialVelocity(i,:)=baseInertia*V(i,:)+2*rand(1,D).*(eliteVector-pop(i,:));
   inertia=.9-.5*progress;
   trialVelocity(i,:)=inertia*V(i,:)+trialVelocity(i,:)-baseInertia*V(i,:);
   trialVelocity(i,:)=max(-Vmax,min(Vmax,trialVelocity(i,:)));
   trial(i,:)=pop(i,:)+trialVelocity(i,:);trial(i,:)=max(lb,min(ub,trial(i,:)));
  else
   rows=(i-1)*SMP+(1:SMP);seekBuffer(rows,:)=pop(i(ones(SMP,1)),:);
   for j=2:SMP
    dims=randperm(D,seekDimCount);eliteStep=.25*(eliteVector(dims)-pop(i,dims));differenceStep=0;
    step=.05*(ub(dims)-lb(dims))/2*(1-progress);
    seekBuffer(rows(j),dims)=pop(i,dims)+eliteStep+differenceStep+step.*(2*rand(1,numel(dims))-1);
    seekBuffer(rows(j),:)=max(lb,min(ub,seekBuffer(rows(j),:)));
   end
  end
 end
 traceIds=find(tracing);seekIds=find(~tracing);pop(traceIds,:)=trial(traceIds,:);V(traceIds,:)=trialVelocity(traceIds,:);
 [targetTrace,targetSeek]=AllocateBudgetMode(roundQuota,numel(traceIds),numel(seekIds),6);
 if targetTrace>0
  db=sum((trial(traceIds,:)-Best.Vector).^2,2);dc=sum((trial(traceIds,:)-center).^2,2);
  traceCats=traceIds(SelectTracingLean(db,dc,targetTrace));
 else,traceCats=[];end
 traceCats=traceCats(randperm(numel(traceCats)));
 probeNow=false;victim=0;probeDimension=0;sigma=1-.9*progress;probePoint=[];
 if fe>=nextDecision
  phase=min(2,floor(3*progress));eta=inf;lowProgress=false;
  if fe-N>=lookback && windows>0
   startIndex=find(windowFE(1:windows)<=fe-lookback,1,'last');
   if ~isempty(startIndex)
    eta=max(0,windowBest(startIndex)-Best.Cost)/windowScale(startIndex);lowProgress=eta<threshold;
   end
  end
  candidates=seekIds(~ismember(seekIds,elitePool));varying=find(ub>lb);
  canProbe=lowProgress && targetSeek>=1 && ~isempty(candidates) && ~isempty(varying) && ...
   2*(numel(seekIds)-1)>=targetSeek-1;
  stateId=1+2*phase+double(lowProgress);allowed=1;if canProbe,allowed=[1 2];end
  if pending
   gain=max(0,prevBest-Best.Cost);reward=probeReward(gain>=threshold*prevScale,rewardScheme,...
  windowLog(windows,7)>0,windowLog(windows,19)>0);
   windowLog(windows,2)=fe;windowLog(windows,15:16)=[Best.Cost,reward];windowLog(windows,21)=populationDiversity(realPop,lb,ub);
   if strcmp(policy,'q') && prevTrain
    bootstrap=max(Q(stateId,allowed));discount=gamma^((fe-prevFE)/episodeFE);
    Q(prevState,prevAction)=Q(prevState,prevAction)+alpha*(reward+discount*bootstrap-Q(prevState,prevAction));
    QVisits(prevState,prevAction)=QVisits(prevState,prevAction)+1;updates=updates+1;
    updateLog(updates,:)=[prevState,prevAction,reward,stateId,0,prevFE,fe,numel(allowed)];
   end
  end
  action=1;
  if canProbe
   switch policy
    case 'rule',action=2;
    case 'random',action=randi(policyRng,2);
    case 'q'
     if rand(policyRng)<epsilon,action=randi(policyRng,2);
     else,winners=find(Q(stateId,:)==max(Q(stateId,:)));action=winners(randi(policyRng,numel(winners)));end
   end
  end
  probeNow=action==2;
  if probeNow
   [~,worstIndex]=max(fitness(candidates));victim=candidates(worstIndex);
   probeDimension=varying(randi(probeRng,numel(varying)));probePoint=roundBest;
   width=ub(probeDimension)-lb(probeDimension);
   raw=probePoint(probeDimension)+width*sigma*randn(probeRng);
   folded=mod(raw-lb(probeDimension),2*width);
   probePoint(probeDimension)=lb(probeDimension)+width-abs(folded-width);
   assert(all(probePoint>=lb & probePoint<=ub) && ~ismember(victim,elitePool));
  end
  windows=windows+1;windowFE(windows)=fe;windowBest(windows)=Best.Cost;
  windowScale(windows)=max(iqr(fitness),scaleFloor);
  diversity=populationDiversity(realPop,lb,ub);
  windowLog(windows,:)=[fe,fe,stateId,phase+1,eta,windowScale(windows),lowProgress,canProbe,...
   action,action,victim,probeDimension,Best.Cost,sigma,Best.Cost,0,0,0,0,diversity,diversity,fe-lastImprovementFE,0];
  prevState=stateId;prevAction=action;prevBest=Best.Cost;prevScale=windowScale(windows);prevFE=fe;
  prevTrain=canProbe;pending=true;nextDecision=min(budget,fe+episodeFE);actionCounts(action)=actionCounts(action)+1;
 end
 normalSeekIds=seekIds;if probeNow,normalSeekIds=seekIds(seekIds~=victim);end
 [seekPlan,seekCats]=ScreenSeekingFlat(seekBuffer,normalSeekIds,roundBest,center,targetSeek-double(probeNow),N,SMP);
 cats=[traceCats;seekCats];roundLocal=0;
 for k=1:numel(cats)
  i=cats(k);
  if tracing(i)
   before=fitness(i);value=f(trial(i,:));assert(isfinite(value));fe=fe+1;traceFE=traceFE+1;
   roundLocal=roundLocal+double(value<before);
   if value<fitness(i),realPop(i,:)=trial(i,:);fitness(i)=value;pop(i,:)=trial(i,:);else,pop(i,:)=realPop(i,:);end
   if value<personalBestCost(i),personalBest(i,:)=trial(i,:);personalBestCost(i)=value;end
   if value<Best.Cost,Best.Cost=value;Best.Vector=trial(i,:);lastImprovementFE=fe;end
   T(fe)=Best.Cost;
   if audit,evalPoints(fe,:)=trial(i,:);evalLog(fe,:)=[fe,1,i,value,Best.Cost];end
  else
   selected=seekPlan{i};localCost=fitness(i);parentCost=fitness(i);localVector=pop(i,:);wasVirtual=any(pop(i,:)~=realPop(i,:));
   maxParentEvaluations=max(maxParentEvaluations,numel(selected));
   for q=1:numel(selected)
    row=selected(q);value=f(seekBuffer(row,:));assert(isfinite(value));fe=fe+1;seekFE=seekFE+1;
    roundLocal=roundLocal+double(value<localCost);
    if value<personalBestCost(i),personalBest(i,:)=seekBuffer(row,:);personalBestCost(i)=value;end
    if value<localCost,localCost=value;localVector=seekBuffer(row,:);end
    if value<Best.Cost,Best.Cost=value;Best.Vector=seekBuffer(row,:);lastImprovementFE=fe;end
    T(fe)=Best.Cost;
    if audit,evalPoints(fe,:)=seekBuffer(row,:);evalLog(fe,:)=[fe,2,i,value,Best.Cost];end
   end
   pop(i,:)=localVector;
   if localCost<parentCost,realPop(i,:)=localVector;elseif wasVirtual && ~isempty(selected),pop(i,:)=realPop(i,:);end
   fitness(i)=localCost;
  end
 end
 if probeNow
  probes=probes+1;before=fitness(victim);oldPB=personalBestCost(victim);beforeBest=Best.Cost;
  probePoints(probes,:)=probePoint;probeOldReal(probes,:)=realPop(victim,:);probeOldPB(probes,:)=personalBest(victim,:);probeOldV(probes,:)=V(victim,:);
  value=f(probePoint);assert(isfinite(value));fe=fe+1;seekFE=seekFE+1;
  parentSuccess=value<before;globalSuccess=value<beforeBest;writeBack=strcmp(acceptance,'replace') || parentSuccess;
  if strcmp(acceptance,'replace')
   pop(victim,:)=probePoint;realPop(victim,:)=probePoint;fitness(victim)=value;
   personalBest(victim,:)=probePoint;personalBestCost(victim)=value;V(victim,:)=0;
  elseif parentSuccess
   pop(victim,:)=probePoint;realPop(victim,:)=probePoint;fitness(victim)=value;
   if value<personalBestCost(victim),personalBest(victim,:)=probePoint;personalBestCost(victim)=value;end
  else,pop(victim,:)=realPop(victim,:);end
  if globalSuccess,Best.Cost=value;Best.Vector=probePoint;lastImprovementFE=fe;end
  T(fe)=Best.Cost;
  if audit,evalPoints(fe,:)=probePoint;evalLog(fe,:)=[fe,3,victim,value,Best.Cost];end
  probeAfterReal(probes,:)=realPop(victim,:);probeAfterPB(probes,:)=personalBest(victim,:);probeAfterV(probes,:)=V(victim,:);
  probeLog(probes,:)=[fe,windows,victim,probeDimension,sigma,before,value,beforeBest,Best.Cost,parentSuccess,globalSuccess,...
   writeBack,oldPB,personalBestCost(victim),fitness(victim),sum(V(victim,:).^2)];
  maxParentEvaluations=max(maxParentEvaluations,1);
  if writeBack
   assert(isequal(realPop(victim,:),probePoint) && fitness(victim)==value);
   if strcmp(acceptance,'replace'),assert(isequal(personalBest(victim,:),probePoint) && personalBestCost(victim)==value && all(V(victim,:)==0));end
  end
 end
 assert(fe-roundBefore==roundQuota && fe<=budget);
 roundLog(rounds,:)=[roundBefore,fe,targetTrace,targetSeek,double(probeNow)];
 windowLog(windows,2)=fe;windowLog(windows,17:19)=windowLog(windows,17:19)+[targetTrace,targetSeek,double(probeNow)];
 windowLog(windows,23)=windowLog(windows,23)+roundLocal;
end
if pending
 gain=max(0,prevBest-Best.Cost);reward=probeReward(gain>=threshold*prevScale,rewardScheme,...
  windowLog(windows,7)>0,windowLog(windows,19)>0);
 windowLog(windows,15:16)=[Best.Cost,reward];windowLog(windows,21)=populationDiversity(realPop,lb,ub);
 if strcmp(policy,'q') && prevTrain
  Q(prevState,prevAction)=Q(prevState,prevAction)+alpha*(reward-Q(prevState,prevAction));
  QVisits(prevState,prevAction)=QVisits(prevState,prevAction)+1;updates=updates+1;
  updateLog(updates,:)=[prevState,prevAction,reward,0,1,prevFE,fe,0];
 end
end
assert(fe==budget && numel(T)==budget && all(isfinite(T)) && all(diff(T)<=0));
info=struct('Algorithm',['Fixed6-EliteProbe-' policy '-' acceptance],'Evaluations',fe,'Seed',seed,...
 'SeekingEvaluations',seekFE,'TracingEvaluations',traceFE,'ProbeEvaluations',probes,...
 'ProbeParentSuccesses',sum(probeLog(1:probes,10)),'ProbeGlobalSuccesses',sum(probeLog(1:probes,11)),...
 'ProbeWritebacks',sum(probeLog(1:probes,12)),'Policy',policy,'Acceptance',acceptance,...
 'PolicySeed',policySeed,'ProbeSeed',probeSeed,'ProgressWindowFE',lookback,'ProgressThreshold',threshold,...
 'EpisodeFE',episodeFE,'MaxParentEvaluations',maxParentEvaluations,'Rounds',rounds,'ActionCounts',actionCounts,...
 'QTable',Q,'QVisits',QVisits,'QUpdates',updates,'UpdateLog',updateLog(1:updates,:),...
 'WindowLog',windowLog(1:windows,:),'ProbeLog',probeLog(1:probes,:),...
 'ProbePoints',probePoints(1:probes,:),'ProbeOldReal',probeOldReal(1:probes,:),...
 'ProbeOldPersonalBest',probeOldPB(1:probes,:),'ProbeOldVelocity',probeOldV(1:probes,:),...
 'ProbeAfterReal',probeAfterReal(1:probes,:),'ProbeAfterPersonalBest',probeAfterPB(1:probes,:),...
 'ProbeAfterVelocity',probeAfterV(1:probes,:),'RoundLog',roundLog(1:rounds,:),...
 'RealPopulation',realPop,'VirtualPopulation',pop,'Fitness',fitness,...
 'PersonalBest',personalBest,'PersonalBestCost',personalBestCost,'Velocity',V,...
 'EvaluationPoints',evalPoints,'EvaluationLog',evalLog);
info.RewardScheme=rewardScheme;
info.WindowColumns={'StartFE','EndFE','State','Phase','ProgressRatio','ProgressScale','LowProgress','ProbeFeasible',...
 'RequestedAction','ExecutedAction','ProbeParent','ProbeDimension','BestBefore','Sigma','BestAfter','Reward',...
 'TracingFE','SeekingFE','ProbeFE','RealDiversityBefore','RealDiversityAfter','StrictStallFE','NormalParentImprovements'};
info.ProbeColumns={'FE','Window','Parent','Dimension','Sigma','ParentCostBefore','CandidateCost','BestBefore','BestAfter',...
 'ParentSuccess','GlobalSuccess','Writeback','PersonalBestCostBefore','PersonalBestCostAfter','RealFitnessAfter','VelocityNormSquaredAfter'};
end

function value=fieldOr(state,name,default)
if isfield(state,name),value=state.(name);else,value=default;end
end

function [nTrace,nSeek]=AllocateBudgetMode(quota,traceCount,seekCount,traceQuota)
% Four tracing and six seeking slots for full rounds, with tail fallback.
targetTrace=min(traceQuota, max(1, quota-1));
nTrace=min(traceCount,targetTrace);
nSeek=min(2*seekCount,quota-nTrace);
leftover=quota-nTrace-nSeek;
extraTrace=min(leftover,traceCount-nTrace); nTrace=nTrace+extraTrace;
leftover=leftover-extraTrace;
extraSeek=min(leftover,2*seekCount-nSeek); nSeek=nSeek+extraSeek;
end

function cats=SelectTracingLean(distBest,distCenter,count)
[~,near]=sort(distBest); [~,far]=sort(distCenter,'descend');
raw=[near(1:ceil(count/2));far(1:floor(count/2))]; cats=zeros(count,1); n=0;
for k=1:numel(raw)
    if ~any(cats(1:n)==raw(k)), n=n+1; cats(n)=raw(k); end
end
if n<count
    for k=1:numel(distBest)
        if ~any(cats(1:n)==k), n=n+1; cats(n)=k; if n==count, break, end, end
    end
end
end

function [plan,seekCats]=ScreenSeekingFlat(pool,catIds,best,center,quota,N,SMP)
plan=cell(N,1);
seekCats=zeros(0,1);
if quota==0,return,end
nCats=numel(catIds); perCat=SMP-1; total=nCats*perCat; rows=zeros(total,1); parents=zeros(total,1); row=0;
for q=1:nCats
    block=(catIds(q)-1)*SMP+(2:SMP);
    ix=row+(1:perCat); rows(ix)=block; parents(ix)=catIds(q); row=row+perCat;
end
points=pool(rows,:);
[~,near]=sort(sum((points-best).^2,2));
[~,far]=sort(sum((points-center).^2,2),'descend');
selected=false(total,1); selectedCount=0; counts=zeros(N,1); chosen=zeros(N,2);
nearTarget=ceil(quota/2);
for phase=1:2
    if phase==1
        order=near; target=nearTarget;
    else
        order=far; target=quota;
    end
    if selectedCount>=target,continue,end
    for q=1:total
        index=order(q); parent=parents(index);
        if ~selected(index) && counts(parent)<2
            selected(index)=true; selectedCount=selectedCount+1;
            counts(parent)=counts(parent)+1;
            chosen(parent,counts(parent))=rows(index);
        end
        if selectedCount>=target,break,end
    end
end
seekCats=find(counts>0);
for q=seekCats'
    plan{q}=chosen(q,1:counts(q));
end
end

function value=populationDiversity(points,lb,ub)
center=mean(points,1);scale=max(ub-lb,eps);value=sqrt(mean(((points-center)./scale).^2,'all'));
end


function reward=probeReward(improved,scheme,lowProgress,probeExecuted)
if strcmp(scheme,'legacy')
 reward=2*double(improved)-1;
elseif improved
 reward=10;
elseif lowProgress && probeExecuted
 reward=.5;
else
 reward=-1;
end
end
