function [Best,T,info]=SAQ_CSO_FrameworkAblation(f,state,~,N,seed)
% ASE_CSO_ModeBudget Fixed MR=.4, only true-FE mode quota varies.
% modeTraceQuota=2/4/6 corresponds to 2T8S/4T6S/6T4S in full rounds.
% Default quota4 is bitwise equivalent to the validated B10 study entry.
% Defaults exactly reproduce B10; seekCandidateCount=2 uses SMP3;
% useSeekingElite=false removes only the Seeking elite displacement.
% Logging and accounting do not draw random numbers.
% Total FE and search equations are unchanged, but full rounds use 10 FE
% (4 tracing + 6 seeking) instead of the frozen 5-FE schedule.
% Required state fields: initialPopulation, lowerBound, upperBound,
% maxEvaluations. All search parameters are fixed; no RL or experimental
% selectors are present. Initial population generation belongs to the caller.
clockStart=tic;
% Framework ablation flags; the default path exactly reproduces frozen compact.
evaluationMode='sparse';screenPolicy='geometry';virtualTracing=true;
if isfield(state,'evaluationMode'),evaluationMode=state.evaluationMode;end
if isfield(state,'screenPolicy'),screenPolicy=state.screenPolicy;end
if isfield(state,'virtualTracing'),virtualTracing=logical(state.virtualTracing);end
assert(ismember(evaluationMode,{'sparse','dense'})&&ismember(screenPolicy,{'geometry','random'}));
isDense=strcmp(evaluationMode,'dense');screenRng=RandStream('mt19937ar','Seed',seed+4000001);

seekCandidateCount=4; useSeekingElite=true; audit=false;
if isfield(state,'seekCandidateCount'),seekCandidateCount=state.seekCandidateCount;end
if isfield(state,'useSeekingElite'),useSeekingElite=logical(state.useSeekingElite);end
if isfield(state,'auditSimplify'),audit=logical(state.auditSimplify);end
assert(ismember(seekCandidateCount,[2,4]) && isscalar(useSeekingElite));
assert(seekCandidateCount==4 && useSeekingElite,'Mode-quota study freezes B10 backbone.');
traceQuota=4;if isfield(state,'modeTraceQuota'),traceQuota=state.modeTraceQuota;end
assert(isscalar(traceQuota) && ismember(traceQuota,[2,4,6]));
policy='fixed4';if isfield(state,'modePolicy'),policy=state.modePolicy;end
assert(ismember(policy,{'fixed2','fixed4','fixed6','random','phase','epsfixed','q','gateq','gaterandom','gate2','gate4','gateeps6'}));
if isDense,assert(strcmp(policy,'fixed6'),'Dense ablation removes quota controller; compare with Sparse-Fixed6.');end
logTrajectory=false;if isfield(state,'logTrajectory'),logTrajectory=logical(state.logTrajectory);end
rewardMode='binary';if isfield(state,'modeReward'),rewardMode=state.modeReward;end
assert(ismember(rewardMode,{'binary','positive','gain'}));
stateMode='previous';if isfield(state,'modeState'),stateMode=state.modeState;end
assert(ismember(stateMode,{'previous','stagnation'}));
stagnationThreshold=1000;if isfield(state,'stagnationThreshold'),stagnationThreshold=state.stagnationThreshold;end
assert(isscalar(stagnationThreshold)&&stagnationThreshold>0);
gatedPolicy=startsWith(policy,'gate');if gatedPolicy,assert(strcmp(stateMode,'stagnation'));end
episodeFE=100;if isfield(state,'episodeFE'),episodeFE=state.episodeFE;end
assert(isscalar(episodeFE)&&ismember(episodeFE,[100,500]));
rewardBonus=1;if isfield(state,'rewardBonus'),rewardBonus=state.rewardBonus;end
assert(isscalar(rewardBonus)&&ismember(rewardBonus,[1,10]));
compactGate=false;if isfield(state,'compactGate'),compactGate=logical(state.compactGate);end
traceQuotas=[2,4,6];if isfield(state,'traceQuotas'),traceQuotas=state.traceQuotas;end
assert(ismember(numel(traceQuotas),[2,3])&&all(ismember(traceQuotas,[2,4,6]))&&numel(unique(traceQuotas))==numel(traceQuotas));
assert(~compactGate || (gatedPolicy&&episodeFE==100));actionCount=numel(traceQuotas);
policyRng=RandStream('mt19937ar','Seed',seed+3000001);
trendLog=[];lastImprovementFE=50;initialRealDiversity=NaN;
stateCount=6;if compactGate,stateCount=3;end
Q=zeros(stateCount,actionCount);QVisits=zeros(stateCount,actionCount);alpha=.1;gamma=.9;epsilon=.1;
SMP=seekCandidateCount+1;
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
if logTrajectory
    trendLog=zeros(ceil((budget-N)/100)+1,7);
    initialRealDiversity=populationDiversity(realPop,lb,ub);
