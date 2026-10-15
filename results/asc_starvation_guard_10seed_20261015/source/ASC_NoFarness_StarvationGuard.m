function [Best,T,info]=ASC_NoFarness_StarvationGuard(f,state,~,N,seed)
%ASC_NOFARNESS_STARVATIONGUARD  Verified-exemplar learning with an evaluation
%starvation guard, on the frozen ASC-NoFarness search core, standalone file.
%
% Motivation.  The stage-scheduled screen showed two things.  The cognitive
% direction (the particle's own evaluated personal best plus an evaluated elite)
% raises the share of real evaluations that improve a particle's record from
% 4.05% to 8.27%, but it also degrades how evenly the real evaluations cover the
% population: the share of particles more than 100 rounds without a real
% evaluation grows from 0.001% to 2.41%, the largest evaluation gap from 94 to
% 842 rounds, and the per-1000-evaluation particle coverage falls from 99.999%
% to 97.56%.  In a sparse-evaluation framework a particle that is never
% evaluated keeps moving on stale information.  This file tests whether
% spending one of the existing ten evaluation slots on the longest-starved
% particle repairs that degradation, and whether it changes final performance.
%
% guardRounds:
%   0    guard disabled; the search path is bit-identical to this file with no
%        guard, and to ASC_NoFarness when the schedule is also 'C00'
%   K>0  when some particle has gone at least K rounds since its last real
%        evaluation, one of the round's ten slots is reserved for that
%        particle's best candidate before the usual geometry screening fills
%        the rest.  The reserved slot is taken from the same fixed budget, so
%        no schedule ever consumes more than 100,000 evaluations.
%
% The guard changes only where an evaluation is spent, never how many, and it
% changes nothing at all while the coverage is healthy.  That makes it a
% single-factor comparison against the unguarded run, and it can be combined
% with the learning schedule without touching any search formula.
%
% Research question.  The earlier verified-exemplar screen showed that giving
% Tracing the particle's own evaluated personal best in addition to an evaluated
% elite raises the share of real evaluations that improve a particle's record
% from 3.97% to 8.49% and cuts the F1 error by three orders of magnitude, but
% that the advantage is built up early and then decays, with F3/F17/F29 and F27
% ending worse than the original.  This file therefore tests *when* the
% cognitive direction should be active, not how strong it should be.
%
% learnSchedule:
%   'C00'  social learning for the whole budget; bit-identical to ASC_NoFarness
%   'C11'  cognitive + social learning for the whole budget
%   'C01'  social first, cognitive + social after `switchProgress` of the real
%          evaluation budget
%   'C10'  cognitive + social first, social only afterwards
%
% Two properties of the design matter for interpretation.
%
%   1. Matched expected weight.  The social update is w*v + 2*rand.*(e - x),
%      whose expected coefficient is 1.0 per dimension.  The cognitive update is
%      w*v + c1*rCog.*(pbest_i - x) + c2*rSocial.*(e - x) with c1 = c2 = 1,
%      whose expected total coefficient is also 1.0.  Only the direction is
%      split, so the comparison is not confounded by learning strength.
%   2. Isolated cognitive randomness.  The social coefficient is drawn from the
%      global stream exactly where the social update draws it, while the
%      cognitive coefficient comes from a separate RandStream that never touches
%      the global stream.  C10 is therefore bit-identical to C00 before the
%      switch point, which the audit test verifies; the earlier B1 could not
%      make that statement because it consumed an extra global draw.
%
% No velocity, personal best or Jump state is reset at the switch point, and no
% extra objective evaluation is consumed by any schedule.
%
% The optional diagnostics record, per round, which branch (Tracing/Seeking) and
% which geometry phase (near-best/far-centre) produced each real evaluation,
% whether it improved the particle's personal best or the global best, and how
% the particles displaced by Jump fared afterwards.  This version additionally
% records how unevenly the real evaluations cover the population: the share of
% particles whose last real evaluation is more than 50 or 100 rounds old, the
% share of particles evaluated at least once inside each 1000-evaluation window,
% and the normalised spread of the personal-best positions.  None of this
% consumes objective evaluations or global random numbers.
%
% The ASC-NoFarness baseline description below is quoted unchanged from
% ASC_NoFarness.m.
%
%ASC_NOFARNESS  ASC-CSO with the farness coupling removed, standalone file.
%
% This is the ASC-NoFarness preset that ranked first in the ASC family in two
% independent rounds (results/asc_main5_20261015_090201 and
% results/asc_enh2_20261015_103033), extracted from ASC_CSO.m into its own
% file.  The framework below is byte-identical to the one in ASC_CSO.m; the
% only behavioural difference is the default traceBoostGain = 0, which
% removes the coupling between the global best's distance from the swarm
% centre ("farness") and the seek probability.  In the base preset that line
% reads
%
%     pSeek = pSeek*(1 - 0.60*farness)
%
% and never showed a significant positive sign on the benchmark, so here the
% gain is zero and pSeek is driven by the adaptive slowness control alone.
%
% Design brief (inherited unchanged from ASC_CSO.m):
%   * No sparse two-track budget split and no Q-gated quota controller.  Every
%     round the WHOLE population moves and generates candidates; the geometry
%     screening then selects a fixed number of positions to evaluate
%     (default 10).
%   * No real-position anchors.  There is a single position array and a single
%     fitness record per particle.  A particle's record is updated only when
%     that particle is actually evaluated; there is no separate "last verified
%     position" to fall back to, and no rollback on failure.
%   * The elite displacement previously used by the seeking model is replaced
%     by an adaptive mechanism (radius and seek probability driven by
%     convergence speed, plus a jump-out on stagnation).
%   * Geometry screening is the only mechanism carried over from SAQ-CSO.
%
% Switchable enhancers, each off by default and each consuming no random
% numbers when disabled (same as in ASC_CSO.m):
%   useGroup    sub-swarm search with progressive merging
%   useOBL      opposition-based learning candidates
%   seekNoise   'gaussian' seeking perturbation instead of uniform
%   useGaussBest  candidates drawn from a Gaussian around the global best
%
% Reproducibility note: with all switches off the random stream is exactly
% the one the published ASC-NoFarness records were produced from.  Any
% tunable below may be overridden through a field of the same name on
% `state`.  A `state.variant` field is accepted but ignored; this file has
% exactly one preset.
%
% [Best,T,info] = ASC_NoFarness(f,state,[],N,seed)
%
% Required state fields: initialPopulation, lowerBound, upperBound,
% maxEvaluations.  Verified by tools/verify_asc_nofarness.m against
% results/asc_enh2_20261015_103033/runs.csv.

p=ascDefaults();
fn=fieldnames(p);
for k=1:numel(fn)
    if isfield(state,fn{k}),p.(fn{k})=state.(fn{k});end
end

p.learnSchedule=fieldOr(state,'learnSchedule','C00');
p.switchProgress=fieldOr(state,'switchProgress',0.50);
p.cognitiveShare=fieldOr(state,'cognitiveShare',0.50);
p.cogSeedOffset=fieldOr(state,'cogSeedOffset',7777777);
p.guardRounds=fieldOr(state,'guardRounds',0);
assert(ismember(p.learnSchedule,{'C00','C11','C01','C10'}), ...
    'StarvationGuard:Schedule','Unknown learnSchedule.');
assert(isscalar(p.switchProgress)&&p.switchProgress>0&&p.switchProgress<1, ...
    'StarvationGuard:Switch','switchProgress must lie strictly inside (0,1).');
assert(isscalar(p.cognitiveShare)&&p.cognitiveShare>0&&p.cognitiveShare<1, ...
    'StarvationGuard:Share','cognitiveShare must lie strictly inside (0,1).');
assert(isscalar(p.cogSeedOffset)&&p.cogSeedOffset==floor(p.cogSeedOffset) ...
    &&p.cogSeedOffset>=0,'StarvationGuard:Seed','cogSeedOffset must be a non-negative integer.');
assert(isscalar(p.guardRounds)&&p.guardRounds==floor(p.guardRounds)&&p.guardRounds>=0, ...
    'StarvationGuard:Rounds','guardRounds must be a non-negative integer.');
state.ASC=p;

[Best,T,info]=ASC_NoFarness_Framework(f,state,N,seed);
info.Variant=['ASC-NoFarness-' p.learnSchedule];
end

function [Best,T,info]=ASC_NoFarness_Framework(f,state,N,seed)
p=state.ASC;
schedule=p.learnSchedule;
% The cognitive coefficient is drawn from its own stream so that it can never
% shift the global stream the search logic uses.  Constructing a RandStream does
% not consume global random numbers, so the C00 path stays identical to the
% original algorithm even though the stream always exists.
cogStream=RandStream('mt19937ar','Seed',mod(seed+p.cogSeedOffset,2^32));
switchStarted=false;switchFE=NaN;cogEvaluations=0;
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

% --- evaluation-branch diagnostics ---------------------------------------
% Bookkeeping only: no objective evaluation and no random number is consumed
% by filling these fields, so the search path of every mode is unchanged.
diag=struct( ...
    'EvalTrace',0,'EvalSeek',0,'ImpPbestTrace',0,'ImpPbestSeek',0, ...
    'ImpGlobalTrace',0,'ImpGlobalSeek',0, ...
    'EvalNear',0,'EvalFar',0,'ImpPbestNear',0,'ImpPbestFar',0, ...
    'ImpGlobalNear',0,'ImpGlobalFar',0, ...
    'GapSum',0,'GapN',0,'GapMax',0,'LastEvalRound',zeros(N,1), ...
    'JumpEvents',0,'JumpStallSum',0,'JumpVictims',0, ...
    'JumpVictimRecovered',0,'JumpVictimPending',zeros(N,1), ...
    'Cov50Sum',0,'Cov100Sum',0,'CovRounds',0, ...
    'SpreadSum',0,'SpreadRounds',0, ...
    'WinCovSum',0,'WinCovN',0, ...
    'GuardEvaluations',0,'ImpPbestGuard',0,'ImpGlobalGuard',0);
% Window bookkeeping for the coverage diagnostics: a window is 1000 real
% evaluations counting from the end of initialisation.
winMark=diag.LastEvalRound;winStart=fe;

maxRounds=ceil((budget-fe)/max(1,E0))+2;
roundLog=zeros(maxRounds,15);
diagLog=zeros(maxRounds,12);
stageLog=zeros(maxRounds,1);
pool=zeros(maxCand,D); owner=zeros(maxCand,1);
roundIndex=0; role=zeros(N,1);
pSeek=p.seekProbFixed; rad=p.radiusFixed; farness=NaN;
nGroupsNow=numel(unique(groupOf));

while fe<budget
    roundIndex=roundIndex+1;
    roundBeforeFE=fe;
    diagBefore=[diag.EvalTrace,diag.EvalSeek,diag.EvalNear,diag.EvalFar, ...
        diag.ImpPbestTrace,diag.ImpPbestSeek,diag.ImpPbestNear,diag.ImpPbestFar, ...
        diag.ImpGlobalTrace,diag.ImpGlobalSeek,diag.ImpGlobalNear,diag.ImpGlobalFar];
    progress=(fe-N)/max(1,budget-N);
    quota=min(E0,budget-fe);
    % --- which learning rule is active in this round -----------------------
    % The switch is decided once per round from the real-evaluation progress,
    % and nothing is reset when it happens: velocities, personal bests and the
    % Jump clock all carry over unchanged.
    switch schedule
        case 'C00'
            useCog=false;
        case 'C11'
            useCog=true;
        case 'C01'
            useCog=progress>=p.switchProgress;
        otherwise
            useCog=progress<p.switchProgress;
    end
    if useCog&&~switchStarted,switchStarted=true;switchFE=fe;end
    stageLog(roundIndex)=double(useCog);
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
            range,rad,pSeek,inertia,Vmax,vel,lb,ub,oblDims,maxCand,progress,Best,useCog,cogStream);
    else
        [~,ord]=sort(pbestCost);
        elites=ord(1:eliteCount);
        m=0;
        for i=1:N
            eliteVector=pbest(elites(randi(eliteCount)),:);
            [pool,owner,m,vel,role]=emitParticleCandidates(p,pool,owner,m,vel,role,i,pop, ...
                eliteVector,range,rad,pSeek,K,seekDims,D,lb,ub,inertia,Vmax,oblDims,Best,progress, ...
                pbest,useCog,cogStream);
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
        [sel,newRow,screenPhase]=geometryScreen(pool(1:m,:),owner(1:m),Best.Vector,center, ...
            quota,N,cap,diag.LastEvalRound,roundIndex,p.guardRounds);
        assert(numel(sel)==quota,'Screening returned %d positions for a quota of %d.',numel(sel),quota);
    elseif p.useGroup
        sel=zeros(0,1); newRow=zeros(N,1); screenPhase=zeros(0,1);
        nG=numel(groupRowStart);
        base=floor(quota/nG); rem=mod(quota,nG);
        qg=base*ones(nG,1); qg(1:rem)=qg(1:rem)+1;
        for g=1:nG
            rg=groupRowStart(g):groupRowEnd(g);
            if isempty(rg) || qg(g)==0, continue; end
            [selL,newRowL,phaseL]=geometryScreen(pool(rg,:),owner(rg),groupBestVec(g,:), ...
                groupCentre(g,:),qg(g),N,cap,diag.LastEvalRound,roundIndex,p.guardRounds);
            sel=[sel; rg(1)-1+selL]; %#ok<AGROW>
            screenPhase=[screenPhase; phaseL]; %#ok<AGROW>
            nz=find(newRowL>0);
            newRow(nz)=rg(1)-1+newRowL(nz);
        end
    else
        [sel,newRow,screenPhase]=geometryScreen(pool(1:m,:),owner(1:m),Best.Vector,center, ...
            quota,N,cap,diag.LastEvalRound,roundIndex,p.guardRounds);
        assert(numel(sel)==quota,'Screening returned %d positions for a quota of %d.',numel(sel),quota);
    end
    assert(numel(sel)<=quota,'Screenings returned more positions than the quota.');
    for i=1:N
        r=newRow(i);
        if r>0, pop(i,:)=pool(r,:); end
    end

    % --- evaluate exactly `quota` positions ------------------------------
    improved=false;
    for k=1:numel(sel)
        r=sel(k); i=owner(r); x=pool(r,:);
        v=f(x); fe=fe+1;
        cost(i)=v;
        betterPbest=v<pbestCost(i);
        if betterPbest, pbest(i,:)=x; pbestCost(i)=v; end
        betterGlobal=v<Best.Cost;
        if betterGlobal, Best.Cost=v; Best.Vector=x; improved=true; end
        T(fe)=Best.Cost;
        % --- where did this real evaluation come from, and did it pay off ---
        traceBranch=role(i)==1;
        nearPhase=screenPhase(k)==1;
        guardPhase=screenPhase(k)==3;
        if traceBranch, diag.EvalTrace=diag.EvalTrace+1; else, diag.EvalSeek=diag.EvalSeek+1; end
        if guardPhase
            diag.GuardEvaluations=diag.GuardEvaluations+1;
        elseif nearPhase
            diag.EvalNear=diag.EvalNear+1;
        else
            diag.EvalFar=diag.EvalFar+1;
        end
        if betterPbest
            if traceBranch, diag.ImpPbestTrace=diag.ImpPbestTrace+1; else, diag.ImpPbestSeek=diag.ImpPbestSeek+1; end
            if guardPhase
                diag.ImpPbestGuard=diag.ImpPbestGuard+1;
            elseif nearPhase
                diag.ImpPbestNear=diag.ImpPbestNear+1;
            else
                diag.ImpPbestFar=diag.ImpPbestFar+1;
            end
            if diag.JumpVictimPending(i)>0
                diag.JumpVictimPending(i)=0; diag.JumpVictimRecovered=diag.JumpVictimRecovered+1;
            end
        end
        if betterGlobal
            if traceBranch, diag.ImpGlobalTrace=diag.ImpGlobalTrace+1; else, diag.ImpGlobalSeek=diag.ImpGlobalSeek+1; end
            if guardPhase
                diag.ImpGlobalGuard=diag.ImpGlobalGuard+1;
            elseif nearPhase
                diag.ImpGlobalNear=diag.ImpGlobalNear+1;
            else
                diag.ImpGlobalFar=diag.ImpGlobalFar+1;
            end
        end
        gap=roundIndex-diag.LastEvalRound(i);
        diag.LastEvalRound(i)=roundIndex;
        diag.GapSum=diag.GapSum+gap; diag.GapN=diag.GapN+1; diag.GapMax=max(diag.GapMax,gap);
    end
    assert(fe<=budget,'Budget exceeded.');
    if useCog, cogEvaluations=cogEvaluations+numel(sel); end

    % --- coverage diagnostics: how evenly the real evaluations landed ----
    % These measure the population side of sparse evaluation: a particle whose
    % last real evaluation is many rounds old is moving on stale information.
    gapRounds=roundIndex-diag.LastEvalRound;
    diag.Cov50Sum=diag.Cov50Sum+sum(gapRounds>50)/N;
    diag.Cov100Sum=diag.Cov100Sum+sum(gapRounds>100)/N;
    diag.CovRounds=diag.CovRounds+1;
    pbestCentre=mean(pbest,1);
    diag.SpreadSum=diag.SpreadSum+mean(sqrt(sum((pbest-pbestCentre).^2,2)))/norm(range);
    diag.SpreadRounds=diag.SpreadRounds+1;
    if fe-winStart>=1000
        diag.WinCovSum=diag.WinCovSum+sum(diag.LastEvalRound>winMark)/N;
        diag.WinCovN=diag.WinCovN+1;
        winMark=diag.LastEvalRound;winStart=fe;
    end

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
                % Count each displaced particle once, not once per jump, so the
                % recovered/pending split stays a partition of this field.
                if ~diag.JumpVictimPending(i)
                    diag.JumpVictims=diag.JumpVictims+1;
                end
                diag.JumpVictimPending(i)=1;
            end
            jumpCount=jumpCount+1; jumpRounds(end+1)=roundIndex; %#ok<AGROW>
            jumped=true;
            diag.JumpEvents=diag.JumpEvents+1;
            diag.JumpStallSum=diag.JumpStallSum+(fe-lastImproveFE);
        end
        stall=0; lastImproveFE=fe;
    end

    roundLog(roundIndex,:)=[roundBeforeFE,fe,quota,pSeek,rad,sNorm,farness, ...
        succRate,stall,double(jumped),sum(role==1),sum(role==2),numel(sel), ...
        nGroupsNow,mergeStage];
    diagLog(roundIndex,:)=[diag.EvalTrace,diag.EvalSeek,diag.EvalNear,diag.EvalFar, ...
        diag.ImpPbestTrace,diag.ImpPbestSeek,diag.ImpPbestNear,diag.ImpPbestFar, ...
        diag.ImpGlobalTrace,diag.ImpGlobalSeek,diag.ImpGlobalNear,diag.ImpGlobalFar]-diagBefore;
