function [Best,T,info]=ASE_CSO_ReservedEval(f,state,~,N,seed)
% One real Seeking credit: keep the verified batch plan or explore a fresh parent.
% reservePolicy: keep/explore/random/progress/reverse/q. Six-state two-action Q.
started=tic;pop=state.initialPopulation;D=size(pop,2);lb=state.lowerBound;ub=state.upperBound;budget=state.maxEvaluations;
policy='q';if isfield(state,'reservePolicy'),policy=char(state.reservePolicy);end
assert(ismember(policy,{'keep','explore','random','progress','reverse','q'}));assert(N==50 && size(pop,1)==N && budget>=N && budget==floor(budget));assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
alpha=.1;gamma=.9;epsilon=.1;bonus=10;
if isfield(state,'alpha'),alpha=state.alpha;end;if isfield(state,'gamma'),gamma=state.gamma;end;if isfield(state,'epsilon'),epsilon=state.epsilon;end;if isfield(state,'rewardBonus'),bonus=state.rewardBonus;end
assert(alpha>0 && alpha<=1 && gamma>=0 && gamma<=1 && epsilon>=0 && epsilon<=1 && bonus>0);
audit=isfield(state,'auditDecisions') && state.auditDecisions;rng(seed,'twister');
SMP=5;seekDimCount=max(1,round(.20*D));V=.01*(2*rand(N,D)-1).*(ub-lb);Vmax=.2*(ub-lb);
T=nan(budget,1);fitness=zeros(N,1);Best=struct('Cost',inf,'Vector',pop(1,:));fe=0;
for i=1:N,fitness(i)=f(pop(i,:));if fitness(i)<Best.Cost,Best.Cost=fitness(i);Best.Vector=pop(i,:);end;T(i)=Best.Cost;end
fe=N;realPop=pop;personalBest=pop;personalBestCost=fitness;seekBuffer=zeros(N*SMP,D);
streamSeed=mod(double(seed)+2000003,2^32-1);policyStream=RandStream('mt19937ar','Seed',streamSeed);
Q=zeros(6,2);visits=zeros(6,1);pending=false;pendingState=0;pendingAction=0;pendingReward=0;pendingFE=0;pendingDecision=0;
rounds=0;seekEvalTotal=0;traceEvalTotal=0;traceSuccess=0;traceRollbacks=0;actions=zeros(1,2);forced=0;decisions=0;freeDecisions=0;qUpdates=0;globalHits=0;gainSum=0;coverage=0;plannedCoverage=0;maxParent=0;
localCost=[];localVector=[];mask=[];counts=[];updates=zeros(0,9);decisionLog=zeros(0,20);points=zeros(0,D);
if audit,maxRows=max(1,ceil((budget-N)/10));updates=zeros(maxRows,9);decisionLog=zeros(maxRows,20);points=zeros(maxRows,D);end
while fe<budget
    rounds=rounds+1; roundStart=fe; progress=(fe-N)/max(1,budget-N); quota=min(10,budget-fe);
    center=mean(pop,1); roundBest=Best.Vector; trial=pop; trialVelocity=V; tracing=false(N,1);
    eliteCount=max(2,ceil(.20*N)); [~,eliteOrder]=sort(personalBestCost); elitePool=eliteOrder(1:eliteCount);
    for i=1:N
        eliteVector=personalBest(elitePool(randi(eliteCount)),:);
        if rand<.40
            tracing(i)=true;
            baseVelocity=V(i,:)+2*rand(1,D).*(eliteVector-pop(i,:));
            inertia=.9-.5*progress;
            trialVelocity(i,:)=inertia*V(i,:)+baseVelocity-V(i,:);
            trialVelocity(i,:)=max(-Vmax,min(Vmax,trialVelocity(i,:)));
            trial(i,:)=max(lb,min(ub,pop(i,:)+trialVelocity(i,:)));
        else
            rows=(i-1)*SMP+(1:SMP); seekBuffer(rows,:)=pop(i(ones(SMP,1)),:);
            for j=2:SMP
                dims=randperm(D,seekDimCount);
                eliteStep=.25*(eliteVector(dims)-pop(i,dims));
                step=.05*(ub(dims)-lb(dims))/2*(1-progress);
                seekBuffer(rows(j),dims)=pop(i,dims)+eliteStep+step.*(2*rand(1,numel(dims))-1);
                seekBuffer(rows(j),:)=max(lb,min(ub,seekBuffer(rows(j),:)));
            end
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing);
    pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialVelocity(traceIds,:);
    [targetTrace,targetSeek]=AllocateFCSBudget(quota,numel(traceIds),numel(seekIds));
    traceCats=chooseRandom(traceIds,targetTrace);
    for k=1:numel(traceCats)
        i=traceCats(k); anchorCost=fitness(i); value=f(trial(i,:)); fe=fe+1; traceEvalTotal=traceEvalTotal+1;
        if value<anchorCost
            realPop(i,:)=trial(i,:); fitness(i)=value; pop(i,:)=trial(i,:); traceSuccess=traceSuccess+1;
        else
            pop(i,:)=realPop(i,:); traceRollbacks=traceRollbacks+1;
        end
        if value<personalBestCost(i), personalBest(i,:)=trial(i,:); personalBestCost(i)=value; end
        if value<Best.Cost, Best.Cost=value; Best.Vector=trial(i,:); end
        T(fe)=Best.Cost;
    end

    if targetSeek>0 && ~isempty(seekIds)
        [orderedRows,orderedParents]=orderedCandidates(seekBuffer,seekIds,roundBest,center,SMP);
        [rows,parents]=batchPlan(orderedRows,orderedParents,targetSeek,N);plannedCoverage=plannedCoverage+numel(unique(parents));
        localCost=fitness;localVector=pop;anchorPop=realPop;wasVirtual=any(pop~=realPop,2);mask=false(N,1);counts=zeros(N,1);
        seekStartFE=fe;prefixStartBest=Best.Cost;prefixCount=targetSeek-1;
        for j=1:prefixCount,evaluateCandidate(rows(j),parents(j));end
        prefixImproved=(Best.Cost<prefixStartBest);fresh=seekIds(~mask(seekIds));canExplore=~isempty(fresh);
        phase=min(2,floor(3*((fe-N)/max(1,budget-N))));s=1+2*phase+double(~prefixImproved);decisions=decisions+1;
        if strcmp(policy,'q') && pending,settle(s,canExplore,false);end
        if ~canExplore,a=1;forced=forced+1;
        else
            freeDecisions=freeDecisions+1;
            switch policy
                case 'keep',a=1;
                case 'explore',a=2;
                case 'random',a=randi(policyStream,2);
                case 'progress',a=1+double(~prefixImproved);
                case 'reverse',a=1+double(prefixImproved);
                case 'q'
                    visits(s)=visits(s)+1;
                    if rand(policyStream)<epsilon,a=randi(policyStream,2);
                    else,qs=Q(s,:);ties=find(qs==max(qs));a=ties(randi(policyStream,numel(ties)));end
            end
        end
        plannedRow=rows(end);plannedParent=parents(end);row=plannedRow;parent=plannedParent;
        if a==2
            parent=fresh(randi(policyStream,numel(fresh)));choices=(parent-1)*SMP+(2:SMP);choices(choices==plannedRow)=[];row=choices(randi(policyStream,numel(choices)));
        end
        wasUncovered=~mask(parent);countBefore=counts(parent);before=Best.Cost;actions(a)=actions(a)+1;evaluateCandidate(row,parent);
        gain=max(0,before-Best.Cost);hit=(gain>0);reward=bonus*double(hit)-double(~hit);globalHits=globalHits+hit;gainSum=gainSum+gain;
        if strcmp(policy,'q') && canExplore,pending=true;pendingState=s;pendingAction=a;pendingReward=reward;pendingFE=fe;pendingDecision=decisions;end
        if audit
            decisionLog(decisions,:)=[rounds s prefixImproved prefixCount plannedRow plannedParent a row parent wasUncovered ~canExplore fe before Best.Cost gain reward canExplore seekStartFE prefixStartBest countBefore];points(decisions,:)=seekBuffer(row,:);
        end
        for j=find(mask)'
            if localCost(j)<fitness(j),fitness(j)=localCost(j);realPop(j,:)=localVector(j,:);pop(j,:)=localVector(j,:);
            elseif wasVirtual(j),pop(j,:)=anchorPop(j,:);end
        end
        coverage=coverage+nnz(mask);maxParent=max(maxParent,max(counts));assert(all(counts<=2));
    end
    assert(fe-roundStart==quota,'Reserved:Quota','Round FE not filled.');