end
seekEvalTotal=0; traceEvalTotal=0;
seekBuffer=zeros(N*SMP,D);
roundIndex=0; roundLog=zeros(ceil((budget-N)/10),13);
maxParentEvaluations=0;frameworkLog=zeros(ceil((budget-N)/10),7);
decisionCount=0;maxDecisions=ceil((budget-N)/100);rewardLog=zeros(maxDecisions,4);stateLog=zeros(maxDecisions,3);gateLog=zeros(maxDecisions,3);discountLog=zeros(maxDecisions,1);nextDecisionFE=N;decisionLog=zeros(maxDecisions,14);updateLog=zeros(maxDecisions,8);updateCount=0;pending=false;prevSuccess=false;blockFallback=false;
% Decision columns: BeforeFE,AfterFE,State,Action,Quota,Phase,PreviousSuccess,
% BestBefore,BestAfter,Reward,TraceFE,SeekFE,FallbackRounds,Updated.
% Update columns: State,Action,Reward,NextState,Terminal,BeforeFE,AfterFE,Eligible.
if audit,evalPoints=zeros(budget,D);evalLog=zeros(budget,9);else,evalPoints=[];evalLog=[];end
if audit
    evalPoints(1:N,:)=initialPopulation;
    evalLog(1:N,:)=[(1:N)',zeros(N,2),(1:N)',ones(N,1),inf(N,1),fitness,T(1:N),zeros(N,1)];