end

T=T(1:fe);
diag.CoverageOver50=diag.Cov50Sum/max(1,diag.CovRounds);
diag.CoverageOver100=diag.Cov100Sum/max(1,diag.CovRounds);
diag.WindowCoverage=diag.WinCovSum/max(1,diag.WinCovN);
diag.PbestSpread=diag.SpreadSum/max(1,diag.SpreadRounds);
info=struct( ...
    'Algorithm','ASC-NoFarness-StarvationGuard', ...
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
    'LearnSchedule',schedule, ...
    'SwitchProgress',p.switchProgress, ...
    'SwitchFE',switchFE, ...
    'SwitchStarted',switchStarted, ...
    'CognitiveShare',p.cognitiveShare, ...
    'CogSeedOffset',p.cogSeedOffset, ...
    'GuardRounds',p.guardRounds, ...
    'CogEvaluations',cogEvaluations, ...
    'StageLog',stageLog(1:roundIndex), ...
    'Diagnostics',diag, ...
    'DiagLog',diagLog(1:roundIndex,:), ...
    'DiagLogColumns',{{'EvalTrace','EvalSeek','EvalNear','EvalFar', ...
        'ImpPbestTrace','ImpPbestSeek','ImpPbestNear','ImpPbestFar', ...
        'ImpGlobalTrace','ImpGlobalSeek','ImpGlobalNear','ImpGlobalFar'}}, ...
    'RoundLog',roundLog(1:roundIndex,:), ...
    'RoundLogColumns',{{'BeforeFE','AfterFE','Quota','SeekProb','Radius', ...
        'Slowness','Farness','SuccessRate','StallRounds','Jumped', ...
        'TracingCount','SeekingCount','Evaluated','Groups','MergeStage'}});
