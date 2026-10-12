function [Best,T,info]=ASE_CSO_FCSQ_CountRepair(f,state,~,N,seed)
% ASE_CSO_FCSQ Feedback-conditioned sparse Seeking for CSO.
% Execution repair: actual evaluation counters exclude reserved starters.
% Shares B10 proposals/10-FE density; retains this file's random Tracing and
% candidate order. B10 is a quality reference, not a one-factor ablation.
% state.fcsPolicy: batch, continue, switch, random, success, reverse, or q.
% state.auditDecisions enables point-level decision and round logs.

started=tic;
pop=state.initialPopulation; D=size(pop,2); lb=state.lowerBound; ub=state.upperBound;
budget=state.maxEvaluations; policy='q';
if isfield(state,'fcsPolicy'), policy=char(state.fcsPolicy); end
auditDecisions=isfield(state,'auditDecisions') && state.auditDecisions;
alpha=.10; gamma=.90; epsilon=.10;
if isfield(state,'alpha'), alpha=state.alpha; end
if isfield(state,'gamma'), gamma=state.gamma; end
if isfield(state,'epsilon'), epsilon=state.epsilon; end
assert(N==50 && size(pop,1)==N,'FCS-CSO uses a population of 50.');
assert(D>=1 && budget>=N && budget==floor(budget));
assert(ismember(policy,{'batch','continue','switch','random','success','reverse','q'}));
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
rng(seed,'twister');

SMP=5; seekDimCount=max(1,round(.20*D));
V=.01*(2*rand(N,D)-1).*(ub-lb); Vmax=.2*(ub-lb);
T=nan(budget,1); fitness=zeros(N,1); Best=struct('Cost',inf,'Vector',pop(1,:)); fe=0;
for i=1:N
    fitness(i)=f(pop(i,:));
    if fitness(i)<Best.Cost, Best.Cost=fitness(i); Best.Vector=pop(i,:); end
    T(i)=Best.Cost;
end
fe=N; realPop=pop; personalBest=pop; personalBestCost=fitness;
seekBuffer=zeros(N*SMP,D); Q=zeros(6,2); qVisits=zeros(6,1); actionCounts=zeros(1,2);
rounds=0; seekEvalTotal=0; traceEvalTotal=0; seekSuccess=0; traceSuccess=0;
traceRollbacks=0; continueCount=0; switchCount=0; secondEvalSuccess=0;
parentCoverageTotal=0; starterCountTotal=0;
executedCounts=zeros(1,2); fallbackCount=0; mismatchCount=0; qFallbackUpdates=0;
sameParentSecond=0; otherParentSecond=0; openedParents=0; actualMaxParentCount=0; firstVisits=0;
conditionalCounts=zeros(6,2); conditionalSuccesses=zeros(6,2); conditionalGain=zeros(6,2);
decisionColumns={'Round','StarterFE','State','StarterParent','StarterRow','StarterSuccess','RequestedAction','ExecutedAction','FollowParent','FollowRow','FollowCountBefore','Fallback','FollowSuccess','Reward','NextState','FollowFE','StarterAnchor','StarterCost','FollowAnchor','FollowCost','StarterCountBefore'};
decisionLog=zeros(0,numel(decisionColumns));starterPoints=zeros(0,D);followPoints=zeros(0,D);roundLog=zeros(0,7);decisionNumber=0;
if auditDecisions
 decisionLog=zeros(ceil(budget/2),numel(decisionColumns));starterPoints=zeros(ceil(budget/2),D);followPoints=zeros(ceil(budget/2),D);
 roundLog=zeros(max(1,ceil((budget-N)/10)),7);