end
while fe<budget
    roundIndex=roundIndex+1; roundBeforeFE=fe;
    traceLocal=0; seekLocal=0; traceGlobal=0; seekGlobal=0; traceGain=0; seekGain=0;
    progress=(fe-N)/max(1,budget-N);
    if fe>=nextDecisionFE
        if logTrajectory
            trendLog(decisionCount+1,:)=[fe,populationDiversity(realPop,lb,ub),populationDiversity(pop,lb,ub),max(fitness)-min(fitness),fe-lastImprovementFE,Best.Cost,initialRealDiversity];
        end
        phase=min(2,floor(3*progress));
        if pending,prevSuccess=Best.Cost<decisionLog(decisionCount,8);end
        signal=double(~prevSuccess);
        if strcmp(stateMode,'stagnation'),signal=double(fe-lastImprovementFE>=stagnationThreshold);end
        stateId=1+2*phase+signal;if compactGate,stateId=phase+1;end
        if pending
            gain=max(0,decisionLog(decisionCount,8)-Best.Cost);
            reward=progressReward(rewardMode,gain,rewardLog(decisionCount,1));if strcmp(rewardMode,'binary')&&gain>0,reward=rewardBonus;end;rewardLog(decisionCount,2:4)=[gain,reward,Best.Cost];discountLog(decisionCount)=gamma^((fe-decisionLog(decisionCount,1))/100);eligible=~blockFallback;if gatedPolicy,eligible=eligible&&logical(gateLog(decisionCount,2));end
            if (strcmp(policy,'q')||strcmp(policy,'gateq')) && eligible
                ps=decisionLog(decisionCount,3);pa=decisionLog(decisionCount,4);
                nextValue=max(Q(stateId,:));if compactGate&&signal==0,nextValue=0;end
                Q(ps,pa)=Q(ps,pa)+alpha*(reward+discountLog(decisionCount)*nextValue-Q(ps,pa));QVisits(ps,pa)=QVisits(ps,pa)+1;decisionLog(decisionCount,14)=1;
            end
            updateCount=updateCount+1;updateLog(updateCount,:)=[decisionLog(decisionCount,3),decisionLog(decisionCount,4),reward,stateId,0,decisionLog(decisionCount,1),fe,eligible];
            decisionLog(decisionCount,9:10)=[Best.Cost,reward];
        end
        freeDecision=~gatedPolicy || signal==1;
        if gatedPolicy && ~freeDecision,action=find(traceQuotas==6);assert(isscalar(action));
        else
        switch policy
            case 'fixed2',action=find(traceQuotas==2);assert(isscalar(action));
            case 'fixed4',action=find(traceQuotas==4);assert(isscalar(action));
            case 'fixed6',action=find(traceQuotas==6);assert(isscalar(action));
            case {'random','gaterandom'},action=randi(policyRng,actionCount);
            case 'gate2',action=find(traceQuotas==2);assert(isscalar(action));
            case 'gate4',action=find(traceQuotas==4);assert(isscalar(action));
            case 'gateeps6'
                action=find(traceQuotas==6);assert(isscalar(action));if rand(policyRng)<epsilon,action=randi(policyRng,actionCount);end
            case 'phase',quota=4+2*double(phase==2);action=find(traceQuotas==quota);assert(isscalar(action));
            case 'epsfixed'
                action=find(traceQuotas==6);assert(isscalar(action));if rand(policyRng)<epsilon,action=randi(policyRng,actionCount);end
            case {'q','gateq'}
                if rand(policyRng)<epsilon,action=randi(policyRng,actionCount);
                else,winners=find(Q(stateId,:)==max(Q(stateId,:)));action=winners(randi(policyRng,numel(winners)));end
        end
        end
        traceQuota=traceQuotas(action);decisionCount=decisionCount+1;rewardLog(decisionCount,1)=max(fitness)-min(fitness);stateLog(decisionCount,:)=[fe-lastImprovementFE,signal,stateId];gateLog(decisionCount,:)=[gatedPolicy,freeDecision,action];decisionLog(decisionCount,1:8)=[fe,0,stateId,action,traceQuota,phase,prevSuccess,Best.Cost];blockFallback=false;pending=true;
        holdFE=100;if gatedPolicy&&freeDecision,holdFE=episodeFE;end
        nextDecisionFE=min(budget,fe+holdFE);
    end
    center=mean(pop,1); roundBest=Best.Vector;
    budgetThisRound=min(10,budget-fe);
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
            rows=(i-1)*SMP+(1:SMP);
            % Indexed replication avoids the temporary produced by repmat.
            seekBuffer(rows,:)=pop(i(ones(SMP,1)),:);
            for j=2:SMP
                dims=randperm(D,seekDimCount);
                eliteStep=0;
                if useSeekingElite,eliteStep=0.25*(eliteVector(dims)-pop(i,dims));end
                differenceStep=0;
                step=0.05*(ub(dims)-lb(dims))/2*(1-progress);
                seekBuffer(rows(j),dims)=pop(i,dims)+eliteStep+differenceStep+ ...
                    step.*(2*rand(1,numel(dims))-1);
                seekBuffer(rows(j),:)=max(lb,min(ub,seekBuffer(rows(j),:)));
            end
        end
    end
    traceIds=find(tracing); seekIds=find(~tracing);
    if virtualTracing,pop(traceIds,:)=trial(traceIds,:);end; V(traceIds,:)=trialVelocity(traceIds,:);
    if isDense
        availableTrace=numel(traceIds);availableSeek=(SMP-1)*numel(seekIds);
        targetTrace=min(availableTrace,budget-fe);
        targetSeek=min(availableSeek,budget-fe-targetTrace);
        traceCats=traceIds(1:targetTrace);traceCats=traceCats(randperm(numel(traceCats)));
        [seekPlan,seekCats]=DenseSeeking(seekIds,targetSeek,N,SMP);
    else
    [targetTrace,targetSeek]=AllocateBudgetMode(budgetThisRound,numel(traceIds),numel(seekIds),traceQuota);
    if targetTrace>0
        traceBest=sum((trial(traceIds,:)-Best.Vector).^2,2);
        traceCenter=sum((trial(traceIds,:)-center).^2,2);
        if strcmp(screenPolicy,'geometry')
            traceCats=traceIds(SelectTracingLean(traceBest,traceCenter,targetTrace));
        else,traceCats=traceIds(randperm(screenRng,numel(traceIds),targetTrace));end
    else
        traceCats=[];
    end
    traceCats=traceCats(randperm(numel(traceCats)));
    if strcmp(screenPolicy,'geometry')
        [seekPlan,seekCats]=ScreenSeekingFlat(seekBuffer,seekIds,roundBest,center,targetSeek,N,SMP);
    else,[seekPlan,seekCats]=RandomSeeking(seekIds,targetSeek,N,SMP,screenRng);end
    end
    cats=[traceCats;seekCats];
    for k=1:numel(cats)
        i=cats(k);
        if tracing(i)
            beforeCost=fitness(i); beforeBest=Best.Cost;
            value=f(trial(i,:));
            traceLocal=traceLocal+double(value<beforeCost);
            traceGlobal=traceGlobal+double(value<beforeBest);
            traceGain=traceGain+max(0,beforeBest-value);
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
                Best.Cost=value; Best.Vector=trial(i,:);lastImprovementFE=fe;
            end
            T(fe)=Best.Cost;
            if audit
                evalPoints(fe,:)=trial(i,:);
                evalLog(fe,:)=[fe,roundIndex,1,i,0,beforeCost,value,beforeBest,Best.Cost];
            end
        else
            selected=seekPlan{i};
            localCost=fitness(i); parentCost=fitness(i); localVector=pop(i,:);
            wasVirtual=any(pop(i,:)~=realPop(i,:));
            maxParentEvaluations=max(maxParentEvaluations,numel(selected));
            for q=1:numel(selected)
                row=selected(q); beforeCost=localCost; beforeBest=Best.Cost;
                if audit,assert(floor((row-1)/SMP)+1==i && mod(row-1,SMP)>=1);end
                value=f(seekBuffer(row,:));
                seekLocal=seekLocal+double(value<beforeCost);
                seekGlobal=seekGlobal+double(value<beforeBest);
                seekGain=seekGain+max(0,beforeBest-value);
                fe=fe+1; seekEvalTotal=seekEvalTotal+1;
                if value<personalBestCost(i)
                    personalBest(i,:)=seekBuffer(row,:); personalBestCost(i)=value;
                end
                if value<localCost
                    localCost=value; localVector=seekBuffer(row,:);
                end
                if value<Best.Cost
                    Best.Cost=value; Best.Vector=seekBuffer(row,:);lastImprovementFE=fe;
                end
                T(fe)=Best.Cost;
                if audit
                    evalPoints(fe,:)=seekBuffer(row,:);
                    evalLog(fe,:)=[fe,roundIndex,2,i,mod(row-1,SMP)+1,beforeCost,value,beforeBest,Best.Cost];
                end
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
    roundLog(roundIndex,:)=[roundBeforeFE,fe,targetTrace,targetSeek,numel(traceIds),numel(seekIds),numel(seekCats),traceLocal,seekLocal,traceGlobal,seekGlobal,traceGain,seekGain];
    frameworkLog(roundIndex,:)=[roundBeforeFE,fe,numel(traceIds),numel(seekIds)*(SMP-1),targetTrace,targetSeek,double(isDense)];
    if audit && ~virtualTracing,assert(isequal(pop,realPop),'NoVirtual must retain only evaluated real positions.');end

    expectedTrace=min(traceQuota,max(1,budgetThisRound-1));fallback=targetTrace~=expectedTrace || targetSeek~=budgetThisRound-expectedTrace;
    blockFallback=blockFallback || fallback;
    decisionLog(decisionCount,2)=fe;
    decisionLog(decisionCount,11:13)=decisionLog(decisionCount,11:13)+[targetTrace,targetSeek,fallback];
