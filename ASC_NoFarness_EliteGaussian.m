function [Best,T,info]=ASC_NoFarness_EliteGaussian(f,state,~,N,seed)
% Protected sparse probe: A0 original; A1 multi-elite uniform;
% A2 gbest Gaussian; A3 multi-elite Gaussian. No Q-learning.
% A0 preserves all original objective points and RNG behaviour.

p=ascDefaults();
fn=fieldnames(p);
for k=1:numel(fn)
    if isfield(state,fn{k}),p.(fn{k})=state.(fn{k});end
end
p.probeVariant=fieldOr(state,'probeVariant','A0');
p.probeEveryRounds=fieldOr(state,'probeEveryRounds',5);
p.probeDims=fieldOr(state,'probeDims',5);
p.probeSigmaStart=fieldOr(state,'probeSigmaStart',.05);
p.probeSigmaEnd=fieldOr(state,'probeSigmaEnd',.005);
p.probeSeed=fieldOr(state,'probeSeed',mod(seed+9100001,2^32));
assert(ismember(p.probeVariant,{'A0','A1','A2','A3'}));
assert(isscalar(p.probeEveryRounds)&&p.probeEveryRounds>=1&&p.probeEveryRounds==floor(p.probeEveryRounds));
assert(isscalar(p.probeDims)&&p.probeDims>=1&&p.probeDims==floor(p.probeDims));
assert(isfinite(p.probeSigmaStart)&&isfinite(p.probeSigmaEnd)&&p.probeSigmaStart>=0&&p.probeSigmaEnd>=0);
assert(~p.useGroup&&~p.useOBL&&~p.useGaussBest,'This experiment fixes the original single-population settings.');
state.ASC=p;

[Best,T,info]=ASC_NoFarness_EliteGaussian_Framework(f,state,N,seed);
info.Variant=['ASC-Probe-' p.probeVariant];
end

function [Best,T,info]=ASC_NoFarness_EliteGaussian_Framework(f,state,N,seed)
p=state.ASC;
clockStart=tic;

pop=state.initialPopulation;
[N0,D]=size(pop);
assert(N0==N,'Population size mismatch: state holds %d rows, N=%d.',N0,N);
lb=state.lowerBound; ub=state.upperBound; budget=state.maxEvaluations;
range=ub-lb;
E0=p.evaluationsPerRound;
K=p.seekCandidateCount;
assert(K>=1 && E0>=1 && budget>N);
assert(N>=E0,'Population must be at least as large as the per-round evaluation quota.');
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
rng(seed,'twister');

Vmax=0.2*range;
seekDims=max(1,round(p.seekDimFraction*D));
eliteCount=max(2,ceil(p.eliteFraction*N));
cap=p.perOwnerCap;
oblDims=max(1,round(p.oblDimFraction*D));
maxCand=N*(K+2);

T=nan(budget,1);
cost=zeros(N,1);
pbest=pop; pbestCost=zeros(N,1);
Best.Cost=inf; Best.Vector=pop(1,:);
fe=0;
for i=1:N
    v=f(pop(i,:));
    cost(i)=v; pbestCost(i)=v; pbest(i,:)=pop(i,:);
    if v<Best.Cost, Best.Cost=v; Best.Vector=pop(i,:); end
    T(i)=Best.Cost;
end
fe=N;
vel=0.01*(2*rand(N,D)-1).*range;

% --- sub-swarm bookkeeping ------------------------------------------------
groupOf=ones(N,1);
nGroups0=1;
maxMergeStages=0;
if p.useGroup
    nGroups0=min(p.groupCount,N);
    edges=round(linspace(0,N,nGroups0+1));
    for g=1:nGroups0
        groupOf(edges(g)+1:edges(g+1))=g;
    end
    nGroups0=numel(unique(groupOf));
    maxMergeStages=max(0,ceil(log2(nGroups0)));
end
mergeStage=0; lastMergeFE=fe;

% adaptive-control state
sNorm=0;                                  % 0 = converging fast, 1 = stalled
succBuf=zeros(p.convWindowRounds,1); bufPtr=0; bufCount=0;
stall=0; lastImproveFE=fe; jumpCount=0; jumpRounds=[];
if strcmp(p.jumpUnit,'generation')
    jumpUnitFE=N;                         % one generation = one full sweep
