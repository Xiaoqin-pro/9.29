function [Best,T,info]=ASE_CSO_TPL(f,state,~,N,seed)
% ASE_CSO_TPL Evaluation-consistent sparse candidate allocation for CSO.
%
% The method keeps two ledgers separate:
%   (1) realPop/fitness: positions that have a trusted objective value;
%   (2) proposalPool/proposalAge/proposalCredit: unevaluated Seeking proposals.
% Unevaluated proposals can influence which opportunity receives a real
% evaluation, but they never update pbest, gbest, or a parent's fitness.
%
% state.tplPolicy: 'fixed', 'q', or 'random'.  The fixed policy uses a
% balanced exploitation/coverage score.  The q policy has only eight states
% (phase x last Seeking improvement x proposal freshness) and two actions:
% exploitation or coverage.  This is deliberately a small experimental
% controller; it does not change MR, the search equations, or the FE budget.

started=tic;
pop=state.initialPopulation; D=size(pop,2); lb=state.lowerBound; ub=state.upperBound;
budget=state.maxEvaluations; policy=state.tplPolicy;
alpha=.3; gamma=.9; epsilon=.1;
if isfield(state,'alpha'), alpha=state.alpha; end
if isfield(state,'gamma'), gamma=state.gamma; end
if isfield(state,'epsilon'), epsilon=state.epsilon; end
reuseProposals=true; marginalCoverage=true;
if isfield(state,'reuseProposals'), reuseProposals=logical(state.reuseProposals); end
if isfield(state,'marginalCoverage'), marginalCoverage=logical(state.marginalCoverage); end
assert(N==50 && size(pop,1)==N,'TPL-CSO uses a population of 50.');
assert(budget>=N && budget==floor(budget));
assert(ismember(policy,{'fixed','q','random'}));
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
rng(seed,'twister');

V=.01*(2*rand(N,D)-1).*(ub-lb); Vmax=.2*(ub-lb);
seekDimCount=max(1,round(.20*D)); SMP=5; proposalCount=SMP-1; maxAge=2;
T=nan(budget,1); fitness=zeros(N,1); Best=struct('Cost',inf,'Vector',pop(1,:)); fe=0;
for i=1:N
    fitness(i)=f(pop(i,:));
    if fitness(i)<Best.Cost, Best.Cost=fitness(i); Best.Vector=pop(i,:); end
    T(i)=Best.Cost;
end
fe=N; realPop=pop; personalBest=pop; personalCost=fitness;
proposalPool=zeros(N,proposalCount,D); proposalAge=(maxAge+1)*ones(N,proposalCount);
proposalCredit=zeros(N,proposalCount);
Q=zeros(8,2); previousSeekImprovement=false;
seekFE=0; traceFE=0; rounds=0; seekSuccess=0; traceSuccess=0; traceRollbacks=0;
proposalGenerated=0; proposalEvaluated=0; proposalExpired=0; parentCoverage=0; concentration=0;
actionCount=zeros(1,2); stateVisits=zeros(8,1); qUpdates=0;

