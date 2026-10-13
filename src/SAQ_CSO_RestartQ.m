function [Best,T,info]=SAQ_CSO_RestartQ(f,state,~,N,seed)
% SAQ_CSO_RestartQ: sparse CSO with state-gated protected partial restart.
% The baseline sparse search and geometric candidate screen are retained.
% OP is one composite candidate formula; Q only chooses normal vs OP.
%
% State: 3 search phases x {healthy, stalled-high-diversity, stalled-low-diversity}
% Action 1: normal sparse search. Action 2: restart for the next 100 true FE.
% state.policy: 'base', 'fixed', or 'q'.

started=tic; pop=state.initialPopulation; D=size(pop,2);
lb=state.lowerBound; ub=state.upperBound; budget=state.maxEvaluations; policy='q';
if isfield(state,'policy'), policy=char(state.policy); end
assert(ismember(policy,{'base','fixed','random','q'})); assert(N==50 && size(pop,1)==N);
assert(D>=1 && budget>=N && budget==floor(budget));
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all')); rng(seed,'twister');

alpha=.1; gamma=.9; epsilon=.1; episodeFE=100; stagnationThreshold=1000; diversityThreshold=.08; restartCooldown=5000;
if isfield(state,'alpha'),alpha=state.alpha;end
if isfield(state,'gamma'),gamma=state.gamma;end
if isfield(state,'epsilon'),epsilon=state.epsilon;end
if isfield(state,'episodeFE'),episodeFE=state.episodeFE;end
if isfield(state,'stagnationThreshold'),stagnationThreshold=state.stagnationThreshold;end
if isfield(state,'diversityThreshold'),diversityThreshold=state.diversityThreshold;end
if isfield(state,'restartCooldown'),restartCooldown=state.restartCooldown;end
SMP=5; seekDimCount=max(1,round(.20*D)); V=.01*(2*rand(N,D)-1).*(ub-lb); Vmax=.2*(ub-lb);
T=nan(budget,1); fitness=zeros(N,1); Best=struct('Cost',inf,'Vector',pop(1,:)); fe=0;
for i=1:N
 fitness(i)=f(pop(i,:)); if fitness(i)<Best.Cost,Best.Cost=fitness(i);Best.Vector=pop(i,:);end; T(i)=Best.Cost;
end
fe=N; realPop=pop; personalBest=pop; personalBestCost=fitness; seekBuffer=zeros(N*SMP,D);
Q=zeros(9,2); QVisits=zeros(9,2); actionCounts=zeros(1,2); decisionCount=0; qUpdates=0;
nextDecisionFE=N; pending=false; previousState=1; previousAction=1; previousBest=Best.Cost;
restartActive=false; lastImprovementFE=N; lastRestartFE=-inf; rounds=0; seekFE=0; traceFE=0; restartFE=0; restartSuccess=0;
restartWindows=0; parentCoverage=0; restartCandidateDistance=0; restartCandidateCount=0; decisionLog=zeros(ceil((budget-N)/episodeFE)+2,12);
windowRestartSuccess=0; windowRestartGain=0; windowRestartCount=0; restartParentSuccess=0;