else
    jumpUnitFE=1;                         % one generation = one round
end
jumpTriggerFE=p.jumpGens*jumpUnitFE;

maxRounds=ceil((budget-fe)/max(1,E0))+2;
roundLog=zeros(maxRounds,18);
probeRng=RandStream('mt19937ar','Seed',p.probeSeed);
maxProbes=ceil(maxRounds/p.probeEveryRounds);probeCount=0;probeLog=zeros(maxProbes,15);
probePoints=zeros(maxProbes,D);probeAnchors=zeros(maxProbes,D);probeDimsLog=zeros(maxProbes,min(D,p.probeDims));
probePrePositions=zeros(maxProbes,D);probePostPositions=zeros(maxProbes,D);probePostVelocity=zeros(maxProbes,D);
probeAnchorEligible=false(maxProbes,1);
pool=zeros(maxCand,D); owner=zeros(maxCand,1);
roundIndex=0; role=zeros(N,1);
pSeek=p.seekProbFixed; rad=p.radiusFixed; farness=NaN;
nGroupsNow=numel(unique(groupOf));

while fe<budget
    roundIndex=roundIndex+1;
    roundBeforeFE=fe;
    progress=(fe-N)/max(1,budget-N);
    quota=min(E0,budget-fe);
    center=mean(pop,1);
    % --- adaptive probability and radius ---------------------------------
    % The drift measures are computed on every round so that the round log is
    % comparable between the adaptive and fixed ablations; only their effect on
    % pSeek is switched off.
    spreadVec=sqrt(sum((pop-center).^2,2));
    spread=max(mean(spreadVec),1e-9*norm(range));
    dRatio=norm(Best.Vector-center)/spread;
    farness=min(1,max(0,(dRatio-p.farLow)/(p.farHigh-p.farLow)));
    % slowness -> control input.  slownessInvert flips the mapping so that a
    % fast phase widens the seeking radius and a slow phase narrows it; that
    % direction is kept switchable because it is an empirical question which
    % way round helps, not a matter of definition.
    if p.slownessInvert, sEff=1-sNorm; else, sEff=sNorm; end
    if p.useAdaptiveProb
        pSeek=p.seekProbMin+(p.seekProbMax-p.seekProbMin)*sEff;
        pSeek=pSeek*(1-p.traceBoostGain*farness);
    else
        pSeek=p.seekProbFixed;
    end
    if p.useAdaptiveRadius
        rad=p.radiusMin+(p.radiusMax-p.radiusMin)*sEff;
    else
        rad=p.radiusFixed;
    end
    pSeek=min(1,max(0,pSeek));

    % --- progressive sub-swarm merging -----------------------------------
    % Fires on a progress milestone or on a long stagnation, whichever comes
    % first.  The stall clock starts from the later of the last improvement and
    % the last merge, so a merge buys a full quiet period before the next one.
    if p.useGroup && mergeStage<maxMergeStages
        genSinceChange=(fe-max(lastImproveFE,lastMergeFE))/N;
        sched=p.groupMergeProg(min(mergeStage+1,numel(p.groupMergeProg)));
        if progress>=sched || genSinceChange>=p.mergeStallGens
            target=max(1,round(nGroups0/2^(mergeStage+1)));
            groupOf=mergeGroups(groupOf,pop,target,D);
            mergeStage=mergeStage+1; lastMergeFE=fe;
        end
    end
    nGroupsNow=numel(unique(groupOf));

    % --- candidate generation: all particles move, every round ------------
    inertia=p.inertiaStart+(p.inertiaEnd-p.inertiaStart)*progress;
    if p.useGroup
        [pool,owner,m,groupRowStart,groupRowEnd,groupBestVec,groupCentre,role]= ...
            generateGroupCandidates(p,pop,pbest,pbestCost,groupOf,N,D,K,seekDims, ...
            range,rad,pSeek,inertia,Vmax,vel,lb,ub,oblDims,maxCand,progress,Best);
    else
        [~,ord]=sort(pbestCost);
        elites=ord(1:eliteCount);
        m=0;
        for i=1:N
            eliteVector=pbest(elites(randi(eliteCount)),:);
            [pool,owner,m,vel,role]=emitParticleCandidates(p,pool,owner,m,vel,role,i,pop, ...
                eliteVector,range,rad,pSeek,K,seekDims,D,lb,ub,inertia,Vmax,oblDims,Best,progress);
        end
    end

    % --- geometry screening picks the positions worth evaluating ----------
    if p.useGroup && strcmpi(p.groupScreen,'global')
        % Shared screening: the sub-swarms still attract to their own elites,
        % so they explore different basins, but the fixed quota is spent where
        % it is globally most promising.  Dividing the quota per group starves
        % the diversity half of the rule once the group count is large: with
        % one slot per group, ceil(1/2) hands the whole slot to the
        % closest-to-best half and no far candidate is ever evaluated.
        [sel,newRow]=geometryScreen(pool(1:m,:),owner(1:m),Best.Vector,center,quota,N,cap);
        assert(numel(sel)==quota,'Screening returned %d positions for a quota of %d.',numel(sel),quota);
    elseif p.useGroup
        sel=zeros(0,1); newRow=zeros(N,1);
        nG=numel(groupRowStart);
        base=floor(quota/nG); rem=mod(quota,nG);
        qg=base*ones(nG,1); qg(1:rem)=qg(1:rem)+1;
        for g=1:nG
            rg=groupRowStart(g):groupRowEnd(g);
            if isempty(rg) || qg(g)==0, continue; end
            [selL,newRowL]=geometryScreen(pool(rg,:),owner(rg),groupBestVec(g,:), ...
                groupCentre(g,:),qg(g),N,cap);
            sel=[sel; rg(1)-1+selL]; %#ok<AGROW>
            nz=find(newRowL>0);
            newRow(nz)=rg(1)-1+newRowL(nz);
        end
    else
        [sel,newRow]=geometryScreen(pool(1:m,:),owner(1:m),Best.Vector,center,quota,N,cap);
        assert(numel(sel)==quota,'Screening returned %d positions for a quota of %d.',numel(sel),quota);
    end
    assert(numel(sel)<=quota,'Screenings returned more positions than the quota.');
    for i=1:N
        r=newRow(i);
        if r>0, pop(i,:)=pool(r,:); end
    end

    % Every fifth round reserves one original FE after generating ordinary candidates.
    probeNow=~strcmp(p.probeVariant,'A0') && mod(roundIndex,p.probeEveryRounds)==0;
    probeOwner=0;probeAnchorIndex=0;probeDims=[];probePoint=[];probeAnchor=[];probeSigma=NaN;removed=0;
    if probeNow
        unselected=setdiff(1:N,unique([elites(:);owner(sel)]),'stable');
        assert(~isempty(unselected),'No eligible nonelite carrier.');
        [~,worst]=max(pbestCost(unselected));probeOwner=unselected(worst);
        [probePoint,probeAnchor,probeDims,probeSigma,probeAnchorIndex]=makeEliteProbe(...
            p.probeVariant,pbest,elites,Best.Vector,range,lb,ub,progress,min(D,p.probeDims),...
            p.probeSigmaStart,p.probeSigmaEnd,probeRng);
        assert(~ismember(probeOwner,elites)&&~any(owner(sel)==probeOwner));
        removed=sel(end);sel(end)=[];
    end
    normalEvaluations=numel(sel);

    % --- evaluate exactly `quota` positions ------------------------------
    improved=false;
    for k=1:numel(sel)
        r=sel(k); i=owner(r); x=pool(r,:);
        v=f(x); fe=fe+1;
        cost(i)=v;
        if v<pbestCost(i), pbest(i,:)=x; pbestCost(i)=v; end
        if v<Best.Cost, Best.Cost=v; Best.Vector=x; improved=true; end
        T(fe)=Best.Cost;
    end
    if probeNow
        probeCount=probeCount+1;beforePB=pbestCost(probeOwner);beforeBest=Best.Cost;
        probePrePositions(probeCount,:)=pop(probeOwner,:);
        v=f(probePoint);fe=fe+1;cost(probeOwner)=v;parentSuccess=v<beforePB;globalSuccess=v<beforeBest;
        if parentSuccess
            pbest(probeOwner,:)=probePoint;pbestCost(probeOwner)=v;
            pop(probeOwner,:)=probePoint;vel(probeOwner,:)=0;
        end
        if globalSuccess,Best.Cost=v;Best.Vector=probePoint;improved=true;end
        T(fe)=Best.Cost;
        probePoints(probeCount,:)=probePoint;probeAnchors(probeCount,:)=probeAnchor;probeDimsLog(probeCount,:)=probeDims;
        probePostPositions(probeCount,:)=pop(probeOwner,:);probePostVelocity(probeCount,:)=vel(probeOwner,:);
        probeAnchorEligible(probeCount)=probeAnchorIndex==0||ismember(probeAnchorIndex,elites);
        probeLog(probeCount,:)=[fe,roundIndex,probeOwner,probeAnchorIndex,probeSigma,beforePB,v,beforeBest,Best.Cost,...
            parentSuccess,globalSuccess,removed,normalEvaluations,pbestCost(probeOwner),1];
    end
    assert(normalEvaluations+double(probeNow)==quota&&fe-roundBeforeFE==quota,'Probe budget mismatch.');
    assert(fe<=budget,'Budget exceeded.');

    % --- convergence speed -> graded slowness -----------------------------
    % Slowness is driven by the share of recent rounds that improved the global
    % best.  That indicator is bounded in [0,1] by construction, so unlike a
    % rate normalised against the opening window it keeps a usable gradient
    % instead of flipping straight from 0 to 1.  The exponential smoother stops
    % the control from switching abruptly between rounds.
    bufPtr=mod(bufPtr,p.convWindowRounds)+1;
    succBuf(bufPtr)=double(improved);
    bufCount=min(bufCount+1,p.convWindowRounds);
    succRate=sum(succBuf(1:bufCount))/bufCount;
    sNorm=sNorm+p.slownessGain*((1-succRate)-sNorm);
    sNorm=min(1,max(0,sNorm));

    if improved, stall=0; lastImproveFE=fe; else, stall=stall+1; end

    % --- jump-out on stagnation ------------------------------------------
    % The clock runs on real evaluations since the last improvement, so one
    % "generation" means the whole population has been swept once
    % (jumpUnit='generation'), which puts the default 20 generations at about
    % the same 1000-evaluation scale the previous design used.
    jumped=false;
    if p.useJump && (fe-lastImproveFE)>=jumpTriggerFE
        [~,ordCost]=sort(pbestCost);
        % The single-population path keeps using the elite list that was
        % captured at the START of the round, before this round's evaluations
        % moved the personal bests.  Re-sorting here instead looks equivalent
        % but is not: it silently changes which points the jump protects, and
        % that is enough to alter the published records.  The grouped path has
        % no such round-start list, so it sorts a global one.
        if p.useGroup
            jumpElites=ordCost(1:eliteCount);
        else
            jumpElites=elites;
        end
        protect=0;
        if p.jumpProtectElites, protect=min(N-1,eliteCount); end
        victims=ordCost(protect+1:N);
        if p.jumpFraction<1 && ~isempty(victims)
            nv=max(1,round(p.jumpFraction*numel(victims)));
            victims=victims(randperm(numel(victims),nv));
        end
        if ~isempty(victims)
            eliteVectors=pbest(jumpElites,:);
            eliteNorm=sum(eliteVectors.^2,2)';
            for q=1:numel(victims)
                i=victims(q);
                S=lb+range.*rand(p.jumpSamples,D);
                d2=sum(S.^2,2)-2*(S*eliteVectors')+eliteNorm;
                [~,b]=max(min(d2,[],2));
                pop(i,:)=S(b,:);
                vel(i,:)=0;
            end
            jumpCount=jumpCount+1; jumpRounds(end+1)=roundIndex; %#ok<AGROW>
            jumped=true;
        end
        stall=0; lastImproveFE=fe;
    end

    roundLog(roundIndex,:)=[roundBeforeFE,fe,quota,pSeek,rad,sNorm,farness, ...
        succRate,stall,double(jumped),sum(role==1),sum(role==2),numel(sel), ...
        nGroupsNow,mergeStage,double(probeNow),normalEvaluations,probeOwner];
end

T=T(1:fe);
info=struct( ...
    'Algorithm','ASC-NoFarness', ...
    'Seed',seed, ...
    'Evaluations',fe, ...
    'InitialCost',T(N), ...
    'InitialPopulation',state.initialPopulation, ...
    'Seconds',toc(clockStart), ...
    'Rounds',roundIndex, ...
    'Jumps',jumpCount, ...
    'JumpRounds',jumpRounds, ...
    'GroupsInitial',nGroups0, ...
    'GroupsFinal',nGroupsNow, ...
    'MergeStages',mergeStage, ...
    'FinalSlowness',sNorm, ...
    'FinalSeekProb',pSeek, ...
    'FinalRadius',rad, ...
    'FinalFarness',farness, ...
    'Parameters',p, ...
    'ProbeVariant',p.probeVariant,'ProbeEvaluations',probeCount,...
    'ProbeParentSuccesses',sum(probeLog(1:probeCount,10)),'ProbeGlobalSuccesses',sum(probeLog(1:probeCount,11)),...
    'ProbeLog',probeLog(1:probeCount,:),'ProbePoints',probePoints(1:probeCount,:),...
    'ProbeAnchors',probeAnchors(1:probeCount,:),'ProbeDimensions',probeDimsLog(1:probeCount,:),...
    'ProbePrePositions',probePrePositions(1:probeCount,:),'ProbePostPositions',probePostPositions(1:probeCount,:),...
    'ProbePostVelocity',probePostVelocity(1:probeCount,:),'ProbeAnchorEligible',probeAnchorEligible(1:probeCount),...
    'RoundLog',roundLog(1:roundIndex,:), ...
    'RoundLogColumns',{{'BeforeFE','AfterFE','Quota','SeekProb','Radius', ...
        'Slowness','Farness','SuccessRate','StallRounds','Jumped', ...
        'TracingCount','SeekingCount','Evaluated','Groups','MergeStage','Probe','NormalEvaluated','ProbeOwner'}});
end


function [pool,owner,m,vel,role]=emitParticleCandidates(p,pool,owner,m,vel,role,i,pop, ...
    eliteVector,range,rad,pSeek,K,seekDims,D,lb,ub,inertia,Vmax,oblDims,Best,progress)
%EMITPARTICLECANDIDATES  Candidate set of one particle.
%
% Shared by the single-population and the sub-swarm paths so both use exactly
% the same tracing and seeking formulas.  Every enhancer is guarded by its own
% switch and consumes no random numbers when disabled.
if rand<pSeek
    role(i)=2;
    for j=1:K
        dims=randperm(D,seekDims);
        cand=pop(i,:);
        % seekEliteGain is zero by default: the brief asks for the elite
        % displacement inside the seeking model to be replaced by the adaptive
        % step.  The knob stays here so the cost of dropping it can be measured
        % rather than argued about.
        eliteStep=p.seekEliteGain*(eliteVector(dims)-pop(i,dims));
        if strcmp(p.seekNoise,'gaussian')
            % randn/sqrt(12) has the same variance as the uniform draw on
            % [-0.5, 0.5], so only the shape of the distribution changes.
            step=rad*range(dims).*randn(1,seekDims)/sqrt(12);
        else
            step=rad*range(dims).*(2*rand(1,seekDims)-1)/2;
        end
        cand(dims)=pop(i,dims)+eliteStep+step;
        cand=min(ub,max(lb,cand));
        m=m+1; pool(m,:)=cand; owner(m)=i;
    end
    vel(i,:)=0;
else
    role(i)=1;
    trialVelocity=inertia*vel(i,:)+2*rand(1,D).*(eliteVector-pop(i,:));
    trialVelocity=min(Vmax,max(-Vmax,trialVelocity));
    vel(i,:)=trialVelocity;
    cand=min(ub,max(lb,pop(i,:)+trialVelocity));
    m=m+1; pool(m,:)=cand; owner(m)=i;
end

% --- opposition-based candidate -----------------------------------------
% Evaluation-neutral: the opposite point only joins the pool and competes for
% the same fixed quota.
if p.useOBL && rand<p.oblProb
    dims=randperm(D,oblDims);
    opp=pop(i,:);
    opp(dims)=lb(dims)+ub(dims)-pop(i,dims);
    opp=min(ub,max(lb,opp));
    m=m+1; pool(m,:)=opp; owner(m)=i;
end

% --- Gaussian candidate around the global best --------------------------
if p.useGaussBest && rand<p.gaussBestProb
    width=p.gaussBestSigma*max(0.2,1-progress);
    cand2=Best.Vector+width*range.*randn(1,D);
    cand2=min(ub,max(lb,cand2));
    m=m+1; pool(m,:)=cand2; owner(m)=i;
end
end


function [pool,owner,m,rowStart,rowEnd,bestVec,centre,role]=generateGroupCandidates( ...
    p,pop,pbest,pbestCost,groupOf,N,D,K,seekDims,range,rad,pSeek,inertia,Vmax,vel,lb,ub, ...
    oblDims,maxCand,progress,Best)
%GENERATEGROUPCANDIDATES  Candidate set for every sub-swarm.
%
% Each group attracts to its own elite pool and screens its own share of the
% quota, which is what makes the groups search independently.  Candidates are
% laid out group by group so the caller can screen one contiguous block per
% group.
pool=zeros(maxCand,D); owner=zeros(maxCand,1);
gids=unique(groupOf);
nG=numel(gids);
rowStart=zeros(nG,1); rowEnd=zeros(nG,1);
bestVec=zeros(nG,D); centre=zeros(nG,D);
role=zeros(N,1);
m=0;
for g=1:nG
    mem=find(groupOf==gids(g));
    centre(g,:)=mean(pop(mem,:),1);
    [~,o]=sort(pbestCost(mem));
    bestVec(g,:)=pbest(mem(o(1)),:);
    ec=min(numel(mem),max(2,ceil(p.eliteFraction*numel(mem))));
    groupElites=pbest(mem(o(1:ec)),:);
    rowStart(g)=m+1;
    for t=1:numel(mem)
        i=mem(t);
        eliteVector=groupElites(randi(size(groupElites,1)),:);
        [pool,owner,m,vel,role]=emitParticleCandidates(p,pool,owner,m,vel,role,i,pop, ...
            eliteVector,range,rad,pSeek,K,seekDims,D,lb,ub,inertia,Vmax,oblDims,Best,progress);
    end
    rowEnd(g)=m;
end
end


function groupOf=mergeGroups(groupOf,pop,target,D)
%MERGEGROUPS  Repeatedly fuse the two closest sub-swarms until only `target`
%   remain.  Closeness is measured between sub-swarm centroids, so groups that
%   have converged into the same basin are the ones that join first.
while true
    gids=unique(groupOf);
    k=numel(gids);
    if k<=target, break; end
    C=zeros(k,D);
    for t=1:k
        C(t,:)=mean(pop(groupOf==gids(t),:),1);
    end
    bestD=inf; pa=1; pb=2;
    for a=1:k-1
        for b=a+1:k
            dd=sum((C(a,:)-C(b,:)).^2);
            if dd<bestD, bestD=dd; pa=a; pb=b; end
        end
    end
    groupOf(groupOf==gids(pb))=gids(pa);
    [~,~,lab]=unique(groupOf,'stable');
    groupOf=lab;
end
end


function [sel,newRow]=geometryScreen(pool,owner,best,center,quota,N,cap)
%GEOMETRYSCREEN  Pick the positions worth spending evaluations on.
%
% Two-phase greedy over the candidate pool, the only mechanism inherited from
% SAQ-CSO: the first half of the quota goes to candidates closest to the
% current best, the remainder to candidates furthest from the population
% centre.  A single particle may contribute at most `cap` positions, so the
% quota is spread over several particles instead of starving on one.
%
% Each particle's new position is the candidate that scores best under the same
% two criteria (sum of the two ranks), which keeps the population moving even
% when a particle is not selected.

M=size(pool,1);
sel=zeros(quota,1); n=0; newRow=zeros(N,1);
if M==0 || quota==0
    return
end

dB=sum((pool-best).^2,2);
dC=sum((pool-center).^2,2);
[~,oNear]=sort(dB);
[~,oFar]=sort(dC,'descend');
rankNear=zeros(M,1); rankNear(oNear)=(1:M)';
rankFar=zeros(M,1);  rankFar(oFar)=(1:M)';

cnt=zeros(N,1); taken=false(M,1);
targetNear=ceil(quota/2);
for idx=oNear'
    if n>=targetNear, break, end
    pp=owner(idx);
    if ~taken(idx) && cnt(pp)<cap
        taken(idx)=true; cnt(pp)=cnt(pp)+1; n=n+1; sel(n)=idx;
    end
end
for idx=oFar'
    if n>=quota, break, end
    pp=owner(idx);
    if ~taken(idx) && cnt(pp)<cap
        taken(idx)=true; cnt(pp)=cnt(pp)+1; n=n+1; sel(n)=idx;
    end
end
if n<quota
    for idx=oNear'
        if n>=quota, break, end
        if ~taken(idx)
            taken(idx)=true; n=n+1; sel(n)=idx;
        end
    end
end
sel=sel(1:n);

score=rankNear+rankFar;
bestScore=inf(N,1);
for idx=1:M
    pp=owner(idx);
    if score(idx)<bestScore(pp)
        bestScore(pp)=score(idx); newRow(pp)=idx;
    end
end
end

function [y,anchor,dims,sigma,anchorId]=makeEliteProbe(variant,pbest,elites,gbest,range,lb,ub,progress,k,s0,s1,stream)
% Same elite draw and dimensions in controls; the matched uniform has unit variance.
anchorId=elites(randi(stream,numel(elites)));anchor=pbest(anchorId,:);
if strcmp(variant,'A2'),anchor=gbest;anchorId=0;end
dims=randperm(stream,numel(gbest),k);sigma=s0+(s1-s0)*progress;
if strcmp(variant,'A1'),z=sqrt(3)*(2*rand(stream,1,k)-1);else,z=randn(stream,1,k);end
y=anchor;y(dims)=anchor(dims)+sigma*range(dims).*z;y=min(ub,max(lb,y));
end
function v=fieldOr(st,key,default)
if isfield(st,key),v=st.(key);else,v=default;end
end
function p=ascDefaults()
% The ASC-NoFarness preset: the recommended ASC-CSO operating point with the
% farness coupling switched off (traceBoostGain = 0).  Two independent rounds
% (main5 and enh2) ranked this configuration first in the ASC family; the
% coupling itself never showed a significant positive sign in either round.
%
% The mapping direction is the annealed one: slownessInvert = true, so wide
% seeking while the best value is still improving quickly, narrow seeking and
% more tracing once it stalls.  The enhancers (useGroup, useOBL, seekNoise,
% useGaussBest) are all off by default, exactly as in ASC_CSO.m.
p=struct( ...
    'evaluationsPerRound',10, ...
    'seekCandidateCount',4, ...
    'seekDimFraction',0.20, ...
    'radiusMin',0.020, ...
    'radiusMax',0.200, ...
    'radiusFixed',0.050, ...
    'seekProbMin',0.20, ...
    'seekProbMax',0.90, ...
    'seekProbFixed',0.40, ...
    'seekEliteGain',0, ...
    'traceBoostGain',0, ...
    'farLow',0.25, ...
    'farHigh',1.50, ...
    'convWindowRounds',100, ...
    'slownessGain',0.05, ...
    'slownessInvert',true, ...
    'eliteFraction',0.20, ...
    'perOwnerCap',2, ...
    'inertiaStart',0.90, ...
    'inertiaEnd',0.40, ...
    'useAdaptiveRadius',true, ...
    'useAdaptiveProb',true, ...
    'useJump',true, ...
    'jumpGens',20, ...
    'jumpUnit','generation', ...
    'jumpFraction',0.50, ...
    'jumpSamples',10, ...
    'jumpProtectElites',true, ...
    'logRounds',false, ...
    'useGroup',false, ...
    'groupCount',8, ...
    'groupScreen','perGroup', ...
    'groupMergeProg',[0.45 0.70 0.90], ...
    'mergeStallGens',100, ...
    'useOBL',false, ...
    'oblProb',0.20, ...
    'oblDimFraction',1.00, ...
    'seekNoise','uniform', ...
    'useGaussBest',false, ...
    'gaussBestProb',0.10, ...
    'gaussBestSigma',0.10);
end