end
if strcmp(policy,'q') && pending,settle(0,false,true);end
if audit,updates=updates(1:qUpdates,:);decisionLog=decisionLog(1:decisions,:);points=points(1:decisions,:);end
assert(fe==budget && all(isfinite(T)) && all(diff(T)<=0));
info=struct('Algorithm','ASE-CSO-ReservedEval','Seed',seed,'InitialCost',T(N),'Policy',policy,'Evaluations',fe,'Rounds',rounds,'TracingEvaluations',traceEvalTotal,'SeekingEvaluations',seekEvalTotal,...
 'ActionCounts',actions,'Decisions',decisions,'FreeDecisions',freeDecisions,'ForcedKeep',forced,'QTable',Q,'QVisits',visits,'QUpdates',qUpdates,'PendingAtEnd',pending,...
 'GlobalLastSuccesses',globalHits,'GlobalLastGain',gainSum,'MeanParentCoverage',coverage/max(1,rounds),'MeanPlannedCoverage',plannedCoverage/max(1,rounds),'ActualMaxParentEvaluations',maxParent,...
 'Alpha',alpha,'Gamma',gamma,'Epsilon',epsilon,'RewardBonus',bonus,'PolicySeed',streamSeed,'Seconds',toc(started),...
 'DecisionColumns',{{'Round','State','PrefixImproved','PrefixCount','PlannedRow','PlannedParent','Action','SelectedRow','SelectedParent','WasUncovered','Forced','LastFE','BestBefore','BestAfter','GlobalGain','Reward','CanExplore','SeekStartFE','PrefixStartBest','ParentCountBefore'}},...
 'DecisionLog',decisionLog,'DecisionPoints',points,'UpdateColumns',{{'State','Action','Reward','NextState','Terminal','UpdateFE','PreviousLastFE','CanExploreNext','PreviousDecision'}},'UpdateLog',updates);
    function evaluateCandidate(row,parent)
        value=f(seekBuffer(row,:));assert(isscalar(value) && isfinite(value));fe=fe+1;seekEvalTotal=seekEvalTotal+1;mask(parent)=true;counts(parent)=counts(parent)+1;
        if value<personalBestCost(parent),personalBest(parent,:)=seekBuffer(row,:);personalBestCost(parent)=value;end
        if value<localCost(parent),localCost(parent)=value;localVector(parent,:)=seekBuffer(row,:);end
        if value<Best.Cost,Best.Cost=value;Best.Vector=seekBuffer(row,:);end
        T(fe)=Best.Cost;
    end
    function settle(nextState,available,terminal)
        [Q,~]=fcs.updateCredit(Q,pendingState,pendingAction,pendingReward,nextState,[true available],gamma,alpha,terminal);qUpdates=qUpdates+1;
        if audit,updates(qUpdates,:)=[pendingState pendingAction pendingReward nextState terminal fe pendingFE available pendingDecision];end
        pending=false;
    end
