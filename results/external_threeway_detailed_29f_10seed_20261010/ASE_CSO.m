function [Best,T,info]=ASE_CSO(f,state,~,N,seed)
% ASE_CSO Anchored sparse-evaluation cat swarm optimization, frozen implementation.
% Required state fields: initialPopulation, lowerBound, upperBound,
% maxEvaluations. All search parameters are fixed; no RL or experimental
% selectors are present. Initial population generation belongs to the caller.
clockStart=tic;
pop=state.initialPopulation; D=size(pop,2);
lb=state.lowerBound; ub=state.upperBound; budget=state.maxEvaluations;
assert(N==50 && size(pop,1)==N,'Frozen population size is 50.');
assert(D>=1 && budget>=N && budget==floor(budget));
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
rng(seed,'twister');
V=0.01*(2*rand(N,D)-1).*(ub-lb);
Vmax=0.2*(ub-lb);
T=nan(budget,1); fitness=zeros(N,1); Best.Cost=inf;
for i=1:N
    fitness(i)=f(pop(i,:));
    if fitness(i)<Best.Cost
        Best.Cost=fitness(i); Best.Vector=pop(i,:);
    end
    T(i)=Best.Cost;
end
realPop=pop; personalBest=pop; personalBestCost=fitness;
info.Algorithm='EB-CSO'; info.Seed=seed; info.Evaluations=N;
info.InitialCost=Best.Cost; info.InitialPopulation=pop;
info.FirstImprovementEvaluation=NaN;
info.SeekingEvaluations=0; info.TracingEvaluations=0;
info.CandidateEvaluations=0;
info.EvaluationsPerRound=[];
info.TargetTracingEvaluations=[]; info.ActualTracingEvaluations=[];
info.TargetSeekingEvaluations=[]; info.ActualSeekingEvaluations=[];
info.BudgetFillRate=[]; info.ModeAllocationError=[];
info.SeekingParentCoverage=[]; info.SeekingConcentration=[];
info.SeekingMaxParentEvaluations=[];
info.SeekingGlobalImprovementCounts=[]; info.TracingGlobalImprovementCounts=[];
info.SeekingGlobalGain=[]; info.TracingGlobalGain=[];
while info.Evaluations<budget
    roundStart=info.Evaluations;
    progress=(info.Evaluations-N)/max(1,budget-N);
    center=mean(pop,1); roundBest=Best.Vector;
    budgetThisRound=min(5,budget-info.Evaluations);
    eliteCount=max(2,ceil(0.20*N));
    [~,eliteOrder]=sort(personalBestCost);
    elitePool=eliteOrder(1:eliteCount);
    trial=pop; trialVelocity=V;
    tracing=false(N,1); seekingPool=cell(N,1);
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
            copies=repmat(pop(i,:),5,1);
            for j=2:5
                dims=randperm(D,max(1,round(0.20*D)));
                eliteStep=0.25*(eliteVector(dims)-pop(i,dims));
                differenceStep=0;
                step=0.05*(ub(dims)-lb(dims))/2*(1-progress);
                copies(j,dims)=pop(i,dims)+eliteStep+differenceStep+ ...
                    step.*(2*rand(1,numel(dims))-1);
                copies(j,:)=max(lb,min(ub,copies(j,:)));
            end
            seekingPool{i}=copies;
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing);
    pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialVelocity(traceIds,:);
    [targetTrace,targetSeek]=AllocateBudget(budgetThisRound,numel(traceIds),numel(seekIds));
    if targetTrace>0
        traceBest=sum((trial(traceIds,:)-Best.Vector).^2,2);
        traceCenter=sum((trial(traceIds,:)-center).^2,2);
        traceCats=traceIds(SelectTracing(traceBest,traceCenter,targetTrace));
    else
        traceCats=[];
    end
    traceCats=traceCats(randperm(numel(traceCats)));
    seekCats=[];
    seekCats=seekCats(randperm(numel(seekCats))); %#ok<NASGU>
    seekPlan=ScreenSeeking(seekingPool,seekIds,roundBest,center,targetSeek);
    seekCats=find(~cellfun(@isempty,seekPlan));
    cats=[traceCats;seekCats];
    parentCounts=zeros(N,1);
    roundSeek=0; roundTrace=0; seekGlobals=0; traceGlobals=0;
    seekGain=0; traceGain=0;
    for k=1:numel(cats)
        i=cats(k);
        if tracing(i)
            value=f(trial(i,:));
            info.Evaluations=info.Evaluations+1;
            roundTrace=roundTrace+1;
            if value<fitness(i)
                realPop(i,:)=trial(i,:);
                fitness(i)=value; pop(i,:)=trial(i,:);
            else
                pop(i,:)=realPop(i,:);
            end
            if value<personalBestCost(i)
                personalBest(i,:)=trial(i,:); personalBestCost(i)=value;
            end
            oldBest=Best.Cost;
            if value<Best.Cost
                Best.Cost=value; Best.Vector=trial(i,:);
            end
            traceGlobals=traceGlobals+double(Best.Cost<oldBest);
            traceGain=traceGain+oldBest-Best.Cost;
            if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            T(info.Evaluations)=Best.Cost;
        else
            copies=seekingPool{i}; selected=seekPlan{i};
            localCost=fitness(i); parentCost=fitness(i); localVector=pop(i,:);
            wasVirtual=any(pop(i,:)~=realPop(i,:));
            for j=selected
                value=f(copies(j,:));
                info.Evaluations=info.Evaluations+1;
                roundSeek=roundSeek+1; parentCounts(i)=parentCounts(i)+1;
                if value<personalBestCost(i)
                    personalBest(i,:)=copies(j,:); personalBestCost(i)=value;
                end
                if value<localCost
                    localCost=value; localVector=copies(j,:);
                end
                oldBest=Best.Cost;
                if value<Best.Cost
                    Best.Cost=value; Best.Vector=copies(j,:);
                end
                seekGlobals=seekGlobals+double(Best.Cost<oldBest);
                seekGain=seekGain+oldBest-Best.Cost;
                if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                    info.FirstImprovementEvaluation=info.Evaluations;
                end
                T(info.Evaluations)=Best.Cost;
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
    info.SeekingEvaluations=info.SeekingEvaluations+roundSeek;
    info.TracingEvaluations=info.TracingEvaluations+roundTrace;
    info.CandidateEvaluations=info.CandidateEvaluations+roundSeek+roundTrace;
    info.EvaluationsPerRound(end+1)=info.Evaluations-roundStart;
    info.TargetTracingEvaluations(end+1)=targetTrace;
    info.ActualTracingEvaluations(end+1)=roundTrace;
    info.TargetSeekingEvaluations(end+1)=targetSeek;
    info.ActualSeekingEvaluations(end+1)=roundSeek;
    info.BudgetFillRate(end+1)=(roundTrace+roundSeek)/max(1,budgetThisRound);
    info.ModeAllocationError(end+1,:)=[roundTrace-targetTrace roundSeek-targetSeek];
    info.SeekingParentCoverage(end+1)=nnz(parentCounts);
    info.SeekingConcentration(end+1)=sum((parentCounts/max(1,roundSeek)).^2);
    info.SeekingMaxParentEvaluations(end+1)=max(parentCounts);
    info.SeekingGlobalImprovementCounts(end+1)=seekGlobals;
    info.TracingGlobalImprovementCounts(end+1)=traceGlobals;
    info.SeekingGlobalGain(end+1)=seekGain; info.TracingGlobalGain(end+1)=traceGain;
