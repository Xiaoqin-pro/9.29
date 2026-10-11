function [Best,T,info]=ASE_CSO_QualityPool(f,state,~,N,seed)
% Experimental Seeking pool on the frozen B10 Tracing kernel.
% Four sources: own memory, elite memory, coordinate exemplars, Range.
% state.selection: geometry, random, reserved or credit. No RL or DE.
started=tic;
pop=state.initialPopulation; D=size(pop,2); lb=state.lowerBound; ub=state.upperBound;
budget=state.maxEvaluations; selector=state.selection;
assert(N==50 && size(pop,1)==N && budget>=N);
assert(ismember(selector,{'geometry','random','reserved','credit'}));
rng(seed,'twister');
selectionStream=RandStream('mt19937ar','Seed',mod(seed+7919,2^32-1));
V=0.01*(2*rand(N,D)-1).*(ub-lb); Vmax=0.2*(ub-lb);
dimCount=max(1,round(.20*D)); T=nan(budget,1); fitness=zeros(N,1);
Best=struct('Cost',inf,'Vector',pop(1,:));
for i=1:N
    fitness(i)=f(pop(i,:));
    if fitness(i)<Best.Cost, Best.Cost=fitness(i); Best.Vector=pop(i,:); end
    T(i)=Best.Cost;