end


function [pool,owner,m,vel,role]=emitParticleCandidates(p,pool,owner,m,vel,role,i,pop, ...
    eliteVector,range,rad,pSeek,K,seekDims,D,lb,ub,inertia,Vmax,oblDims,Best,progress, ...
    pbest,useCog,cogStream)
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
    trialVelocity=tracingVelocity(p,inertia,vel(i,:),pop(i,:),pbest(i,:), ...
        eliteVector,D,useCog,cogStream);
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
    oblDims,maxCand,progress,Best,useCog,cogStream)
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
    groupEliteIdx=mem(o(1:ec));
    groupElites=pbest(groupEliteIdx,:);
    rowStart(g)=m+1;
    for t=1:numel(mem)
        i=mem(t);
        eliteVector=groupElites(randi(size(groupElites,1)),:);
        [pool,owner,m,vel,role]=emitParticleCandidates(p,pool,owner,m,vel,role,i,pop, ...
            eliteVector,range,rad,pSeek,K,seekDims,D,lb,ub,inertia,Vmax,oblDims,Best,progress, ...
            pbest,useCog,cogStream);
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


function [sel,newRow,phase]=geometryScreen(pool,owner,best,center,quota,N,cap, ...
    lastEvalRound,roundIndex,guardRounds)
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
%
% The third output labels every selected row with the phase that picked it,
% 1 = closest to the current best (including the fallback sweep), 2 = furthest
% from the population centre.  It is diagnostic only and adds no cost.
%
% The starvation guard is a fourth possibility, phase 3: before the two-phase
% sweep runs, one slot is reserved for the particle that has waited longest for
% a real evaluation, provided it has waited at least `guardRounds` rounds.  The
% reserved slot comes out of the same fixed quota, so no schedule ever spends
% more than the budget.  With guardRounds = 0 the guard never fires and the
% routine behaves exactly as the unguarded screening.