while fe<budget
    rounds=rounds+1;
    progress=(fe-N)/max(1,budget-N); center=mean(pop,1); roundBest=Best.Vector;
    quota=min(10,budget-fe); eliteCount=max(2,ceil(.20*N)); [~,ord]=sort(personalCost); elites=ord(1:eliteCount);
    trial=pop; trialV=V; tracing=false(N,1);
    for i=1:N
        elite=personalBest(elites(randi(eliteCount)),:);
        if rand<.40
            tracing(i)=true;
            base=V(i,:)+2*rand(1,D).*(elite-pop(i,:));
            inertia=.9-.5*progress; trialV(i,:)=inertia*V(i,:)+base-V(i,:);
            trialV(i,:)=max(-Vmax,min(Vmax,trialV(i,:)));
            trial(i,:)=max(lb,min(ub,pop(i,:)+trialV(i,:)));
        else
            % Reuse a proposal briefly.  Expired proposals are regenerated;
            % no unevaluated proposal is assigned a fitness value.
            for s=1:proposalCount
                if ~reuseProposals || proposalAge(i,s)>=maxAge
                    dims=randperm(D,seekDimCount);
                    proposal=pop(i,:);
                    eliteStep=.25*(elite(dims)-pop(i,dims));
                    step=.025*(ub(dims)-lb(dims))*(1-progress);
                    proposal(dims)=pop(i,dims)+eliteStep+step.*(2*rand(1,seekDimCount)-1);
                    proposalPool(i,s,:)=max(lb,min(ub,proposal));
                    proposalAge(i,s)=0; proposalCredit(i,s)=0;
                    proposalGenerated=proposalGenerated+1;
                end
            end
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing);
    pop(traceIds,:)=trial(traceIds,:); V(traceIds,:)=trialV(traceIds,:);
    nTrace=min(numel(traceIds),min(4,max(1,quota-1))); nSeek=min(2*numel(seekIds),quota-nTrace);
    if nTrace>0
        dBest=sum((trial(traceIds,:)-roundBest).^2,2); dCenter=sum((trial(traceIds,:)-center).^2,2);
        traceCats=traceIds(selectTracing(dBest,dCenter,nTrace)); traceCats=traceCats(randperm(numel(traceCats)));
    else
        traceCats=[];
    end

    % Tracing evaluations use the trusted parent state.
    for i=traceCats'
        value=f(trial(i,:)); fe=fe+1; traceFE=traceFE+1;
        if value<fitness(i)
            realPop(i,:)=trial(i,:); fitness(i)=value; pop(i,:)=trial(i,:); traceSuccess=traceSuccess+1;
        else
            pop(i,:)=realPop(i,:); traceRollbacks=traceRollbacks+1;
        end
        if value<personalCost(i), personalBest(i,:)=trial(i,:); personalCost(i)=value; end
        if value<Best.Cost, Best.Cost=value; Best.Vector=trial(i,:); end
        proposalAge(i,:)=maxAge+1; proposalCredit(i,:)=0; T(fe)=Best.Cost;
    end

    if nSeek>0
        seekBestBefore=Best.Cost;
        phase=double(fe>=N+.5*(budget-N));
        freshness=double(mean(proposalAge(seekIds,:), 'all')>=.5);
        currentState=1+4*phase+2*double(previousSeekImprovement)+freshness;
        stateVisits(currentState)=stateVisits(currentState)+1;
        if strcmp(policy,'q')
            if rand<epsilon, action=randi(2); else, [~,action]=max(Q(currentState,:)); end
        elseif strcmp(policy,'fixed')
            action=0; % balanced score
        else
            action=3; % random selector
        end
        if action==1, actionCount(1)=actionCount(1)+1; end
        if action==2, actionCount(2)=actionCount(2)+1; end
        [rows,parents]=selectTPLProposals(proposalPool,proposalAge,proposalCredit,seekIds,nSeek,Best.Vector,realPop,action,proposalCount,N,marginalCoverage);
        selectedImprovement=false; selectedParents=false(N,1); counts=zeros(N,1);
        for k=1:numel(rows)
            row=rows(k); i=parents(k); s=mod(row-1,proposalCount)+1;
            value=f(reshape(proposalPool(i,s,:),1,D)); fe=fe+1; seekFE=seekFE+1; proposalEvaluated=proposalEvaluated+1;
            anchor=fitness(i); gain=max(0,anchor-value)/max(abs(anchor),eps); gain=min(1,gain);
            proposalCredit(i,s)=.9*proposalCredit(i,s)+.1*gain;
            if value<anchor, seekSuccess=seekSuccess+1; selectedImprovement=true; end
            if value<personalCost(i), personalBest(i,:)=reshape(proposalPool(i,s,:),1,D); personalCost(i)=value; end
            if value<Best.Cost, Best.Cost=value; Best.Vector=reshape(proposalPool(i,s,:),1,D); end
            if value<fitness(i), fitness(i)=value; realPop(i,:)=reshape(proposalPool(i,s,:),1,D); pop(i,:)=realPop(i,:); end
            proposalAge(i,s)=0; selectedParents(i)=true; counts(i)=counts(i)+1; T(fe)=Best.Cost;
        end
        parentCoverage=parentCoverage+nnz(selectedParents); concentration=concentration+sum((counts/nSeek).^2);
        unselectedSeek=seekIds(~selectedParents(seekIds));
        proposalAge(unselectedSeek,:)=min(maxAge+1,proposalAge(unselectedSeek,:)+1);
        previousSeekImprovement=selectedImprovement;
        if strcmp(policy,'q')
            reward=max(0,seekBestBefore-Best.Cost)/max(abs(seekBestBefore),eps);
            nextFreshness=double(mean(proposalAge(seekIds,:), 'all')>=.5);
            nextPhase=double(fe>=N+.5*(budget-N));
            nextState=1+4*nextPhase+2*double(selectedImprovement)+nextFreshness;
            Q(currentState,action)=Q(currentState,action)+alpha*(reward+gamma*max(Q(nextState,:))-Q(currentState,action));
            qUpdates=qUpdates+1;
        end
        previousSeekImprovement=selectedImprovement;
    end
    proposalExpired=proposalExpired+sum(proposalAge(:)>=maxAge+1);