while fe<budget
 rounds=rounds+1; roundBefore=fe; progress=(fe-N)/max(1,budget-N); quota=min(10,budget-fe);
 if fe>=nextDecisionFE
   currentState=stateIndex(progress,fe-lastImprovementFE,populationDiversity(realPop,lb,ub),stagnationThreshold,diversityThreshold);
   if pending
     globalReward=max(0,previousBest-Best.Cost)/max(abs(previousBest),eps);
     localReward=windowRestartGain/max(1,windowRestartCount);
     if previousAction==2, reward=.5*globalReward+.5*min(1,localReward); else, reward=globalReward; end
     if reward==0, reward=-.1; end
     nextValue=max(Q(currentState,:));
     Q(previousState,previousAction)=Q(previousState,previousAction)+alpha*(reward+gamma*nextValue-Q(previousState,previousAction));
     QVisits(previousState,previousAction)=QVisits(previousState,previousAction)+1; qUpdates=qUpdates+1;
   end
   canRestart=(fe-lastImprovementFE>=stagnationThreshold) && ...
       (populationDiversity(realPop,lb,ub)<diversityThreshold) && ...
       (fe-lastRestartFE>=restartCooldown);
   if strcmp(policy,'base'), action=1;
   elseif strcmp(policy,'fixed'), action=1+double(canRestart);
   elseif strcmp(policy,'random'), if canRestart, action=randi(2); else, action=1; end
   elseif rand<epsilon, action=randi(2);
   else, winners=find(Q(currentState,:)==max(Q(currentState,:))); action=winners(randi(numel(winners))); end
   if ~canRestart, action=1; end
   previousState=currentState; previousAction=action; previousBest=Best.Cost; pending=true;
   windowRestartSuccess=0; windowRestartGain=0; windowRestartCount=0;
   restartActive=action==2; restartWindows=restartWindows+double(restartActive);
   if restartActive, lastRestartFE=fe; end
   decisionCount=decisionCount+1; decisionLog(decisionCount,:)=[fe,currentState,action,Best.Cost,fe-lastImprovementFE,populationDiversity(realPop,lb,ub),restartActive,0,0,0,0,0];
   nextDecisionFE=min(budget,fe+episodeFE); actionCounts(action)=actionCounts(action)+1;
 end
 center=mean(pop,1); roundBest=Best.Vector; trial=pop; trialV=V; tracing=false(N,1);
 eliteCount=max(2,ceil(.20*N)); [~,eliteOrder]=sort(personalBestCost); elitePool=eliteOrder(1:eliteCount);
 for i=1:N
   elite=personalBest(elitePool(randi(eliteCount)),:);
   if rand<.40
     tracing(i)=true; base=V(i,:)+2*rand(1,D).*(elite-pop(i,:)); inertia=.9-.5*progress;
     trialV(i,:)=inertia*V(i,:)+base-V(i,:); trialV(i,:)=max(-Vmax,min(Vmax,trialV(i,:)));
     trial(i,:)=max(lb,min(ub,pop(i,:)+trialV(i,:)));
   else
     rows=(i-1)*SMP+(1:SMP); seekBuffer(rows,:)=pop(i(ones(SMP,1)),:);
     for j=2:SMP
       dims=randperm(D,seekDimCount); step=.05*(ub(dims)-lb(dims))/2*(1-progress);
       seekBuffer(rows(j),dims)=pop(i,dims)+.25*(elite(dims)-pop(i,dims))+step.*(2*rand(1,numel(dims))-1);
       seekBuffer(rows(j),:)=max(lb,min(ub,seekBuffer(rows(j),:)));
     end
   end
 end
 traceIds=find(tracing); seekIds=find(~tracing); pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialV(traceIds,:);
 [targetTrace,targetSeek]=allocateQuota(quota,numel(traceIds),numel(seekIds),6);
 if targetTrace>0
   traceBest=sum((trial(traceIds,:)-Best.Vector).^2,2); traceCenter=sum((trial(traceIds,:)-center).^2,2);
   traceCats=traceIds(selectTracing(traceBest,traceCenter,targetTrace)); traceCats=traceCats(randperm(numel(traceCats)));
 else, traceCats=zeros(0,1); end
 if restartActive && targetSeek>0 && ~isempty(seekIds)
   [seekBuffer,seekPlan,seekCats,restartRows]=makeRestartPlan(seekBuffer,seekIds,fitness,realPop,lb,ub,targetSeek,N,SMP,progress);
   if ~isempty(restartRows)
     restartParents=floor((restartRows-1)/SMP)+1;
     restartCandidateDistance=restartCandidateDistance+sum(sqrt(sum((seekBuffer(restartRows,:)-realPop(restartParents,:)).^2,2)));
     restartCandidateCount=restartCandidateCount+numel(restartRows);
   end
 else
   [seekPlan,seekCats]=screenGeometry(seekBuffer,seekIds,roundBest,center,targetSeek,N,SMP); restartRows=[];
 end
 cats=[traceCats;seekCats];
 for k=1:numel(cats)
   i=cats(k);
   if tracing(i)
     before=fitness(i); value=f(trial(i,:)); fe=fe+1; traceFE=traceFE+1;
     if value<fitness(i),realPop(i,:)=trial(i,:);fitness(i)=value;pop(i,:)=trial(i,:);end
     if value<personalBestCost(i),personalBest(i,:)=trial(i,:);personalBestCost(i)=value;end
     if value<Best.Cost,Best.Cost=value;Best.Vector=trial(i,:);lastImprovementFE=fe;end; T(fe)=Best.Cost;
     if value>=before && any(pop(i,:)~=realPop(i,:)),pop(i,:)=realPop(i,:);end
   else
     selected=seekPlan{i}; localCost=fitness(i); parentCost=fitness(i); localVector=pop(i,:); wasVirtual=any(pop(i,:)~=realPop(i,:));
     parentCoverage=parentCoverage+double(~isempty(selected));
     for q=1:numel(selected)
       row=selected(q); beforeLocal=localCost; value=f(seekBuffer(row,:)); fe=fe+1; seekFE=seekFE+1; isRestart=ismember(row,restartRows); restartFE=restartFE+double(isRestart); windowRestartCount=windowRestartCount+double(isRestart);
       if value<localCost
         localCost=value;localVector=seekBuffer(row,:);
         if isRestart,windowRestartSuccess=windowRestartSuccess+1;restartParentSuccess=restartParentSuccess+1;windowRestartGain=windowRestartGain+max(0,beforeLocal-value)/max(abs(beforeLocal),eps);end
       end
       if value<personalBestCost(i),personalBest(i,:)=seekBuffer(row,:);personalBestCost(i)=value;end
       if value<Best.Cost,Best.Cost=value;Best.Vector=seekBuffer(row,:);lastImprovementFE=fe;restartSuccess=restartSuccess+double(ismember(row,restartRows));end
       T(fe)=Best.Cost;
     end
     pop(i,:)=localVector;
     if localCost<parentCost,realPop(i,:)=localVector;fitness(i)=localCost;
     elseif wasVirtual && ~isempty(selected),pop(i,:)=realPop(i,:);end
   end
 end
 if decisionCount>0
   decisionLog(decisionCount,8)=decisionLog(decisionCount,8)+targetTrace; decisionLog(decisionCount,9)=decisionLog(decisionCount,9)+targetSeek;
   decisionLog(decisionCount,10)=fe; decisionLog(decisionCount,11)=lastImprovementFE; decisionLog(decisionCount,12)=restartSuccess;
 end