M=size(pool,1);
sel=zeros(quota,1); n=0; newRow=zeros(N,1); phase=zeros(quota,1);
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
guardRow=0;
if guardRounds>0&&quota>=3
    hunger=roundIndex-lastEvalRound;
    [maxHunger,hungryIdx]=max(hunger);
    if maxHunger>=guardRounds
        rows=find(owner==hungryIdx);
        if ~isempty(rows)
            [~,j]=min(dB(rows));
            guardRow=rows(j);
        end
    end
end
if guardRow>0
    n=1; sel(1)=guardRow; taken(guardRow)=true; phase(1)=3;
    cnt(owner(guardRow))=cnt(owner(guardRow))+1;
end
targetNear=ceil((quota-n)/2);
for idx=oNear'
    if n>=targetNear, break, end
    pp=owner(idx);
    if ~taken(idx) && cnt(pp)<cap
        taken(idx)=true; cnt(pp)=cnt(pp)+1; n=n+1; sel(n)=idx; phase(n)=1;
    end
end
for idx=oFar'
    if n>=quota, break, end
    pp=owner(idx);
    if ~taken(idx) && cnt(pp)<cap
        taken(idx)=true; cnt(pp)=cnt(pp)+1; n=n+1; sel(n)=idx; phase(n)=2;
    end
