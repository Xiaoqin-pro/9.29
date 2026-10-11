function [Best,T,info]=ASE_CSO_Lean(f,state,~,N,seed)
% ASE_CSO Anchored sparse-evaluation cat swarm optimization, frozen implementation.
% Required state fields: initialPopulation, lowerBound, upperBound,
% maxEvaluations. All search parameters are fixed; no RL or experimental
% selectors are present. Initial population generation belongs to the caller.
clockStart=tic;
pop=state.initialPopulation; D=size(pop,2);
initialPopulation=pop;
lb=state.lowerBound; ub=state.upperBound; budget=state.maxEvaluations;
assert(N==50 && size(pop,1)==N,'Frozen population size is 50.');
assert(D>=1 && budget>=N && budget==floor(budget));
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
rng(seed,'twister');
V=0.01*(2*rand(N,D)-1).*(ub-lb);
Vmax=0.2*(ub-lb);
seekDimCount=max(1,round(0.20*D));
T=nan(budget,1); fitness=zeros(N,1); Best.Cost=inf; fe=0;
for i=1:N
    fitness(i)=f(pop(i,:));
    if fitness(i)<Best.Cost
        Best.Cost=fitness(i); Best.Vector=pop(i,:);
    end
    T(i)=Best.Cost;
end
fe=N;
realPop=pop; personalBest=pop; personalBestCost=fitness;
seekEvalTotal=0; traceEvalTotal=0;
seekBuffer=zeros(N*5,D);
while fe<budget
    progress=(fe-N)/max(1,budget-N);
    center=mean(pop,1); roundBest=Best.Vector;
    budgetThisRound=min(5,budget-fe);
    eliteCount=max(2,ceil(0.20*N));
    [~,eliteOrder]=sort(personalBestCost);
    elitePool=eliteOrder(1:eliteCount);
    trial=pop; trialVelocity=V;
    tracing=false(N,1);
    for i=1:N
        eliteIndex=elitePool(randi(eliteCount));
        eliteVector=personalBest(eliteIndex,:);
        if rand<0.40
            tracing(i)=true;
            % Preserve the reference arithmetic order: simplifying this
            % expression changes floating-point trajectories.
            baseInertia=1.0;
            trialVelocity(i,:)=baseInertia*V(i,:)+2*rand(1,D).* ...
                (eliteVector-pop(i,:));
            inertia=0.9-0.5*progress;
            trialVelocity(i,:)=inertia*V(i,:)+ ...
                trialVelocity(i,:)-baseInertia*V(i,:);
            trialVelocity(i,:)=max(-Vmax,min(Vmax,trialVelocity(i,:)));
            trial(i,:)=pop(i,:)+trialVelocity(i,:);
            trial(i,:)=max(lb,min(ub,trial(i,:)));
        else
            rows=(i-1)*5+(1:5);
            seekBuffer(rows,:)=repmat(pop(i,:),5,1);
            for j=2:5
                dims=randperm(D,seekDimCount);
                eliteStep=0.25*(eliteVector(dims)-pop(i,dims));
                differenceStep=0;
                step=0.05*(ub(dims)-lb(dims))/2*(1-progress);
                seekBuffer(rows(j),dims)=pop(i,dims)+eliteStep+differenceStep+ ...
                    step.*(2*rand(1,numel(dims))-1);
                seekBuffer(rows(j),:)=max(lb,min(ub,seekBuffer(rows(j),:)));
            end
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing);
    pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialVelocity(traceIds,:);
    [targetTrace,targetSeek]=AllocateBudgetLean(budgetThisRound,numel(traceIds),numel(seekIds));
    if targetTrace>0
        traceBest=sum((trial(traceIds,:)-Best.Vector).^2,2);
        traceCenter=sum((trial(traceIds,:)-center).^2,2);
        traceCats=traceIds(SelectTracingLean(traceBest,traceCenter,targetTrace));
    else
        traceCats=[];
    end
    traceCats=traceCats(randperm(numel(traceCats)));
    seekPlan=ScreenSeekingFlat(seekBuffer,seekIds,roundBest,center,targetSeek,N,5);
    seekCats=find(~cellfun(@isempty,seekPlan));
    cats=[traceCats;seekCats];
    for k=1:numel(cats)
        i=cats(k);
        if tracing(i)
            value=f(trial(i,:));
            fe=fe+1; traceEvalTotal=traceEvalTotal+1;
            if value<fitness(i)
                realPop(i,:)=trial(i,:);
                fitness(i)=value; pop(i,:)=trial(i,:);
            else
                pop(i,:)=realPop(i,:);
            end
            if value<personalBestCost(i)
                personalBest(i,:)=trial(i,:); personalBestCost(i)=value;
            end
            if value<Best.Cost
                Best.Cost=value; Best.Vector=trial(i,:);
            end
            T(fe)=Best.Cost;
        else
            selected=seekPlan{i};
            localCost=fitness(i); parentCost=fitness(i); localVector=pop(i,:);
            wasVirtual=any(pop(i,:)~=realPop(i,:));
            for q=1:numel(selected)
                row=selected(q); value=f(seekBuffer(row,:));
                fe=fe+1; seekEvalTotal=seekEvalTotal+1;
                if value<personalBestCost(i)
                    personalBest(i,:)=seekBuffer(row,:); personalBestCost(i)=value;
                end
                if value<localCost
                    localCost=value; localVector=seekBuffer(row,:);
                end
                if value<Best.Cost
                    Best.Cost=value; Best.Vector=seekBuffer(row,:);
                end
                T(fe)=Best.Cost;
            end
            pop(i,:)=localVector;
            if localCost<parentCost
                realPop(i,:)=localVector;
            elseif wasVirtual && ~isempty(selected)
                pop(i,:)=realPop(i,:);
            end
            fitness(i)=localCost;
        end
    end