end

T=T(1:fe);
info=struct('Algorithm',['TPL-CSO-' policy],'Seed',seed,'Evaluations',fe,'Seconds',toc(started),...
    'SeekingEvaluations',seekFE,'TracingEvaluations',traceFE,'Rounds',rounds,'QTable',Q,'QStateVisits',stateVisits,...
    'ActionCount',actionCount,'QUpdates',qUpdates,'MeanParentCoverage',parentCoverage/max(1,rounds),...
    'MeanConcentration',concentration/max(1,rounds),'TraceSuccesses',traceSuccess,'SeekSuccesses',seekSuccess,...
    'TraceRollbacks',traceRollbacks,'ProposalGenerated',proposalGenerated,'ProposalEvaluated',proposalEvaluated,...
    'ReuseProposals',reuseProposals,'MarginalCoverage',marginalCoverage,...
    'ProposalExpired',proposalExpired,'Alpha',alpha,'Gamma',gamma,'Epsilon',epsilon);
end

function [rows,parents]=selectTPLProposals(pool,age,credit,catIds,quota,best,anchors,action,K,N,marginalCoverage)
% Greedy set selection: marginal coverage is recomputed after each choice.
rows=zeros(quota,1); parents=zeros(quota,1); used=false(N,K); counts=zeros(N,1);
points=reshape(pool(catIds,:,:),numel(catIds)*K,size(pool,3));
ages=reshape(age(catIds,:),[],1); credits=reshape(credit(catIds,:),[],1);
parentGrid=repelem(catIds(:),K); valid=ages<=2;
if ~any(valid), error('TPL:NoProposal','No eligible Seeking proposal.'); end
anchors=anchors(catIds,:); scale=max(sum((points-mean(anchors,1)).^2,2)); scale=max(scale,eps);
promise=1-sum((points-best).^2,2)/max(sum((anchors-best).^2,2)); promise=max(0,min(1,promise));
promise=.75*promise+.25*max(0,min(1,credits));
selectedPoints=zeros(0,size(points,2)); n=0;
while n<quota
    candidates=find(valid);
    if isempty(candidates), break, end
    if action==3
        pick=candidates(randi(numel(candidates)));
    else
        novelty=zeros(size(points,1),1);
        if marginalCoverage
            novelty(:)=1;
            if ~isempty(selectedPoints)
                novelty(candidates)=min(pdist2(points(candidates,:),selectedPoints),[],2)/sqrt(scale);
            end
        end
        lambda=.5;
        if action==1, lambda=.75; elseif action==2, lambda=.25; end
        score=lambda*promise+(1-lambda)*max(0,min(1,novelty));
        score(~valid)=-inf;
        [~,pick]=max(score);
    end
    p=parentGrid(pick); local=pick;
    if counts(p)>=2
        valid(local)=false; continue
    end
    n=n+1; rows(n)=mod(local-1,K)+1; % temporary local index
    parents(n)=p; counts(p)=counts(p)+1; selectedPoints(end+1,:)=points(local,:); %#ok<AGROW>
    valid(local)=false; used(p,mod(local-1,K)+1)=true;
end
if n<quota, error('TPL:Quota','TPL selector could not fill quota.'); end
% Convert local proposal indices to parent-local proposal rows.
for q=1:quota
    parent=parents(q); offset=find(catIds==parent,1)-1;
    rows(q)=offset*K+rows(q);
end
end

function ids=selectTracing(near,far,count)
[~,a]=sort(near); [~,b]=sort(far,'descend'); raw=[a(1:ceil(count/2));b(1:floor(count/2))]; ids=zeros(count,1); k=0;
for i=1:numel(raw), if ~any(ids(1:k)==raw(i)), k=k+1; ids(k)=raw(i); end, end
for i=1:numel(near), if k==count, break, end, if ~any(ids(1:k)==i), k=k+1; ids(k)=i; end, end
end