end
if n<quota
    for idx=oNear'
        if n>=quota, break, end
        if ~taken(idx)
            taken(idx)=true; n=n+1; sel(n)=idx; phase(n)=1;
        end
    end
end
sel=sel(1:n); phase=phase(1:n);

score=rankNear+rankFar;
bestScore=inf(N,1);
for idx=1:M
    pp=owner(idx);
    if score(idx)<bestScore(pp)
        bestScore(pp)=score(idx); newRow(pp)=idx;
    end
end
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


function trialVelocity=tracingVelocity(p,inertia,vel_i,x_i,pbest_i,eliteVector,D, ...
    useCog,cogStream)
%TRACINGVELOCITY  The Tracing velocity update, isolated so it can be replayed.
%
% The social-only branch reproduces the original expression exactly, including
% the single rand(1,D) draw, so routing the update through this helper cannot
% change the published ASC-NoFarness trajectory.  The cognitive branch keeps that
% same global draw for its social term and takes the cognitive coefficient from
% the dedicated stream, which never touches the global stream.  The two
% coefficients sum to 2, so the expected total learning weight per dimension is
% 1.0 in both branches and the comparison isolates the learning direction.
if ~useCog
    trialVelocity=inertia*vel_i+2*rand(1,D).*(eliteVector-x_i);
    return
end
c1=2*p.cognitiveShare;
c2=2*(1-p.cognitiveShare);
rSocial=rand(1,D);
rCog=rand(cogStream,1,D);
trialVelocity=inertia*vel_i+c1*rCog.*(pbest_i-x_i)+c2*rSocial.*(eliteVector-x_i);
end


function v=fieldOr(s,key,default)
if isstruct(s)&&isfield(s,key),v=s.(key);else,v=default;end
end