end

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

    roundTraceActual=fe-roundStart;
    if targetSeek>0 && ~isempty(seekIds)
        [orderedRows,orderedParents]=orderedCandidates(seekBuffer,seekIds,roundBest,center,SMP);
        if strcmp(policy,'batch')
            [rows,parents]=batchPlan(orderedRows,orderedParents,targetSeek,N);
            [Best,fitness,realPop,pop,personalBest,personalBestCost,T,fe,seekEvalTotal,seekSuccess,mask]=evaluateBatch(f,rows,parents,seekBuffer,fitness,realPop,pop,personalBest,personalBestCost,Best,T,fe,seekEvalTotal,seekSuccess,N);
            parentCoverageTotal=parentCoverageTotal+nnz(mask); starterCountTotal=starterCountTotal+numel(rows);
            actualMaxParentCount=max(actualMaxParentCount,max(accumarray(parents,1,[N 1])));firstVisits=firstVisits+nnz(mask);
        else
            starterCount=max(1,ceil(targetSeek/2));
            [starterRows,starterParents,usedRows,counts,starterMask]=selectStarters(orderedRows,orderedParents,starterCount,N);
            % selectStarters reserves rows; none of these slots has been evaluated.
            counts(:)=0;
            seekRoundInitialFitness=fitness; seekRoundVirtual=any(pop~=realPop,2);
            selectedMask=false(N,1);
            for pair=1:starterCount
                row=starterRows(pair); i=starterParents(pair); starterCountBefore=counts(i);
                [Best,fitness,realPop,pop,personalBest,personalBestCost,T,fe,seekEvalTotal,seekSuccess,improved,starterCost,starterAnchor]=evaluateOne(f,row,i,seekBuffer,fitness,realPop,pop,personalBest,personalBestCost,Best,T,fe,seekEvalTotal,seekSuccess);
                selectedMask(i)=true; counts(i)=counts(i)+1; usedRows(row)=true; starterCountTotal=starterCountTotal+1;
                firstVisits=firstVisits+double(starterCountBefore==0);starterFE=fe;
                if pair<=targetSeek-starterCount
                    phase=min(2,floor(3*progress)); stateIndex=1+2*phase+double(~improved);
                    if strcmp(policy,'q'), qVisits(stateIndex)=qVisits(stateIndex)+1; end
                    action=chooseAction(policy,Q,stateIndex,epsilon);
                    actionCounts(action)=actionCounts(action)+1;
                    if action==1
                        continueCount=continueCount+1; [nextRow,nextParent]=findContinue(orderedRows,orderedParents,usedRows,counts,i);
                    else
                        switchCount=switchCount+1; [nextRow,nextParent]=findSwitch(orderedRows,orderedParents,usedRows,counts,starterMask,i);
                    end
                    usedFallback=(nextRow==0);
                    if usedFallback, [nextRow,nextParent]=findAny(orderedRows,orderedParents,usedRows,counts); end
                    if nextRow==0, error('FCS:Quota','Unable to fill paired Seeking quota.'); end
                    followCountBefore=counts(nextParent);
                    [Best,fitness,realPop,pop,personalBest,personalBestCost,T,fe,seekEvalTotal,seekSuccess,followImproved,followCost,followAnchor]=evaluateOne(f,nextRow,nextParent,seekBuffer,fitness,realPop,pop,personalBest,personalBestCost,Best,T,fe,seekEvalTotal,seekSuccess);
                    selectedMask(nextParent)=true; counts(nextParent)=counts(nextParent)+1; usedRows(nextRow)=true;
                    secondEvalSuccess=secondEvalSuccess+followImproved;
                    reward=2*double(followImproved)-1;
                    nextState=1+2*min(2,floor(3*((fe-N)/max(1,budget-N))))+double(~followImproved);
                    actualAction=1+double(nextParent~=i);executedCounts(actualAction)=executedCounts(actualAction)+1;
                    fallbackCount=fallbackCount+usedFallback;mismatchCount=mismatchCount+double(actualAction~=action);
                    sameParentSecond=sameParentSecond+double(nextParent==i && followCountBefore==1);
                    otherParentSecond=otherParentSecond+double(nextParent~=i && followCountBefore==1);
                    openedParents=openedParents+double(followCountBefore==0);firstVisits=firstVisits+double(followCountBefore==0);
                    conditionalCounts(stateIndex,actualAction)=conditionalCounts(stateIndex,actualAction)+1;
                    conditionalSuccesses(stateIndex,actualAction)=conditionalSuccesses(stateIndex,actualAction)+followImproved;
                    conditionalGain(stateIndex,actualAction)=conditionalGain(stateIndex,actualAction)+max(0,followAnchor-followCost);
                    if strcmp(policy,'q')
                        Q(stateIndex,action)=Q(stateIndex,action)+alpha*(reward+gamma*max(Q(nextState,:))-Q(stateIndex,action));
                        qFallbackUpdates=qFallbackUpdates+usedFallback;
                    end
                    if auditDecisions
                        decisionNumber=decisionNumber+1;
                        decisionLog(decisionNumber,:)=[rounds starterFE stateIndex i row improved action actualAction nextParent nextRow followCountBefore usedFallback followImproved reward nextState fe starterAnchor starterCost followAnchor followCost starterCountBefore];
                        starterPoints(decisionNumber,:)=seekBuffer(row,:);followPoints(decisionNumber,:)=seekBuffer(nextRow,:);
                    end
                end
            end
            for p=find(selectedMask)'
                if seekRoundVirtual(p) && fitness(p)>=seekRoundInitialFitness(p)
                    pop(p,:)=realPop(p,:);
                end
            end
            parentCoverageTotal=parentCoverageTotal+nnz(selectedMask);actualMaxParentCount=max(actualMaxParentCount,max(counts));
            assert(all(counts<=2),'FCS:ParentCap','Actual parent evaluation cap exceeded.');
        end
    end
    actualSeek=fe-roundStart-roundTraceActual;
    assert(fe-roundStart==quota && roundTraceActual==targetTrace && actualSeek==targetSeek,'FCS:RoundQuota','Round did not consume its declared real FE quota.');
    if auditDecisions,roundLog(rounds,:)=[rounds roundStart quota targetTrace targetSeek roundTraceActual actualSeek];end