end
if pending
 reward=max(0,previousBest-Best.Cost)/max(abs(previousBest),eps);if reward==0,reward=-.1;end
 globalReward=max(0,previousBest-Best.Cost)/max(abs(previousBest),eps);localReward=windowRestartGain/max(1,windowRestartCount);if previousAction==2,reward=.5*globalReward+.5*min(1,localReward);else,reward=globalReward;end;if reward==0,reward=-.1;end
 Q(previousState,previousAction)=Q(previousState,previousAction)+alpha*(reward-Q(previousState,previousAction));QVisits(previousState,previousAction)=QVisits(previousState,previousAction)+1;qUpdates=qUpdates+1;
end
T=T(1:fe);
info=struct('Algorithm',['SAQ-CSO-RestartQ-' policy],'Seed',seed,'Evaluations',fe,'Seconds',toc(started),...
 'SeekingEvaluations',seekFE,'TracingEvaluations',traceFE,'RestartEvaluations',restartFE,'RestartSuccesses',restartSuccess,...
 'RestartWindows',restartWindows,'RestartParentSuccesses',restartParentSuccess,'MeanRestartCandidateDistance',restartCandidateDistance/max(1,restartCandidateCount),'RestartCandidateCount',restartCandidateCount,'MeanParentCoverage',parentCoverage/max(1,rounds),'QTable',Q,'QVisits',QVisits,...
 'QUpdates',qUpdates,'ActionCounts',actionCounts,'DecisionLog',decisionLog(1:decisionCount,:),...
 'Alpha',alpha,'Gamma',gamma,'Epsilon',epsilon,'StagnationThreshold',stagnationThreshold,'DiversityThreshold',diversityThreshold,'RestartCooldown',restartCooldown);