end
T=T(1:fe); info=struct('Algorithm','EB-CSO','Seed',seed,'Evaluations',fe,...
    'InitialCost',T(N),'InitialPopulation',initialPopulation,'SeekingEvaluations',seekEvalTotal,...
    'TracingEvaluations',traceEvalTotal,'CandidateEvaluations',seekEvalTotal+traceEvalTotal,...
    'Seconds',toc(clockStart));
end

function [nTrace,nSeek]=AllocateBudgetLean(quota,traceCount,seekCount)
% Two tracing slots for full rounds, reference fallback at the budget tail.
nTrace=min(traceCount,max(1,min(quota-1,round(2))));
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

function plan=ScreenSeekingFlat(pool,catIds,best,center,quota,N,SMP)
plan=cell(N,1);
if quota==0,return,end
nCats=numel(catIds); perCat=SMP-1; total=nCats*perCat; rows=zeros(total,1); parents=zeros(total,1); row=0;
for q=1:nCats
    block=(catIds(q)-1)*SMP+(2:SMP);
    ix=row+(1:perCat); rows(ix)=block; parents(ix)=catIds(q); row=row+perCat;
end
points=pool(rows,:);
[~,near]=sort(sum((points-best).^2,2));
[~,far]=sort(sum((points-center).^2,2),'descend');
selected=false(total,1); counts=zeros(N,1); chosen=zeros(N,2);
orders={near,far}; targets=[ceil(quota/2),quota];
for phase=1:2
    if nnz(selected)>=targets(phase),continue,end
    for q=1:total
        index=orders{phase}(q); parent=parents(index);
        if ~selected(index) && counts(parent)<2
            selected(index)=true; counts(parent)=counts(parent)+1; chosen(parent,counts(parent))=rows(index);
        end
        if nnz(selected)>=targets(phase),break,end
    end
end
for q=find(counts)'
    plan{q}=chosen(q,1:counts(q));
end
end
