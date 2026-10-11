function [Best,T,info]=ASE_CSO_SparseAlloc(f,state,~,N,seed)
% Sparse CSO allocation pilot.
% The B10 search kernel is unchanged. Only the six Seeking credits are
% allocated sequentially after three first-visit credits. The policy is one
% of continue, switch, random or q. Q has four states and two actions.
pop=state.initialPopulation; D=size(pop,2); lb=state.lowerBound; ub=state.upperBound;
budget=state.maxEvaluations; policy=state.policy; started=tic;
assert(N==50 && budget>=N && ismember(policy,{'continue','switch','random','q'}));
rng(seed,'twister');
V=.01*(2*rand(N,D)-1).*(ub-lb); Vmax=.2*(ub-lb); dimCount=max(1,round(.2*D));
T=nan(budget,1); fitness=zeros(N,1); Best=struct('Cost',inf,'Vector',pop(1,:)); fe=0;
for i=1:N
    fitness(i)=f(pop(i,:));
    if fitness(i)<Best.Cost, Best.Cost=fitness(i); Best.Vector=pop(i,:); end
    T(i)=Best.Cost;
end
fe=N; realPop=pop; personalBest=pop; personalCost=fitness; buffer=zeros(N*5,D);
evalCost=fitness; evalVector=realPop;
Q=zeros(4,2); alpha=.2; gamma=.9; epsilon=.1;
seekFE=0; traceFE=0; rounds=0; actionCount=zeros(1,2); qVisits=zeros(4,1);
parentCoverage=0; concentration=0; maxParent=0; traceRollbacks=0; traceSuccess=0;
while fe<budget
    rounds=rounds+1; progress=(fe-N)/max(1,budget-N); center=mean(pop,1); roundBest=Best.Vector;
    quota=min(10,budget-fe); eliteCount=max(2,ceil(.2*N)); [~,ord]=sort(personalCost); elites=ord(1:eliteCount);
    trial=pop; trialV=V; tracing=false(N,1);
    for i=1:N
        elite=personalBest(elites(randi(eliteCount)),:);
        if rand<.4
            tracing(i)=true; base=V(i,:)+2*rand(1,D).*(elite-pop(i,:));
            inertia=.9-.5*progress; trialV(i,:)=inertia*V(i,:)+base-V(i,:);
            trialV(i,:)=max(-Vmax,min(Vmax,trialV(i,:))); trial(i,:)=max(lb,min(ub,pop(i,:)+trialV(i,:)));
        else
            rows=(i-1)*5+(1:5); buffer(rows,:)=pop(i(ones(5,1)),:);
            for j=2:5
                dims=randperm(D,dimCount); eliteStep=.25*(elite(dims)-pop(i,dims));
                step=.025*(ub(dims)-lb(dims))*(1-progress);
                buffer(rows(j),dims)=pop(i,dims)+eliteStep+step.*(2*rand(1,dimCount)-1);
                buffer(rows(j),:)=max(lb,min(ub,buffer(rows(j),:)));
            end
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing); pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialV(traceIds,:);
    nTrace=min(numel(traceIds),min(4,max(1,quota-1))); nSeek=quota-nTrace;
    if nTrace>0
        dBest=sum((trial(traceIds,:)-roundBest).^2,2); dCenter=sum((trial(traceIds,:)-center).^2,2);
        traceCats=traceIds(selectTracing(dBest,dCenter,nTrace)); traceCats=traceCats(randperm(numel(traceCats)));
    else, traceCats=[]; end
    for i=traceCats'
        value=f(trial(i,:)); fe=fe+1; traceFE=traceFE+1;
        if value<fitness(i), realPop(i,:)=trial(i,:); fitness(i)=value; pop(i,:)=trial(i,:); traceSuccess=traceSuccess+1;
        else, pop(i,:)=realPop(i,:); traceRollbacks=traceRollbacks+1; end
        if value<personalCost(i), personalBest(i,:)=trial(i,:); personalCost(i)=value; end
        if value<Best.Cost, Best.Cost=value; Best.Vector=trial(i,:); end
        T(fe)=Best.Cost;
    end
    if nSeek>0
        firstCats=selectSeekingParents(buffer,seekIds,roundBest,center,min(3,numel(seekIds)));
        evalCost=fitness; evalVector=realPop;
        counts=zeros(N,1); selected=cell(N,1); current=firstCats(1); lastSuccess=false; reserved=firstCats(2:end);
        for q=1:nSeek
            if q==1
                action=1; % first-visit credit starts the chain
            else
                phase=double(fe>=N+.5*(budget-N)); stateIndex=1+2*phase+double(lastSuccess);
                qVisits(stateIndex)=qVisits(stateIndex)+1;
                if strcmp(policy,'q')
                    if rand<epsilon, action=randi(2); else, [~,action]=max(Q(stateIndex,:)); end
                elseif strcmp(policy,'continue'), action=1;
                elseif strcmp(policy,'switch'), action=2;
                else, action=randi(2);
                end
            end
            if counts(current)>=2 || (action==2 && isempty(reserved) && all(counts(seekIds)>0))
                action=2;
            end
            if action==2
                actionCount(2)=actionCount(2)+1;
                if ~isempty(reserved), next=reserved(1); reserved(1)=[];
                else
                    unused=seekIds(counts(seekIds)==0); if isempty(unused), unused=seekIds(counts(seekIds)<2); end
                    next=unused(1);
                end
                current=next; candidate=2; % first candidate of a new parent
            else
                actionCount(1)=actionCount(1)+1; candidate=counts(current)+2;
            end
            row=(current-1)*5+candidate; counts(current)=counts(current)+1; selected{current}(end+1)=row;
            anchorCost=fitness(current); value=f(buffer(row,:)); fe=fe+1; seekFE=seekFE+1;
            gain=(anchorCost-value)/max(abs(anchorCost),eps); reward=max(-1,min(1,gain)); lastSuccess=value<anchorCost;
            if value<evalCost(current), evalCost(current)=value; evalVector(current,:)=buffer(row,:); end
            if strcmp(policy,'q') && q>1
                nextPhase=double(fe>=N+.5*(budget-N)); nextState=1+2*nextPhase+double(lastSuccess);
                Q(stateIndex,action)=Q(stateIndex,action)+alpha*(reward+gamma*max(Q(nextState,:))-Q(stateIndex,action));
            end
            if value<personalCost(current), personalBest(current,:)=buffer(row,:); personalCost(current)=value; end
            if value<Best.Cost, Best.Cost=value; Best.Vector=buffer(row,:); end
            T(fe)=Best.Cost;
        end
        covered=nnz(counts); parentCoverage=parentCoverage+covered; concentration=concentration+sum((counts/nSeek).^2); maxParent=max(maxParent,max(counts));
        for i=find(counts>0)'
            pop(i,:)=evalVector(i,:); realPop(i,:)=evalVector(i,:); fitness(i)=evalCost(i);
        end
    end