end
if pending
    discountLog(decisionCount)=gamma^((fe-decisionLog(decisionCount,1))/100);
    gain=max(0,decisionLog(decisionCount,8)-Best.Cost);
    reward=progressReward(rewardMode,gain,rewardLog(decisionCount,1));if strcmp(rewardMode,'binary')&&gain>0,reward=rewardBonus;end;rewardLog(decisionCount,2:4)=[gain,reward,Best.Cost];eligible=~blockFallback;if gatedPolicy,eligible=eligible&&logical(gateLog(decisionCount,2));end
    if (strcmp(policy,'q')||strcmp(policy,'gateq')) && eligible
        ps=decisionLog(decisionCount,3);pa=decisionLog(decisionCount,4);Q(ps,pa)=Q(ps,pa)+alpha*(reward-Q(ps,pa));QVisits(ps,pa)=QVisits(ps,pa)+1;decisionLog(decisionCount,14)=1;
    end
    updateCount=updateCount+1;updateLog(updateCount,:)=[decisionLog(decisionCount,3),decisionLog(decisionCount,4),reward,0,1,decisionLog(decisionCount,1),fe,eligible];
    decisionLog(decisionCount,9:10)=[Best.Cost,reward];pending=false;
end
if logTrajectory
    trendLog(decisionCount+1,:)=[fe,populationDiversity(realPop,lb,ub),populationDiversity(pop,lb,ub),max(fitness)-min(fitness),fe-lastImprovementFE,Best.Cost,initialRealDiversity];