end

function chosen=chooseRandom(ids,count)
if count==0 || isempty(ids), chosen=zeros(0,1); else, chosen=ids(randperm(numel(ids),min(count,numel(ids)))); end
end

function [nTrace,nSeek]=AllocateFCSBudget(quota,traceCount,seekCount)
if traceCount==0, nTrace=0; nSeek=min(2*seekCount,quota); return; end
if seekCount==0, nSeek=0; nTrace=min(traceCount,quota); return; end
nTrace=min(traceCount,min(4,max(1,quota-1))); nSeek=min(2*seekCount,quota-nTrace);
left=quota-nTrace-nSeek; extraTrace=min(left,traceCount-nTrace); nTrace=nTrace+extraTrace; left=left-extraTrace;
extraSeek=min(left,2*seekCount-nSeek); nSeek=nSeek+extraSeek;
end

function [rows,parents]=orderedCandidates(pool,catIds,best,center,SMP)
K=SMP-1; total=numel(catIds)*K; rows=zeros(total,1); parents=zeros(total,1); cursor=0;
for q=1:numel(catIds)
    i=catIds(q); span=cursor+(1:K); rows(span)=(i-1)*SMP+(2:SMP); parents(span)=i; cursor=cursor+K;
end
points=pool(rows,:); [~,near]=sort(sum((points-best).^2,2)); [~,far]=sort(sum((points-center).^2,2),'descend');
order=[near(1:ceil(total/2));far(1:floor(total/2))]; order=unique(order,'stable'); order=[order(:);setdiff((1:total)',order(:),'stable')];
rows=rows(order); parents=parents(order);
end

function [rows,parents]=batchPlan(orderedRows,orderedParents,quota,N)
rows=zeros(quota,1); parents=zeros(quota,1); used=false(numel(orderedRows),1); counts=zeros(N,1); n=0;
for q=1:numel(orderedRows)
    i=orderedParents(q);
    if counts(i)<2
        n=n+1; rows(n)=orderedRows(q); parents(n)=i; used(q)=true; counts(i)=counts(i)+1;
        if n==quota, break; end
    end
end
if n<quota, error('FCS:BatchQuota','Unable to fill batch quota.'); end
end