end
T=T(1:fe); info=struct('Algorithm',['SparseAlloc-' policy],'Seed',seed,'Evaluations',fe,'Seconds',toc(started),...
    'SeekingEvaluations',seekFE,'TracingEvaluations',traceFE,'Rounds',rounds,'QTable',Q,'QVisits',qVisits,...
    'ContinueActions',actionCount(1),'SwitchActions',actionCount(2),'MeanParentCoverage',parentCoverage/max(1,rounds),...
    'MeanConcentration',concentration/max(1,rounds),'MaxParentEvaluations',maxParent,'TraceSuccesses',traceSuccess,'TraceRollbacks',traceRollbacks);

end

function ids=selectTracing(near,far,count)
[~,a]=sort(near); [~,b]=sort(far,'descend'); raw=[a(1:ceil(count/2));b(1:floor(count/2))]; ids=zeros(count,1); k=0;
for i=1:numel(raw), if ~any(ids(1:k)==raw(i)), k=k+1; ids(k)=raw(i); end, end
for i=1:numel(near), if k==count, break, end, if ~any(ids(1:k)==i), k=k+1; ids(k)=i; end, end
end

function cats=selectSeekingParents(pool,ids,best,center,count)
if count==0, cats=zeros(0,1); return, end
near=zeros(numel(ids),1); far=zeros(numel(ids),1);
for k=1:numel(ids)
    rows=(ids(k)-1)*5+(2:5); pts=pool(rows,:); near(k)=min(sum((pts-best).^2,2)); far(k)=max(sum((pts-center).^2,2));
end
[~,a]=sort(near); [~,b]=sort(far,'descend'); raw=[a(1:ceil(count/2));b(1:floor(count/2))]; chosen=zeros(count,1); n=0;
for j=1:numel(raw), if ~any(chosen(1:n)==raw(j)), n=n+1; chosen(n)=raw(j); end, end
for j=1:numel(ids), if n==count, break, end, if ~any(chosen(1:n)==j), n=n+1; chosen(n)=j; end, end
cats=ids(chosen(1:count));
end