end
decisionLog=decisionLog(1:decisionCount,:);updateLog=updateLog(1:updateCount,:);rewardLog=rewardLog(1:decisionCount,:);stateLog=stateLog(1:decisionCount,:);gateLog=gateLog(1:decisionCount,:);discountLog=discountLog(1:decisionCount);
if logTrajectory,trendLog=trendLog(1:decisionCount+1,:);end
roundLog=roundLog(1:roundIndex,:);frameworkLog=frameworkLog(1:roundIndex,:);
T=T(1:fe); info=struct('Algorithm','EB-CSO','Seed',seed,'Evaluations',fe,...
    'InitialCost',T(N),'InitialPopulation',initialPopulation,'SeekingEvaluations',seekEvalTotal,...
    'TracingEvaluations',traceEvalTotal,'CandidateEvaluations',seekEvalTotal+traceEvalTotal,...
    'Seconds',toc(clockStart),'SeekCandidateCount',seekCandidateCount,...
    'UseSeekingElite',useSeekingElite,'Rounds',roundIndex,...
    'MaxParentEvaluations',maxParentEvaluations,'RoundLog',roundLog,...
    'RoundLogColumns',{{'BeforeFE','AfterFE','TargetTrace','TargetSeek','TracePopulation','SeekPopulation','SeekingParentCoverage','TraceLocalSuccess','SeekMarginalSuccess','TraceGlobalSuccess','SeekGlobalSuccess','TraceGlobalGain','SeekGlobalGain'}},...
    'EvalLog',evalLog,'EvalPoints',evalPoints);