end
if auditDecisions,decisionLog=decisionLog(1:decisionNumber,:);starterPoints=starterPoints(1:decisionNumber,:);followPoints=followPoints(1:decisionNumber,:);roundLog=roundLog(1:rounds,:);end
T=T(1:fe);
info=struct('Algorithm',['FCS-CSO-' policy],'Seed',seed,'Evaluations',fe,'Seconds',toc(started),...
    'SeekingEvaluations',seekEvalTotal,'TracingEvaluations',traceEvalTotal,'Rounds',rounds,...
    'QTable',Q,'QVisits',qVisits,'ActionCounts',actionCounts,'Alpha',alpha,'Gamma',gamma,'Epsilon',epsilon,...
    'ContinueCount',continueCount,'SwitchCount',switchCount,'SecondEvaluationSuccesses',secondEvalSuccess,...
    'StarterEvaluations',starterCountTotal,'MeanParentCoverage',parentCoverageTotal/max(1,rounds),...
    'TraceSuccesses',traceSuccess,'SeekSuccesses',seekSuccess,'TraceRollbacks',traceRollbacks,...
    'Version','actual-counts-and-odd-tail-v1','ExecutedActionCounts',executedCounts,'FallbackCount',fallbackCount,'ActionMismatchCount',mismatchCount,...
    'QFallbackUpdates',qFallbackUpdates,'SameParentSecondEvaluations',sameParentSecond,'OtherParentSecondEvaluations',otherParentSecond,...
    'OpenedParentEvaluations',openedParents,'FirstVisitEvaluations',firstVisits,'ActualMaxParentEvaluations',actualMaxParentCount,...
    'ConditionalFollowCounts',conditionalCounts,'ConditionalFollowSuccesses',conditionalSuccesses,'ConditionalFollowGain',conditionalGain,...
    'DecisionColumns',{decisionColumns},'DecisionLog',decisionLog,'StarterPoints',starterPoints,'FollowPoints',followPoints,...
    'RoundColumns',{{'Round','StartFE','Quota','TargetTracing','TargetSeeking','ActualTracing','ActualSeeking'}},'RoundLog',roundLog);
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

function [rows,parents,used,counts,starterMask]=selectStarters(orderedRows,orderedParents,count,N)
rows=zeros(count,1); parents=zeros(count,1); used=false(max(orderedRows)+1,1); counts=zeros(N,1); starterMask=false(N,1); n=0;
for q=1:numel(orderedRows)
    i=orderedParents(q); row=orderedRows(q);
    if counts(i)==0
        n=n+1; rows(n)=row; parents(n)=i; used(row)=true; counts(i)=1; starterMask(i)=true;
        if n==count, return; end
    end