end
fe=N; realPop=pop; personalBest=pop; personalCost=fitness;
credit=zeros(1,4); generated=zeros(1,4); eligibleTotal=zeros(1,4);
evaluated=zeros(1,4); successes=zeros(1,4); globalWins=zeros(1,4);
localGain=zeros(1,4); globalGain=zeros(1,4); zeroDirections=zeros(1,4);
seekFE=0; traceFE=0; rounds=0; parentSum=0; concentrationSum=0; seekRounds=0;
maxParentFE=0; traceRollbacks=0; seekRollbacks=0; traceWins=0;
creditSelections=zeros(1,4); explorationReservations=0;
checkpoints=round(budget*[.2 .6 .8 1]); checkpointIndex=1;
history=nan(4,4,9); % generated, eligible, evaluated, success, gbest, gains, credit, zero
pool=zeros(4*N,D);
while fe<budget
    rounds=rounds+1;
    progress=(fe-N)/max(1,budget-N); center=mean(pop,1); roundBest=Best.Vector;
    anchorCost=fitness; anchorPop=realPop;
    [~,eliteOrder]=sort(personalCost); elites=eliteOrder(1:ceil(.20*N));
    trial=pop; trialV=V; tracing=false(N,1); eligible=false(4*N,1);
    for i=1:N
        elite=personalBest(elites(randi(numel(elites))),:);
        if rand<.40
            tracing(i)=true;
            baseInertia=1;
            trialV(i,:)=baseInertia*V(i,:)+2*rand(1,D).*(elite-pop(i,:));
            inertia=.9-.5*progress;
            trialV(i,:)=inertia*V(i,:)+trialV(i,:)-baseInertia*V(i,:);
            trialV(i,:)=max(-Vmax,min(Vmax,trialV(i,:)));
            trial(i,:)=max(lb,min(ub,pop(i,:)+trialV(i,:)));
        else
            rows=(i-1)*4+(1:4);
            pool(rows,:)=pop(i(ones(4,1)),:);
            for s=1:4
                dims=randperm(D,dimCount);
                if s==1
                    direction=personalBest(i,dims)-pop(i,dims);
                    pool(rows(s),dims)=pop(i,dims)+.25*rand(1,dimCount).*direction;
                elseif s==2
                    direction=elite(dims)-pop(i,dims);
                    pool(rows(s),dims)=pop(i,dims)+.25*rand(1,dimCount).*direction;
                elseif s==3
                    % Two-way fitness tournament per modified coordinate.
                    % Donors are real pbest records; exclude the current cat.
                    donors=randi(N-1,2,dimCount); donors=donors+(donors>=i);
                    chooseSecond=personalCost(donors(2,:))<personalCost(donors(1,:));
                    mentor=donors(1,:); mentor(chooseSecond)=donors(2,chooseSecond);
                    values=personalBest(sub2ind([N D],mentor,dims));
                    direction=values-pop(i,dims);
                    pool(rows(s),dims)=pop(i,dims)+.25*rand(1,dimCount).*direction;
                else
                    step=.025*(ub(dims)-lb(dims))*(1-progress);
                    direction=step.*(2*rand(1,dimCount)-1);
                    pool(rows(s),dims)=pop(i,dims)+direction;
                end
                pool(rows(s),:)=max(lb,min(ub,pool(rows(s),:)));
                generated(s)=generated(s)+1;
                zeroDirections(s)=zeroDirections(s)+~any(direction);
                % A cached real anchor needs no new FE. Drop exact duplicates
                % within this parent's pool; apply identically to all selectors.
                isKnown=isequal(pool(rows(s),:),anchorPop(i,:));
                duplicate=any(all(pool(rows(1:s-1),:)==pool(rows(s),:),2));
                eligible(rows(s))=~isKnown && ~duplicate;
                eligibleTotal(s)=eligibleTotal(s)+eligible(rows(s));
            end
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing);
    pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialV(traceIds,:);
    quota=min(10,budget-fe);
    nTrace=min(numel(traceIds),min(4,max(1,quota-1)));
    capacities=zeros(N,1);
    for i=seekIds', capacities(i)=min(2,sum(eligible((i-1)*4+(1:4)))); end
    nSeek=min(sum(capacities),quota-nTrace);
    extra=min(quota-nTrace-nSeek,numel(traceIds)-nTrace); nTrace=nTrace+extra;
    % Usually unnecessary: use an extra cached-anchor evaluation if every
    % generated Seeking candidate is known and no unused Tracing cat remains.
    fillFE=quota-nTrace-nSeek;
    if nTrace>0
        near=sum((trial(traceIds,:)-roundBest).^2,2);
        far=sum((trial(traceIds,:)-center).^2,2);
        traceCats=traceIds(selectTracing(near,far,nTrace));
        traceCats=traceCats(randperm(numel(traceCats)));
    else, traceCats=[]; end
    [chosen,creditPicked,reserved]=selectPool(pool,eligible,roundBest,center,nSeek,N,credit,selector,selectionStream);
    creditSelections=creditSelections+creditPicked;
    explorationReservations=explorationReservations+reserved;
    counts=accumarray(ceil(chosen/4),1,[N 1]);
    if nSeek>0
        seekRounds=seekRounds+1; parentSum=parentSum+nnz(counts);
        concentrationSum=concentrationSum+sum((counts/nSeek).^2);
        maxParentFE=max(maxParentFE,max(counts));
    end
    for i=traceCats'
        value=f(trial(i,:)); fe=fe+1; traceFE=traceFE+1;
        if value<fitness(i)
            realPop(i,:)=trial(i,:); fitness(i)=value; pop(i,:)=trial(i,:); traceWins=traceWins+1;
        else
            pop(i,:)=realPop(i,:); traceRollbacks=traceRollbacks+1;
        end
        if value<personalCost(i), personalBest(i,:)=trial(i,:); personalCost(i)=value; end
        if value<Best.Cost, Best.Cost=value; Best.Vector=trial(i,:); end
        T(fe)=Best.Cost;
    end
    % All selection decisions use the round snapshot. Evaluate grouped by
    % parent, then accept the best real candidate against its trusted anchor.
    for i=find(counts>0)'
        localCost=fitness(i); localVector=realPop(i,:);
        selected=chosen(ceil(chosen/4)==i);
        for row=selected'
            s=mod(row-1,4)+1; value=f(pool(row,:));
            fe=fe+1; seekFE=seekFE+1; evaluated(s)=evaluated(s)+1;
            gain=max(0,anchorCost(i)-value)/max(abs(anchorCost(i)),eps);
            gain=min(1,gain); credit(s)=.9*credit(s)+.1*gain;
            successes(s)=successes(s)+(value<anchorCost(i)); localGain(s)=localGain(s)+gain;
            if value<personalCost(i), personalBest(i,:)=pool(row,:); personalCost(i)=value; end
            if value<localCost, localCost=value; localVector=pool(row,:); end
            if value<Best.Cost
                globalWins(s)=globalWins(s)+1; globalGain(s)=globalGain(s)+Best.Cost-value;
                Best.Cost=value; Best.Vector=pool(row,:);
            end
            T(fe)=Best.Cost;
        end
        seekRollbacks=seekRollbacks+(localCost>=fitness(i) && any(pop(i,:)~=realPop(i,:)));
        pop(i,:)=localVector; realPop(i,:)=localVector; fitness(i)=localCost;
    end
    for k=1:fillFE
        value=f(Best.Vector); fe=fe+1; T(fe)=Best.Cost;
        assert(value==Best.Cost,'Known best cache mismatch');
    end
    while checkpointIndex<=4 && fe>=checkpoints(checkpointIndex)
        history(checkpointIndex,:,:)=reshape([generated;eligibleTotal;evaluated;successes;globalWins;localGain;globalGain;credit;zeroDirections]',1,4,9);
        checkpointIndex=checkpointIndex+1;
    end
end
info=struct('Algorithm',['B10-Quality-' selector],'Seed',seed,'Evaluations',fe,...
    'Seconds',toc(started),'SeekingEvaluations',seekFE,'TracingEvaluations',traceFE,...
    'CachedFallbackEvaluations',fe-N-seekFE-traceFE,'Rounds',rounds,...
    'MeanParentCoverage',parentSum/max(1,seekRounds),'MeanConcentration',concentrationSum/max(1,seekRounds),...
    'MaxParentEvaluations',maxParentFE,'TraceSuccesses',traceWins,'TraceRollbacks',traceRollbacks,...
    'SeekRollbacks',seekRollbacks,'Generated',generated,'Eligible',eligibleTotal,...
    'SourceEvaluations',evaluated,'SourceSuccesses',successes,'SourceGlobalWins',globalWins,...
    'SourceLocalGain',localGain,'SourceGlobalGain',globalGain,'FinalCredit',credit,...
    'ZeroDirections',zeroDirections,'CreditSelected',creditSelections,...
    'ExplorationReservations',explorationReservations,'SourceHistory',history);
end

function ids=selectTracing(near,far,count)
[~,a]=sort(near); [~,b]=sort(far,'descend');
raw=[a(1:ceil(count/2));b(1:floor(count/2))]; ids=zeros(count,1); n=0;
for k=1:numel(raw)
    if ~any(ids(1:n)==raw(k)), n=n+1; ids(n)=raw(k); end
end
for k=1:numel(near)
    if n==count, break, end
    if ~any(ids(1:n)==k), n=n+1; ids(n)=k; end
end
end

function [chosen,creditPicked,reserved]=selectPool(pool,eligible,best,center,quota,N,credit,method,stream)
rows=find(eligible); points=pool(rows,:); parents=ceil(rows/4); sources=mod(rows-1,4)+1;
near=sum((points-best).^2,2); far=sum((points-center).^2,2);
counts=zeros(N,1); used=false(numel(rows),1); selected=zeros(quota,1); n=0;
creditPicked=zeros(1,4); reserved=0;
if quota==0, chosen=zeros(0,1); return, end
if strcmp(method,'random')
    order=randperm(stream,numel(rows))';
    [selected,used,counts,n]=take(order,quota,selected,used,counts,n,parents);
else
    if ismember(method,{'credit','reserved'})
        % One real Range opportunity per round. Choose its geometry fairly;
        % remaining opportunities sort by learned credit, then near/far.
        range=find(sources==4); [~,idx]=sort(far(range),'descend');
        [selected,used,counts,n]=take(range(idx),1,selected,used,counts,n,parents);
        reserved=n;
        weights=zeros(numel(rows),1);
        if strcmp(method,'credit'), weights=reshape(credit(sources),[],1); end
        [~,a]=sortrows([-weights near],[1 2]);
        [~,b]=sortrows([-weights -far],[1 2]);
    else
        [~,a]=sort(near); [~,b]=sort(far,'descend');
    end
    nearTarget=n+ceil((quota-n)/2);
    before=n;
    [selected,used,counts,n]=take(a,nearTarget,selected,used,counts,n,parents);
    [selected,used,counts,n]=take(b,quota,selected,used,counts,n,parents);
    if strcmp(method,'credit')
        creditPicked=accumarray(sources(selected(before+1:n)),1,[4 1])';
    end
end
assert(n==quota,'Seeking selector did not fill available quota');
chosen=rows(selected(1:n));
end

function [selected,used,counts,n]=take(order,target,selected,used,counts,n,parents)
for index=order'
    if n>=target, break, end
    parent=parents(index);
    if ~used(index) && counts(parent)<2
        n=n+1; selected(n)=index; used(index)=true; counts(parent)=counts(parent)+1;
    end
end
end