end

function idx=stateIndex(progress,stagnation,diversity,threshold,divThreshold)
phase=min(2,floor(3*progress)); if stagnation<threshold,status=0;elseif diversity<divThreshold,status=2;else,status=1;end; idx=1+3*phase+status;
end
function [nTrace,nSeek]=allocateQuota(quota,nTraceCats,nSeekCats,traceQuota)
if nTraceCats==0,nTrace=0;nSeek=min(2*nSeekCats,quota);return;end;if nSeekCats==0,nSeek=0;nTrace=min(nTraceCats,quota);return;end
nTrace=min(nTraceCats,min(traceQuota,max(1,quota-1)));nSeek=min(2*nSeekCats,quota-nTrace);left=quota-nTrace-nSeek;nTrace=nTrace+min(left,nTraceCats-nTrace);left=quota-nTrace-nSeek;nSeek=nSeek+min(left,2*nSeekCats-nSeek);
end
function cats=selectTracing(db,dc,count)
[~,a]=sort(db);[~,b]=sort(dc,'descend');raw=[a(1:ceil(count/2));b(1:floor(count/2))];cats=zeros(count,1);n=0;
for k=1:numel(raw),if ~any(cats(1:n)==raw(k)),n=n+1;cats(n)=raw(k);end;end
for k=1:numel(db),if n==count,break;end;if ~any(cats(1:n)==k),n=n+1;cats(n)=k;end;end
end
function [pool,plan,cats,restartRows]=makeRestartPlan(pool,ids,fitness,realPop,lb,ub,quota,N,SMP,progress)
plan=cell(N,1);cats=zeros(0,1);restartRows=zeros(0,1);[~,ord]=sort(fitness(ids),'descend');candidateCount=min(ceil(.20*N),numel(ord));candidateParents=ids(ord(1:candidateCount));take=min(quota,numel(candidateParents));selected=candidateParents(1:take);counts=zeros(N,1);
for q=1:numel(selected)
 i=selected(q);row=(i-1)*SMP+2;x=lb+rand(1,size(realPop,2)).*(ub-lb);pool(row,:)=x;plan{i}=row;cats(end+1,1)=i;restartRows(end+1,1)=row;counts(i)=1;
end
if take<quota
 for q=1:numel(candidateParents)
  i=candidateParents(q);if counts(i)>=2,continue;end
  row=(i-1)*SMP+3;x=lb+rand(1,size(realPop,2)).*(ub-lb);pool(row,:)=x;plan{i}=[plan{i},row];restartRows(end+1,1)=row;counts(i)=2;
  if numel(restartRows)==quota,break;end
 end
end
end
function [plan,cats]=screenGeometry(pool,ids,best,center,quota,N,SMP)
plan=cell(N,1);cats=zeros(0,1);if quota==0,return;end;K=SMP-1;total=numel(ids)*K;rows=zeros(total,1);parents=zeros(total,1);cursor=0;
for q=1:numel(ids),i=ids(q);ix=cursor+(1:K);rows(ix)=(i-1)*SMP+(2:SMP);parents(ix)=i;cursor=cursor+K;end
pts=pool(rows,:);[~,near]=sort(sum((pts-best).^2,2));[~,far]=sort(sum((pts-center).^2,2),'descend');sel=false(total,1);cnt=zeros(N,1);chosen=zeros(N,2);n=0;nearTarget=ceil(quota/2);
for phase=1:2
 if phase==1,order=near;target=nearTarget;else,order=far;target=quota;end
 for q=1:numel(order)
  j=order(q);i=parents(j);if ~sel(j)&&cnt(i)<2,n=n+1;sel(j)=true;cnt(i)=cnt(i)+1;chosen(i,cnt(i))=rows(j);end;if n>=target,break;end
 end
end
cats=find(cnt>0);
for k=1:numel(cats)
 i=cats(k); plan{i}=chosen(i,1:cnt(i));
end
end
function value=populationDiversity(points,lb,ub),c=mean(points,1);s=max(ub-lb,eps);value=sqrt(mean(((points-c)./s).^2,'all'));end