end
T=T(1:info.Evaluations);
info.Seconds=toc(clockStart);
end

function [nTrace,nSeek]=AllocateBudget(quota,traceCount,seekCount)
% Two tracing slots for full rounds, reference fallback at the budget tail.
nTrace=min(traceCount,max(1,min(quota-1,round(2))));
nSeek=min(2*seekCount,quota-nTrace);
leftover=quota-nTrace-nSeek;
extraTrace=min(leftover,traceCount-nTrace); nTrace=nTrace+extraTrace;
leftover=leftover-extraTrace;
extraSeek=min(leftover,2*seekCount-nSeek); nSeek=nSeek+extraSeek;
end

function cats=SelectTracing(distBest,distCenter,count)
[~,near]=sort(distBest); [~,far]=sort(distCenter,'descend');
cats=unique([near(1:ceil(count/2));far(1:floor(count/2))],'stable');
if numel(cats)<count
    extra=setdiff((1:numel(distBest))',cats,'stable');
    cats=[cats;extra(1:count-numel(cats))];
end
end

function plan=ScreenSeeking(pool,catIds,best,center,quota)
plan=cell(numel(pool),1);
if quota==0,return,end
points=cell(numel(catIds),1);
for q=1:numel(catIds),points{q}=pool{catIds(q)}(2:end,:);end
points=vertcat(points{:}); perCat=size(pool{catIds(1)},1)-1;
parents=repelem(catIds,perCat);
candidates=repmat((2:perCat+1)',numel(catIds),1);
[~,near]=sort(sum((points-best).^2,2));
[~,far]=sort(sum((points-center).^2,2),'descend');
selected=false(size(parents)); counts=zeros(numel(pool),1);
orders={near,far}; targets=[ceil(quota/2),quota];
for phase=1:2
    if nnz(selected)>=targets(phase),continue,end
    for q=1:numel(parents)
        index=orders{phase}(q); parent=parents(index);
        if ~selected(index) && counts(parent)<2
            selected(index)=true; counts(parent)=counts(parent)+1;
            plan{parent}(end+1)=candidates(index);
        end
        if nnz(selected)>=targets(phase),break,end
    end
end
end