end
for q=1:numel(orderedRows)
    if n==count, return; end
    row=orderedRows(q); i=orderedParents(q);
    if ~used(row) && counts(i)<2, n=n+1; rows(n)=row; parents(n)=i; used(row)=true; counts(i)=counts(i)+1; end
end
if n<count, error('FCS:StarterQuota','Unable to select starters.'); end
end

function action=chooseAction(policy,Q,stateIndex,epsilon)
if strcmp(policy,'continue'), action=1; return; end
if strcmp(policy,'switch'), action=2; return; end
if strcmp(policy,'random'), action=randi(2); return; end
if strcmp(policy,'success'), action=1+double(mod(stateIndex,2)==0); return; end
if strcmp(policy,'reverse'), action=1+double(mod(stateIndex,2)==1); return; end
if rand<epsilon, action=randi(2); return; end
values=Q(stateIndex,:); best=find(values==max(values)); action=best(randi(numel(best)));
end

function [row,parent]=findContinue(rows,parents,used,counts,current)
row=0; parent=0;
for q=1:numel(rows)
    i=parents(q); if i==current && counts(i)<2 && ~used(rows(q)), row=rows(q); parent=i; return; end
end
end
function [row,parent]=findSwitch(rows,parents,used,counts,starterMask,current)
row=0; parent=0;
for q=1:numel(rows)
    i=parents(q); if i~=current && ~starterMask(i) && counts(i)<2 && ~used(rows(q)), row=rows(q); parent=i; return; end
end
for q=1:numel(rows)
    i=parents(q); if i~=current && counts(i)<2 && ~used(rows(q)), row=rows(q); parent=i; return; end
end
end
function [row,parent]=findAny(rows,parents,used,counts)
row=0; parent=0;
for q=1:numel(rows)
    i=parents(q); if counts(i)<2 && ~used(rows(q)), row=rows(q); parent=i; return; end
end
end

function [Best,fitness,realPop,pop,personalBest,personalBestCost,T,fe,seekEvalTotal,seekSuccess,improved,value,anchor]=evaluateOne(f,row,i,pool,fitness,realPop,pop,personalBest,personalBestCost,Best,T,fe,seekEvalTotal,seekSuccess)
anchor=fitness(i); value=f(pool(row,:)); fe=fe+1; seekEvalTotal=seekEvalTotal+1; improved=value<anchor;
if improved, seekSuccess=seekSuccess+1; fitness(i)=value; realPop(i,:)=pool(row,:); pop(i,:)=pool(row,:); end
if value<personalBestCost(i), personalBest(i,:)=pool(row,:); personalBestCost(i)=value; end
if value<Best.Cost, Best.Cost=value; Best.Vector=pool(row,:); end
T(fe)=Best.Cost;
end

function [Best,fitness,realPop,pop,personalBest,personalBestCost,T,fe,seekEvalTotal,seekSuccess,mask]=evaluateBatch(f,rows,parents,pool,fitness,realPop,pop,personalBest,personalBestCost,Best,T,fe,seekEvalTotal,seekSuccess,N)
mask=false(N,1); localCost=fitness; localVector=pop; anchorPop=realPop; wasVirtual=any(pop~=realPop,2);
for k=1:numel(rows)
    i=parents(k); value=f(pool(rows(k),:)); fe=fe+1; seekEvalTotal=seekEvalTotal+1; mask(i)=true;
    if value<personalBestCost(i), personalBest(i,:)=pool(rows(k),:); personalBestCost(i)=value; end
    if value<Best.Cost, Best.Cost=value; Best.Vector=pool(rows(k),:); end
    if value<localCost(i), localCost(i)=value; localVector(i,:)=pool(rows(k),:); end
    T(fe)=Best.Cost;
end
for i=find(mask)'
    if localCost(i)<fitness(i), fitness(i)=localCost(i); realPop(i,:)=localVector(i,:); pop(i,:)=localVector(i,:); elseif wasVirtual(i), pop(i,:)=anchorPop(i,:); end
end
end