info.Algorithm='CSO-Mode-Q';info.ModeTraceQuota=traceQuota;info.ModePolicy=policy;
info.QTable=Q;info.QVisits=QVisits;info.DecisionLog=decisionLog;info.UpdateLog=updateLog;
info.QUpdates=sum(QVisits,'all');info.Decisions=decisionCount;info.PendingAtEnd=pending;
info.PolicyRNGSeed=seed+3000001;info.Alpha=alpha;info.Gamma=gamma;info.Epsilon=epsilon;
info.CompactGate=compactGate;info.StateCount=stateCount;info.TraceQuotaOptions=traceQuotas;
info.RewardBonus=rewardBonus;info.EpisodeFE=episodeFE;info.DiscountLog=discountLog;
info.GateLog=gateLog;info.GatedPolicy=gatedPolicy;info.FreeDecisions=sum(gateLog(:,2));info.ForcedFixed6Decisions=sum(gateLog(:,2)==0);
info.RewardMode=rewardMode;info.RewardLog=rewardLog;info.StateMode=stateMode;info.StateLog=stateLog;info.StagnationThreshold=stagnationThreshold;
info.TrendLog=trendLog;info.TrendLogColumns={'FE','RealDiversity','VirtualDiversity','RealFitnessSpread','StagnationFE','BestCost','InitialRealDiversity'};
info.EvaluationMode=evaluationMode;info.ScreenPolicy=screenPolicy;info.VirtualTracing=virtualTracing;
info.FrameworkLog=frameworkLog;info.ScreenRNGSeed=seed+4000001;
end

function [nTrace,nSeek]=AllocateBudgetMode(quota,traceCount,seekCount,traceQuota)
% Four tracing and six seeking slots for full rounds, with tail fallback.
targetTrace=min(traceQuota, max(1, quota-1));
nTrace=min(traceCount,targetTrace);
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

function [plan,seekCats]=ScreenSeekingFlat(pool,catIds,best,center,quota,N,SMP)
plan=cell(N,1);
seekCats=zeros(0,1);
if quota==0,return,end
nCats=numel(catIds); perCat=SMP-1; total=nCats*perCat; rows=zeros(total,1); parents=zeros(total,1); row=0;
for q=1:nCats
    block=(catIds(q)-1)*SMP+(2:SMP);
    ix=row+(1:perCat); rows(ix)=block; parents(ix)=catIds(q); row=row+perCat;
end
points=pool(rows,:);
[~,near]=sort(sum((points-best).^2,2));
[~,far]=sort(sum((points-center).^2,2),'descend');
selected=false(total,1); selectedCount=0; counts=zeros(N,1); chosen=zeros(N,2);
nearTarget=ceil(quota/2);
for phase=1:2
    if phase==1
        order=near; target=nearTarget;
    else
        order=far; target=quota;
    end
    if selectedCount>=target,continue,end
    for q=1:total
        index=order(q); parent=parents(index);
        if ~selected(index) && counts(parent)<2
            selected(index)=true; selectedCount=selectedCount+1;
            counts(parent)=counts(parent)+1;
            chosen(parent,counts(parent))=rows(index);
        end
        if selectedCount>=target,break,end
    end
end
seekCats=find(counts>0);
for q=seekCats'
    plan{q}=chosen(q,1:counts(q));
end
end

function value=populationDiversity(points,lb,ub)
center=mean(points,1);scale=max(ub-lb,eps);value=sqrt(mean(((points-center)./scale).^2,'all'));
end

function reward=progressReward(mode,gain,spread)
switch mode
 case 'binary',reward=2*double(gain>0)-1;
 case 'positive',reward=double(gain>0);
 case 'gain',reward=min(1,gain/max(spread,eps));
end
end

function [plan,cats]=RandomSeeking(ids,quota,N,SMP,stream)
plan=cell(N,1);rows=zeros(numel(ids)*(SMP-1),1);parents=rows;offset=0;
for i=ids',ix=offset+(1:SMP-1);rows(ix)=(i-1)*SMP+(2:SMP);parents(ix)=i;offset=offset+SMP-1;end
order=randperm(stream,numel(rows));counts=zeros(N,1);selected=0;
for index=order
 parent=parents(index);if counts(parent)>=2,continue;end
 if selected>=quota,break;end
 counts(parent)=counts(parent)+1;plan{parent}(end+1)=rows(index);selected=selected+1;
end
assert(selected==quota);cats=find(counts>0);
end
function [plan,cats]=DenseSeeking(ids,quota,N,SMP)
plan=cell(N,1);remaining=quota;
for i=ids'
 count=min(SMP-1,remaining);if count>0,plan{i}=(i-1)*SMP+(2:count+1);remaining=remaining-count;end
end
assert(remaining==0);cats=find(~cellfun(@isempty,plan));
end
