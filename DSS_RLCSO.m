function [Best,T,info] = DSS_RLCSO(f,state,~,Particle_Number,seed)
    % 双层空间筛选 + Q-learning；modeAware 保留旧版，modeAwareV3 修正流程。
    clockStart=tic;
    sizepop=Particle_Number;
    SMP=5;
    if isfield(state,'SMP')
        SMP=state.SMP;
    end
    rho=0.10;
    alpha=0.10;
    gamma=0.90;
    useCatScreen=true;
    useCandidateScreen=true;
    useRL=true;
    useModeSignal=true;
    seekingMode='classic';
    candidateScheduler='none';
    useFamilySignal=true;
    familyReward='legacy';
    seekSelection='legacy';
    feedbackSelection='none';
    feedbackLogging=false;
    searchCore='base';
    eliteGuidance=[];
    seekingEliteGuidance=[];
    tracingElitistAcceptance=[];
    stagnationExemplar=false;
    stagnationThreshold=10;
    stagnationLambda=0.50;
    tracingDecay=false;
    virtualTracing=false;
    evaluationQuota=[];
    actionMode='qlearning';
    rlMode='legacy';
    if isfield(state,'ablation')
        useCatScreen=state.ablation.useCatScreen;
        useCandidateScreen=state.ablation.useCandidateScreen;
        useRL=state.ablation.useRL;
    end
    if isfield(state,'actionMode')
        actionMode=state.actionMode;
    end
    if isfield(state,'useModeSignal')
        useModeSignal=state.useModeSignal;
    end
    if isfield(state,'rlMode')
        rlMode=state.rlMode;
    end
    if isfield(state,'seekingMode')
        seekingMode=state.seekingMode;
    end
    if isfield(state,'candidateScheduler')
        candidateScheduler=state.candidateScheduler;
    end
    if isfield(state,'useFamilySignal')
        useFamilySignal=state.useFamilySignal;
    end
    if isfield(state,'familyReward')
        familyReward=state.familyReward;
    end
    if isfield(state,'seekSelection')
        seekSelection=state.seekSelection;
    end
    if isfield(state,'feedbackSelection')
        feedbackSelection=state.feedbackSelection;
    end
    if isfield(state,'feedbackLogging')
        feedbackLogging=state.feedbackLogging;
    end
    if isfield(state,'searchCore')
        searchCore=state.searchCore;
    end
    if isfield(state,'eliteGuidance')
        eliteGuidance=state.eliteGuidance;
    end
    if isfield(state,'seekingEliteGuidance')
        seekingEliteGuidance=state.seekingEliteGuidance;
    end
    if isfield(state,'tracingElitistAcceptance')
        tracingElitistAcceptance=state.tracingElitistAcceptance;
    end
    if isfield(state,'stagnationExemplar')
        stagnationExemplar=state.stagnationExemplar;
    end
    if isfield(state,'stagnationThreshold')
        stagnationThreshold=state.stagnationThreshold;
    end
    if isfield(state,'stagnationLambda')
        stagnationLambda=state.stagnationLambda;
    end
    if isfield(state,'tracingDecay')
        tracingDecay=state.tracingDecay;
    end
    if isfield(state,'virtualTracing')
        virtualTracing=state.virtualTracing;
    end
    if isfield(state,'evaluationQuota')
        evaluationQuota=state.evaluationQuota;
    end
    if isempty(eliteGuidance)
        eliteGuidance=~strcmp(searchCore,'base');
    end
    if isempty(seekingEliteGuidance)
        seekingEliteGuidance=eliteGuidance;
    end
    if isempty(tracingElitistAcceptance)
        tracingElitistAcceptance=~strcmp(searchCore,'base');
    end
    frozenSelection=~strcmp(seekSelection,'legacy');
    globalSelection=strcmp(seekSelection,'global') || strcmp(seekSelection,'globalCap2');
    jointSelection=strcmp(seekSelection,'jointCap2');
    randomSelection=strcmp(seekSelection,'randomCap2');
    matchedSelection=strcmp(seekSelection,'matchedRandomCap2');
    compensationSelection=strcmp(seekSelection,'g2Random') || ...
        strcmp(seekSelection,'g2Age');
    sourceSelection=strcmp(seekSelection,'sourceAware');
    coverageSourceSelection=strcmp(seekSelection,'coverageSource');
    useContinuousReward=strcmp(rlMode,'continuous') || strcmp(rlMode,'v3');
    useDiversityState=strcmp(rlMode,'diversity') || strcmp(rlMode,'v3');
    paperMode=strcmp(rlMode,'paper');
    modeAware=strcmp(rlMode,'modeAware');
    modeAwareV2=strcmp(rlMode,'modeAwareV2');
    modeAwareV3=strcmp(rlMode,'modeAwareV3');
    modeAwareV32=strcmp(rlMode,'modeAwareV32');
    modeAwareV4=strcmp(rlMode,'modeAwareV4');
    modeAwareV41=strcmp(rlMode,'modeAwareV41');
    familyScheduler=~strcmp(candidateScheduler,'none');
    fairOpportunity=strcmp(rlMode,'modeAwareV31');
    modeSampleV3=modeAwareV3 || modeAwareV32 || modeAwareV4 || modeAwareV41;
    modePreserving=modeAwareV32 || modeAwareV41;
    if isfield(state,'useModePreserving')
        modePreserving=state.useModePreserving;
    end
    opportunityV3=modeAwareV3 || modePreserving;
    if fairOpportunity
        modeSampleV3=true;
        opportunityV3=true;
    end
    if isfield(state,'modeSampleV3')
        modeSampleV3=state.modeSampleV3;
    end
    if isfield(state,'opportunityScreen')
        opportunityV3=state.opportunityScreen;
    end
    recoveryEnabled=modeAwareV4;
    recoveryInterval=20;
    recoveryThreshold=10;
    if modeAwareV41
        if isfield(state,'recoveryEnabled')
            recoveryEnabled=state.recoveryEnabled;
        else
            recoveryEnabled=true;
        end
        if isfield(state,'recoveryInterval')
            recoveryInterval=state.recoveryInterval;
        end
    end
    diversityThreshold=0.50;
    pop=state.initialPopulation;
    D=size(pop,2);
    lb=state.lowerBound;
    ub=state.upperBound;
    rng(seed,'twister');
    V=0.01*(2*rand(sizepop,D)-1).*(ub-lb);
    Vmax=0.2*(ub-lb);
    budget=state.maxEvaluations;
    assert(budget>=sizepop,'Evaluation budget must cover initialization.');

    T=nan(budget,1);
    fitness=zeros(sizepop,1);
    lastRealEvaluationFE=zeros(sizepop,1);
    Best.Cost=inf;
    for i=1:sizepop
        fitness(i)=f(pop(i,:));
        lastRealEvaluationFE(i)=i;
        Best=UpdateBest(Best,pop(i,:),fitness(i));
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.InitialCost=Best.Cost;
    info.InitialPopulation=state.initialPopulation;
    personalBest=pop;
    personalBestCost=fitness;
    realPop=pop;
    info.FirstImprovementEvaluation=NaN;
    info.ActionCounts=[];
    info.ActionHistory=[];
    info.DiversityHistory=[];
    info.StallHistory=[];
    info.SelectedCatCounts=[];
    info.CatSelectionCounts=zeros(sizepop,1);
    info.EvaluationsPerRound=[];
    info.SeekingEvaluations=0;
    info.TracingEvaluations=0;
    info.CandidateEvaluations=0;
    info.UseCatScreen=useCatScreen;
    info.UseCandidateScreen=useCandidateScreen;
    info.UseRL=useRL;
    info.ActionMode=actionMode;
    info.RLMode=rlMode;
    info.PaperMode=paperMode;
    info.ModeAware=modeAware || modeAwareV2 || modeAwareV3 || modeAwareV32 || ...
        modeAwareV4 || modeAwareV41 || familyScheduler;
    info.ModeAwareV2=modeAwareV2;
    info.ModeAwareV3=modeSampleV3;
    info.ModeAwareV32=modeAwareV32;
    info.ModeAwareV4=modeAwareV4;
    info.ModeAwareV41=modeAwareV41;
    info.OpportunityScreen=opportunityV3;
    info.FairOpportunity=fairOpportunity;
    info.ModePreservingOpportunity=modePreserving;
    info.UseModeSignal=useModeSignal;
    info.SeekingMode=seekingMode;
    info.CandidateScheduler=candidateScheduler;
    info.UseFamilySignal=useFamilySignal;
    info.FamilyReward=familyReward;
    info.FamilyScheduler=familyScheduler;
    info.SeekSelection=seekSelection;
    info.SearchCore=searchCore;
    info.EliteGuidance=eliteGuidance;
    info.SeekingEliteGuidance=seekingEliteGuidance;
    info.TracingElitistAcceptance=tracingElitistAcceptance;
    info.StagnationExemplar=stagnationExemplar;
    info.StagnationThreshold=stagnationThreshold;
    info.StagnationLambda=stagnationLambda;
    info.TracingDecay=tracingDecay;
    info.VirtualTracing=virtualTracing;
    info.SMP=SMP;
    info.SeekingParentCoverage=[];
    info.SeekingConcentration=[];
    info.FeedbackSeekingAgeFE=[];
    info.FeedbackSeekingVirtualOffset=[];
    info.FeedbackSeekingSuccess=[];
    info.FeedbackSeekingGlobalImprovement=[];
    info.FeedbackSeekingDistanceToBest=[];
    info.FeedbackSeekingDistanceToElite=[];
    info.FeedbackSeekingSourceProgress=[];
    info.FeedbackSelection=feedbackSelection;
    info.FeedbackLogging=feedbackLogging;
    info.MatchedReferenceCoverage=[];
    info.MatchedReferenceConcentration=[];
    info.SeekingMaxParentEvaluations=[];
    info.SeekingGlobalImprovementCounts=[];
    info.TracingGlobalImprovementCounts=[];
    info.SeekingGlobalGain=[];
    info.TracingGlobalGain=[];
    info.RecoveryEnabled=recoveryEnabled;
    info.RecoveryInterval=recoveryInterval;
    info.WasExploration=[];
    info.GreedyActionHistory=[];
    info.EpsilonHistory=[];
    info.SeekingEvaluationsPerRound=[];
    info.TracingEvaluationsPerRound=[];
    info.TargetTracingEvaluations=[];
    info.ActualTracingEvaluations=[];
    info.TargetSeekingEvaluations=[];
    info.ActualSeekingEvaluations=[];
    info.BudgetFillRate=[];
    info.ModeAllocationError=[];
    info.RecoveryEvaluations=0;
    info.RecoveryEvaluationsPerRound=[];
    info.RecoveryImprovementPerRound=[];
    info.ModeSampleCounts=[];
    info.ModeWindowRates=[];
    info.OpportunitySelectionChanged=[];
    info.GeneratedTracingCatShare=[];
    info.SelectedTracingCatShare=[];
    info.RewardHistory=[];
    info.GlobalRewardHistory=[];
    info.PopulationRewardHistory=[];
    info.DiversityStateHistory=[];
    info.ModeStateHistory=[];
    info.FamilyStateHistory=[];
    info.SeekingSuccessHistory=[];
    info.TracingSuccessHistory=[];
    info.ModeSuccessRateHistory=[];
    info.ModeEfficiencyHistory=[];
    info.ClassicCandidateGenerated=0;
    info.RangeCandidateGenerated=0;
    info.ClassicCandidateEvaluations=0;
    info.RangeCandidateEvaluations=0;
    info.ClassicCandidateSuccess=0;
    info.RangeCandidateSuccess=0;
    info.ClassicGlobalImprovements=0;
    info.RangeGlobalImprovements=0;
    info.StagnationCandidateGenerated=0;
    info.StagnationCandidateEvaluations=0;
    info.StagnationCandidateSuccess=0;
    info.StateHistory=[];
    info.StateVisitCounts=[];
    info.StateActionCounts=[];
    stall=0;
    initialCenter=mean(pop,1);
    initialDiversity=mean(sqrt(sum((pop-initialCenter).^2,2)));
    if familyScheduler
        if useFamilySignal
            qStateCount=27;
        else
            qStateCount=9;
        end
    elseif (modeAware || modeAwareV2 || modeSampleV3) && useModeSignal
        qStateCount=27;
    elseif useDiversityState
        qStateCount=18;
    else
        qStateCount=9;
    end
    info.QStateCount=qStateCount;
    info.StateVisitCounts=zeros(qStateCount,1);
    actionCount=4;
    if modeAwareV4 || modeAwareV41 || familyScheduler
        actionCount=3;
    end
    info.ActionCounts=zeros(1,actionCount);
    info.StateActionCounts=zeros(qStateCount,actionCount);
    Q=zeros(qStateCount,actionCount);
    seekSuccessHistory=[];
    seekEvaluationHistory=[];
    traceSuccessHistory=[];
    traceEvaluationHistory=[];
    seekGainHistory=[];
    traceGainHistory=[];
    catStall=zeros(sizepop,1);
    modeWindow=5;
    modeThreshold=0.05;
    seekSamples=[];
    traceSamples=[];
    classicSamples=[];
    rangeSamples=[];
    sampleWindow=20;
    minimumSamples=10;

    while info.Evaluations<budget
        roundStart=info.Evaluations;
        progress=(info.Evaluations-sizepop)/max(1,budget-sizepop);
        center=mean(pop,1);
        diversity=mean(sqrt(sum((pop-center).^2,2)));
        diversityRatio=diversity/max(initialDiversity,eps);
        if modeSampleV3
            [modeStatus,rates]=SampleModeStatus(seekSamples,traceSamples, ...
                minimumSamples,modeThreshold);
            info.ModeSampleCounts(end+1,:)=[numel(seekSamples) numel(traceSamples)];
            info.ModeWindowRates(end+1,:)=rates;
        else
            modeStatus=ModeStatus(seekSuccessHistory,seekEvaluationHistory, ...
                traceSuccessHistory,traceEvaluationHistory,seekGainHistory, ...
                traceGainHistory,modeWindow,modeThreshold,modeAwareV2);
        end
        if familyScheduler
            familyStatus=FamilyStatus(classicSamples,rangeSamples, ...
                minimumSamples,modeThreshold);
            info.FamilyStateHistory(end+1)=familyStatus;
        else
            familyStatus=2;
        end
        if familyScheduler
            if useFamilySignal
                stateIndex=ModeAwareStateIndex(progress,stall,familyStatus);
            else
                stateIndex=StateIndex(progress,stall,diversityRatio, ...
                    false,diversityThreshold);
            end
        elseif (modeAware || modeAwareV2 || modeSampleV3) && useModeSignal
            stateIndex=ModeAwareStateIndex(progress,stall,modeStatus);
        else
            stateIndex=StateIndex(progress,stall,diversityRatio, ...
                useDiversityState,diversityThreshold);
        end
        epsilon=0.50-0.45*progress;
        wasExploration=false;
        greedyAction=NaN;
        if strcmp(candidateScheduler,'fixedClassic')
            action=1;
        elseif strcmp(candidateScheduler,'fixedHybrid')
            action=2;
        elseif strcmp(candidateScheduler,'fixedRange')
            action=3;
        elseif strcmp(candidateScheduler,'randomFamily')
            action=randi(3);
        elseif strcmp(candidateScheduler,'qFamily')
            if rand<epsilon
                action=randi(3);
                wasExploration=true;
            else
                [~,action]=max(Q(stateIndex,:));
                greedyAction=action;
            end
        elseif strcmp(actionMode,'fixed')
            action=4;
        elseif strcmp(actionMode,'fixed1')
            action=1;
        elseif strcmp(actionMode,'fixed2')
            action=2;
        elseif strcmp(actionMode,'fixed3')
            action=3;
        elseif strcmp(actionMode,'fixed4')
            action=4;
        elseif strcmp(actionMode,'random')
            action=randi(actionCount);
        elseif strcmp(actionMode,'epsFixed')
            if rand<epsilon
                action=randi(actionCount);
                wasExploration=true;
            else
                action=min(2,actionCount);
                greedyAction=action;
            end
        elseif strcmp(actionMode,'heuristic')
            if stall>=10
                action=4;
            elseif modeStatus==1
                action=1;
            elseif modeStatus==3
                action=3;
            else
                action=2;
            end
        elseif useRL
            if rand<epsilon
                action=randi(actionCount);
                wasExploration=true;
            else
                [~,action]=max(Q(stateIndex,:));
                greedyAction=action;
            end
        else
            action=1;
        end
        info.WasExploration(end+1)=wasExploration;
        info.GreedyActionHistory(end+1)=greedyAction;
        info.EpsilonHistory(end+1)=epsilon;
        info.ActionCounts(action)=info.ActionCounts(action)+1;
        info.ActionHistory(end+1)=action;
        info.StateHistory(end+1)=stateIndex;
        info.StateVisitCounts(stateIndex)=info.StateVisitCounts(stateIndex)+1;
        info.StateActionCounts(stateIndex,action)= ...
            info.StateActionCounts(stateIndex,action)+1;
        info.ModeStateHistory(end+1)=modeStatus;
        [mr,srd,cdc,jump,peerLearn,opposition]=ActionParameters(action,rlMode);
        roundSeekingMode=seekingMode;
        if familyScheduler
            mr=0.40;
            srd=0.05;
            cdc=0.20;
            jump=false;
            peerLearn=false;
            opposition=false;
            if action==1
                roundSeekingMode='classic';
            elseif action==2
                roundSeekingMode='hybrid';
            else
                roundSeekingMode='range';
            end
        end
        oldBest=Best.Cost;
        roundBest=Best.Vector;
        modeBestBefore=oldBest;
        oldFitness=fitness;
        evaluated=false(sizepop,1);
        roundSeekEvaluations=0;
        roundSeekSuccess=0;
        roundTraceEvaluations=0;
        roundTraceSuccess=0;
        roundSeekGain=0;
        roundTraceGain=0;
        seekingImproved=false;
        seekParentCounts=zeros(sizepop,1);
        seekGlobalCount=0;
        traceGlobalCount=0;
        seekGlobalGain=0;
        traceGlobalGain=0;
        if recoveryEnabled
            if modeAwareV41
                recoveryActive=stall>=recoveryThreshold && ...
                    mod(stall-recoveryThreshold,recoveryInterval)==0;
            else
                recoveryActive=stall>=recoveryThreshold;
            end
        else
            recoveryActive=false;
        end
        if recoveryActive
            recoveryVector=Best.Vector+0.10*(1-progress)*randn(1,D).*(ub-lb);
            recoveryVector=max(lb,min(ub,recoveryVector));
        else
            recoveryVector=[];
        end
        roundRecovery=0;

        if useCatScreen
            budgetThisRound=min(ceil(rho*sizepop),budget-info.Evaluations);
            catCount=min(sizepop,max(2,ceil(budgetThisRound/2)));
        else
            % 消融时保持每轮评价预算不变，只改变猫的选择方式。
            budgetThisRound=min(ceil(rho*sizepop),budget-info.Evaluations);
            catCount=min(sizepop,max(2,ceil(budgetThisRound/2)));
        end
        info.DiversityHistory(end+1)=diversity;
        info.DiversityStateHistory(end+1)=diversityRatio;
        info.StallHistory(end+1)=stall;
        if useCatScreen && ~opportunityV3
            distBest=sum((pop-Best.Vector).^2,2);
            distCenter=sum((pop-center).^2,2);
            [~,orderBest]=sort(distBest);
            [~,orderCenter]=sort(distCenter,'descend');
            cats=unique([orderBest(1:ceil(catCount/2)); ...
                orderCenter(1:floor(catCount/2))],'stable');
            if numel(cats)<catCount
                extra=setdiff((1:sizepop)',cats,'stable');
                cats=[cats;extra(1:catCount-numel(cats))];
            end
        elseif ~opportunityV3
            cats=(1:sizepop)';
        end
        if ~opportunityV3
            cats=cats(randperm(numel(cats)));
            info.SelectedCatCounts(end+1)=numel(cats);
            info.CatSelectionCounts(cats)=info.CatSelectionCounts(cats)+1;
        end
        eliteCount=max(2,ceil(0.20*sizepop));
        [~,eliteOrder]=sort(personalBestCost);
        elitePool=eliteOrder(1:eliteCount);
        trial=pop;
        trialVelocity=V;
        tracing=false(sizepop,1);
        stagnationCandidate=false(sizepop,1);
        seekingPool=cell(sizepop,1);
        seekingEliteVectors=repmat(Best.Vector,sizepop,1);
        for i=1:sizepop
            if eliteGuidance
                eliteIndex=elitePool(randi(eliteCount));
                tracingEliteVector=personalBest(eliteIndex,:);
            else
                tracingEliteVector=Best.Vector;
            end
            if seekingEliteGuidance
                if eliteGuidance
                    seekingEliteVector=tracingEliteVector;
                else
                    eliteIndex=elitePool(randi(eliteCount));
                    seekingEliteVector=personalBest(eliteIndex,:);
                end
            else
                seekingEliteVector=Best.Vector;
            end
            seekingEliteVectors(i,:)=seekingEliteVector;
            if rand<mr
                tracing(i)=true;
                if paperMode && peerLearn
                    peer=OtherCat(i,sizepop);
                    baseTracingInertia=0.9;
                    trialVelocity(i,:)=baseTracingInertia*V(i,:)+1.5*rand(1,D).* ...
                        (pop(peer,:)-pop(i,:));
                elseif paperMode && action==1
                    baseTracingInertia=0.4;
                    trialVelocity(i,:)=baseTracingInertia*V(i,:)+ ...
                        1.0*rand(1,D).*(Best.Vector-pop(i,:))+ ...
                        2.5*rand(1,D).*(Best.Vector-pop(i,:));
                else
                    baseTracingInertia=1.0;
                    trialVelocity(i,:)=baseTracingInertia*V(i,:)+2*rand(1,D).* ...
                        (tracingEliteVector-pop(i,:));
                end
                if tracingDecay
                    tracingInertia=0.9-0.5*progress;
                    trialVelocity(i,:)=tracingInertia*V(i,:)+ ...
                        trialVelocity(i,:)-baseTracingInertia*V(i,:);
                end
                trialVelocity(i,:)=max(-Vmax,min(Vmax,trialVelocity(i,:)));
                if opposition
                    trialVelocity(i,:)=-V(i,:);
                    trial(i,:)=lb+ub-pop(i,:);
                elseif jump
                    sigma=0.10*(1-progress);
                    trial(i,:)=Best.Vector+sigma*randn(1,D).*(ub-lb);
                else
                    trial(i,:)=pop(i,:)+trialVelocity(i,:);
                end
                trial(i,:)=max(lb,min(ub,trial(i,:)));
            else
                copies=repmat(pop(i,:),SMP,1);
                if strcmp(roundSeekingMode,'hybrid')
                    info.ClassicCandidateGenerated=info.ClassicCandidateGenerated+2;
                    info.RangeCandidateGenerated=info.RangeCandidateGenerated+2;
                elseif familyScheduler && strcmp(roundSeekingMode,'range')
                    info.RangeCandidateGenerated=info.RangeCandidateGenerated+4;
                elseif familyScheduler
                    info.ClassicCandidateGenerated=info.ClassicCandidateGenerated+4;
                end
                for j=2:SMP
                    if stagnationExemplar && catStall(i)>=stagnationThreshold && j==2
                        d=randperm(D,max(1,round(cdc*D)));
                        sourceIds=elitePool(randi(eliteCount,1,numel(d)))';
                        sourceIds=sourceIds(:)';
                        sourceIndex=sub2ind([sizepop D],sourceIds,d);
                        exemplar=personalBest(sourceIndex);
                        stepScale=max(0.25,1-progress);
                        step=srd*(ub(d)-lb(d))/2*stepScale;
                        copies(j,d)=pop(i,d)+stagnationLambda* ...
                            (exemplar-pop(i,d))+step.*(2*rand(1,numel(d))-1);
                        info.StagnationCandidateGenerated= ...
                            info.StagnationCandidateGenerated+1;
                        stagnationCandidate(i)=true;
                    elseif opposition
                        sigma=0.05*(1-progress);
                        copies(j,:)=lb+ub-pop(i,:)+ ...
                            sigma*randn(1,D).*(ub-lb);
                    elseif jump
                        sigma=0.10*(1-progress);
                        copies(j,:)=Best.Vector+sigma*randn(1,D).*(ub-lb);
                    elseif paperMode && peerLearn
                        peer=OtherCat(i,sizepop);
                        copies(j,:)=pop(i,:)+rand(1,D).* ...
                            (pop(peer,:)-pop(i,:));
                    elseif strcmp(roundSeekingMode,'range') || ...
                            (strcmp(roundSeekingMode,'hybrid') && j>3)
                        d=randperm(D,max(1,round(cdc*D)));
                        stepScale=1-progress;
                        eliteStep=0;
                        differenceStep=0;
                        if seekingEliteGuidance
                            eliteStep=0.25*(seekingEliteVector(d)-pop(i,d));
                        end
                        if strcmp(searchCore,'eliteDiff')
                            pair=setdiff(1:sizepop,i);
                            pair=pair(randperm(numel(pair),2));
                            differenceStep=0.50*(personalBest(pair(1),d)- ...
                                personalBest(pair(2),d));
                            stepScale=max(0.20,stepScale);
                        end
                        step=srd*(ub(d)-lb(d))/2*stepScale;
                        copies(j,d)=pop(i,d)+eliteStep+differenceStep+ ...
                            step.*(2*rand(1,numel(d))-1);
                    else
                        d=randperm(D,max(1,round(cdc*D)));
                        copies(j,d)=copies(j,d).*(1+srd*(2*rand(1,numel(d))-1));
                    end
                    copies(j,:)=max(lb,min(ub,copies(j,:)));
                end
                seekingPool{i}=copies;
            end
        end

        if virtualTracing
            tracingIds=find(tracing);
            pop(tracingIds,:)=trial(tracingIds,:);
            V(tracingIds,:)=trialVelocity(tracingIds,:);
        end

        modeBudget=budgetThisRound-double(recoveryActive);
        % V3.2：先按模式分配评价名额，再在每个模式内部筛选。
        if modePreserving
            traceIds=find(tracing);
            seekIds=find(~tracing);
            candidateLimit=2;
            if isempty(evaluationQuota)
                targetTrace=min(numel(traceIds),round(modeBudget*mr));
            else
                targetTrace=min(numel(traceIds),max(1,min(modeBudget-1, ...
                    round(evaluationQuota))));
            end
            targetSeek=min(candidateLimit*numel(seekIds), ...
                modeBudget-targetTrace);
            leftover=modeBudget-targetTrace-targetSeek;
            extraTrace=min(leftover,numel(traceIds)-targetTrace);
            targetTrace=targetTrace+extraTrace;
            leftover=leftover-extraTrace;
            extraSeek=min(leftover,candidateLimit*numel(seekIds)-targetSeek);
            targetSeek=targetSeek+extraSeek;
            if useCatScreen
                if targetTrace>0
                    traceBest=sum((trial(traceIds,:)-Best.Vector).^2,2);
                    traceCenter=sum((trial(traceIds,:)-center).^2,2);
                    traceCats=traceIds(SelectCats(traceBest,traceCenter, ...
                        min(targetTrace,numel(traceIds))));
                else
                    traceCats=[];
                end
                if targetSeek>0 && ~globalSelection && ~matchedSelection && ...
                        ~compensationSelection && ~sourceSelection && ...
                        ~coverageSourceSelection
                    seekBest=zeros(numel(seekIds),1);
                    seekCenter=zeros(numel(seekIds),1);
                    for q=1:numel(seekIds)
                        candidates=seekingPool{seekIds(q)}(2:end,:);
                        seekBest(q)=min(sum((candidates-Best.Vector).^2,2));
                        seekCenter(q)=max(sum((candidates-center).^2,2));
                    end
                    seekCatCount=min(numel(seekIds), ...
                        ceil(targetSeek/candidateLimit));
                    seekCats=seekIds(SelectCats(seekBest,seekCenter, ...
                        seekCatCount));
                else
                    seekCats=[];
                end
            else
                traceOrder=randperm(numel(traceIds));
                traceCats=traceIds(traceOrder(1:min(targetTrace,numel(traceIds))));
                seekCatCount=min(numel(seekIds),ceil(targetSeek/candidateLimit));
                seekOrder=randperm(numel(seekIds));
                seekCats=seekIds(seekOrder(1:seekCatCount));
            end
            traceCats=traceCats(randperm(numel(traceCats)));
            seekCats=seekCats(randperm(numel(seekCats)));
            if frozenSelection
                seekPlan=cell(sizepop,1);
                if globalSelection
                    parentCap=SMP-1;
                    if strcmp(seekSelection,'globalCap2')
                        parentCap=2;
                    end
                    seekPlan=GlobalCandidateScreen(seekingPool,seekIds, ...
                        roundBest,center,targetSeek,parentCap);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                elseif jointSelection
                    % Select a small parent shortlist first, then let all
                    % candidates in that shortlist compete jointly.
                    seekPlan=GlobalCandidateScreen(seekingPool,seekCats, ...
                        roundBest,center,targetSeek,2);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                elseif randomSelection
                    seekPlan=RandomCandidateScreen(seekingPool,seekIds,targetSeek,2);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                elseif matchedSelection
                    referencePlan=GlobalCandidateScreen(seekingPool,seekIds, ...
                        roundBest,center,targetSeek,2);
                    seekPlan=MatchedRandomScreen(seekingPool,seekIds,referencePlan);
                    referenceCounts=cellfun(@numel,referencePlan);
                    actualCounts=cellfun(@numel,seekPlan);
                    assert(isequal(sort(referenceCounts),sort(actualCounts)))
                    info.MatchedReferenceCoverage(end+1)=nnz(referenceCounts);
                    info.MatchedReferenceConcentration(end+1)= ...
                        sum((referenceCounts/max(1,targetSeek)).^2);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                elseif compensationSelection
                    basePlan=GlobalCandidateScreen(seekingPool,seekIds, ...
                        roundBest,center,min(2,targetSeek),2);
                    seekPlan=CompensationCandidateScreen(seekingPool,seekIds, ...
                        basePlan,roundBest,lastRealEvaluationFE,info.Evaluations, ...
                        seekSelection);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                elseif sourceSelection
                    basePlan=GlobalCandidateScreen(seekingPool,seekIds, ...
                        roundBest,center,min(2,targetSeek),2);
                    seekPlan=SourceAwareCandidateScreen(seekingPool,seekIds, ...
                        basePlan,roundBest,center,pop,seekingEliteVectors,lb,ub);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                elseif coverageSourceSelection
                    basePlan=GlobalCandidateScreen(seekingPool,seekIds, ...
                        roundBest,center,min(2,targetSeek),2);
                    sourcePlan=SourceAwareCandidateScreen(seekingPool,seekIds, ...
                        basePlan,roundBest,center,pop,seekingEliteVectors,lb,ub);
                    seekPlan=CoverageSourceAwareCandidateScreen(seekingPool,seekIds, ...
                        basePlan,sourcePlan,pop,seekingEliteVectors,lb,ub);
                    seekCats=find(~cellfun(@isempty,seekPlan));
                else
                    slots=targetSeek;
                    for q=1:numel(seekCats)
                        i=seekCats(q);
                        quota=min(2,slots);
                        seekPlan{i}=CandidateScreen(seekingPool{i}, ...
                            roundBest,center,quota);
                        slots=slots-numel(seekPlan{i});
                    end
                end
            end
            cats=[traceCats;seekCats];
            info.OpportunitySelectionChanged(end+1)=true;
            info.TargetTracingEvaluations(end+1)=targetTrace;
            info.TargetSeekingEvaluations(end+1)=targetSeek;
        elseif opportunityV3
            if useCatScreen
                distBest=zeros(sizepop,1);
                distCenter=zeros(sizepop,1);
                for i=1:sizepop
                    if tracing(i)
                        candidates=trial(i,:);
                    else
                        candidates=seekingPool{i}(2:end,:); % 排除缓存父代
                    end
                    candidateBest=sum((candidates-Best.Vector).^2,2);
                    candidateCenter=sum((candidates-center).^2,2);
                    if fairOpportunity
                        distBest(i)=mean(candidateBest);
                        distCenter(i)=mean(candidateCenter);
                    else
                        distBest(i)=min(candidateBest);
                        distCenter(i)=max(candidateCenter);
                    end
                end
                cats=SelectCats(distBest,distCenter,catCount);
                oldCats=SelectCats(sum((pop-Best.Vector).^2,2), ...
                    sum((pop-center).^2,2),catCount);
                info.OpportunitySelectionChanged(end+1)= ...
                    ~isequal(sort(cats),sort(oldCats));
            else
                cats=(1:sizepop)';
            end
            cats=cats(randperm(numel(cats)));
            info.SelectedCatCounts(end+1)=numel(cats);
            info.CatSelectionCounts(cats)=info.CatSelectionCounts(cats)+1;
        end
        info.GeneratedTracingCatShare(end+1)=mean(tracing);
        if isempty(cats)
            info.SelectedTracingCatShare(end+1)=0;
        else
            info.SelectedTracingCatShare(end+1)=mean(tracing(cats));
        end

        remaining=budgetThisRound;
        if recoveryActive && remaining>0
            oldCandidateBest=Best.Cost;
            value=f(recoveryVector);
            info.Evaluations=info.Evaluations+1;
            info.RecoveryEvaluations=info.RecoveryEvaluations+1;
            roundRecovery=1;
            remaining=remaining-1;
            Best=UpdateBest(Best,recoveryVector,value);
            if Best.Cost<oldCandidateBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            T(info.Evaluations)=Best.Cost;
        end
        recoveryImproved=Best.Cost<modeBestBefore;
        modeBestBefore=Best.Cost;
        remainingTrace=budgetThisRound;
        remainingSeek=budgetThisRound;
        if modePreserving
            remainingTrace=info.TargetTracingEvaluations(end);
            remainingSeek=info.TargetSeekingEvaluations(end);
        end
        for k=1:numel(cats)
            if remaining<=0
                break;
            end
            i=cats(k);
            if tracing(i)
                if modePreserving && remainingTrace<=0
                    continue;
                end
                evaluated(i)=true;
                oldLocalCost=fitness(i);
                value=f(trial(i,:));
                info.Evaluations=info.Evaluations+1;
                lastRealEvaluationFE(i)=info.Evaluations;
                info.TracingEvaluations=info.TracingEvaluations+1;
                info.CandidateEvaluations=info.CandidateEvaluations+1;
                roundTraceEvaluations=roundTraceEvaluations+1;
                if modePreserving
                    remainingTrace=remainingTrace-1;
                end
                if value<oldLocalCost
                    roundTraceSuccess=roundTraceSuccess+1;
                    catStall(i)=0;
                else
                    catStall(i)=catStall(i)+1;
                end
                if modeSampleV3
                    traceSamples=[traceSamples value<oldLocalCost];
                    traceSamples=traceSamples(max(1,end-sampleWindow+1):end);
                end
                roundTraceGain=roundTraceGain+max(0,(oldLocalCost-value)/ ...
                    (abs(oldLocalCost)+abs(value)+eps));
                remaining=remaining-1;
                V(i,:)=trialVelocity(i,:);
                tracingAccepted=~tracingElitistAcceptance || value<oldLocalCost;
                if tracingAccepted
                    realPop(i,:)=trial(i,:);
                    fitness(i)=value;
                    pop(i,:)=trial(i,:);
                elseif virtualTracing
                    % A rejected virtual trial must return to its last real position.
                    pop(i,:)=realPop(i,:);
                end
                if value<personalBestCost(i)
                    personalBest(i,:)=trial(i,:);
                    personalBestCost(i)=value;
                end
                oldCandidateBest=Best.Cost;
                Best=UpdateBest(Best,trial(i,:),value);
                traceGlobalCount=traceGlobalCount+double(Best.Cost<oldCandidateBest);
                traceGlobalGain=traceGlobalGain+oldCandidateBest-Best.Cost;
                if Best.Cost<oldCandidateBest && isnan(info.FirstImprovementEvaluation)
                    info.FirstImprovementEvaluation=info.Evaluations;
                end
                T(info.Evaluations)=Best.Cost;
            else
                if modePreserving && remainingSeek<=0
                    continue;
                end
                copies=seekingPool{i};
                if frozenSelection
                    selected=seekPlan{i};
                elseif useCandidateScreen
                    quota=min(2,remaining);
                    selected=CandidateScreen(copies,Best.Vector,center,quota);
                else
                    selected=2:size(copies,1);
                    selected=selected(randperm(numel(selected)));
                    selected=selected(1:min(2,min(numel(selected),remaining)));
                end
                if ~isempty(selected)
                    evaluated(i)=true;
                end
                localCost=fitness(i);
                parentCost=fitness(i);
                localVector=pop(i,:);
                wasVirtual=virtualTracing && any(pop(i,:)~=realPop(i,:));
                for j=selected
                    if remaining<=0
                        break;
                    end
                    if modePreserving && remainingSeek<=0
                        break;
                    end
                    feedbackAgeFE=info.Evaluations-lastRealEvaluationFE(i);
                    feedbackOffset=norm(pop(i,:)-realPop(i,:))/max(norm(ub-lb),eps);
                    feedbackDistanceBest=norm(copies(j,:)-roundBest);
                    feedbackDistanceElite=norm(copies(j,:)-seekingEliteVectors(i,:));
                    sourceDistance=norm(pop(i,:)-seekingEliteVectors(i,:));
                    feedbackSourceProgress=(sourceDistance-feedbackDistanceElite)/ ...
                        max(sourceDistance,1e-6*norm(ub-lb));
                    value=f(copies(j,:));
                    if stagnationCandidate(i) && j==2
                        info.StagnationCandidateEvaluations= ...
                            info.StagnationCandidateEvaluations+1;
                    end
                    if value<personalBestCost(i)
                        personalBest(i,:)=copies(j,:);
                        personalBestCost(i)=value;
                    end
                    seekParentCounts(i)=seekParentCounts(i)+1;
                    hybridRange=strcmp(roundSeekingMode,'range') || ...
                        (strcmp(roundSeekingMode,'hybrid') && j>3);
                    trackCandidateType=familyScheduler || ...
                        strcmp(roundSeekingMode,'hybrid');
                    if trackCandidateType
                        if hybridRange
                            info.RangeCandidateEvaluations=info.RangeCandidateEvaluations+1;
                        else
                            info.ClassicCandidateEvaluations=info.ClassicCandidateEvaluations+1;
                        end
                    end
                    info.Evaluations=info.Evaluations+1;
                    lastRealEvaluationFE(i)=info.Evaluations;
                    info.SeekingEvaluations=info.SeekingEvaluations+1;
                    info.CandidateEvaluations=info.CandidateEvaluations+1;
                    roundSeekEvaluations=roundSeekEvaluations+1;
                    if modePreserving
                        remainingSeek=remainingSeek-1;
                    end
                    successCost=localCost;
                    if modeSampleV3
                        successCost=parentCost;
                        seekSamples=[seekSamples value<parentCost];
                        seekSamples=seekSamples(max(1,end-sampleWindow+1):end);
                    end
                    familySuccess=value<parentCost;
                    if familyScheduler
                        if hybridRange
                            rangeSamples=[rangeSamples familySuccess];
                            rangeSamples=rangeSamples(max(1,end-sampleWindow+1):end);
                        else
                            classicSamples=[classicSamples familySuccess];
                            classicSamples=classicSamples(max(1,end-sampleWindow+1):end);
                        end
                    end
                    if value<successCost
                        roundSeekSuccess=roundSeekSuccess+1;
                        if stagnationCandidate(i) && j==2
                            info.StagnationCandidateSuccess= ...
                                info.StagnationCandidateSuccess+1;
                        end
                        if trackCandidateType
                            if hybridRange
                                info.RangeCandidateSuccess=info.RangeCandidateSuccess+1;
                            else
                                info.ClassicCandidateSuccess=info.ClassicCandidateSuccess+1;
                            end
                        end
                    end
                    roundSeekGain=roundSeekGain+max(0,(successCost-value)/ ...
                        (abs(successCost)+abs(value)+eps));
                    remaining=remaining-1;
                    if value<parentCost
                        catStall(i)=0;
                    else
                        catStall(i)=catStall(i)+1;
                    end
                    if value<localCost
                        localCost=value;
                        localVector=copies(j,:);
                    end
                    oldCandidateBest=Best.Cost;
                    Best=UpdateBest(Best,copies(j,:),value);
                    globalImproved=Best.Cost<oldCandidateBest;
                    seekGlobalCount=seekGlobalCount+double(globalImproved);
                    seekGlobalGain=seekGlobalGain+oldCandidateBest-Best.Cost;
                    if feedbackLogging
                        info.FeedbackSeekingAgeFE(end+1)=feedbackAgeFE;
                        info.FeedbackSeekingVirtualOffset(end+1)=feedbackOffset;
                        info.FeedbackSeekingSuccess(end+1)=double(value<parentCost);
                        info.FeedbackSeekingGlobalImprovement(end+1)=double(globalImproved);
                        info.FeedbackSeekingDistanceToBest(end+1)=feedbackDistanceBest;
                        info.FeedbackSeekingDistanceToElite(end+1)=feedbackDistanceElite;
                        info.FeedbackSeekingSourceProgress(end+1)=feedbackSourceProgress;
                    end
                    if globalImproved
                        seekingImproved=true;
                    end
                    if Best.Cost<oldCandidateBest && trackCandidateType
                        if hybridRange
                            info.RangeGlobalImprovements=info.RangeGlobalImprovements+1;
                        else
                            info.ClassicGlobalImprovements=info.ClassicGlobalImprovements+1;
                        end
                    end
                    if Best.Cost<oldCandidateBest && isnan(info.FirstImprovementEvaluation)
                        info.FirstImprovementEvaluation=info.Evaluations;
                    end
                    T(info.Evaluations)=Best.Cost;
                end
                pop(i,:)=localVector;
                if localCost<parentCost
                    realPop(i,:)=localVector;
                elseif wasVirtual && ~isempty(selected)
                    % Do not keep a virtual parent after a real evaluation fails.
                    pop(i,:)=realPop(i,:);
                end
                fitness(i)=localCost;
            end
        end

        if modePreserving
            targetTrace=info.TargetTracingEvaluations(end);
            targetSeek=info.TargetSeekingEvaluations(end);
            info.ActualTracingEvaluations(end+1)=roundTraceEvaluations;
            info.ActualSeekingEvaluations(end+1)=roundSeekEvaluations;
            info.BudgetFillRate(end+1)=(roundTraceEvaluations+roundSeekEvaluations+roundRecovery)/ ...
                max(1,budgetThisRound);
            info.ModeAllocationError(end+1,:)=[roundTraceEvaluations-targetTrace ...
                roundSeekEvaluations-targetSeek];
        end
        if frozenSelection
            info.SeekingParentCoverage(end+1)=nnz(seekParentCounts);
            info.SeekingConcentration(end+1)=sum((seekParentCounts/ ...
                max(1,roundSeekEvaluations)).^2);
            info.SeekingMaxParentEvaluations(end+1)=max(seekParentCounts);
            info.SeekingGlobalImprovementCounts(end+1)=seekGlobalCount;
            info.TracingGlobalImprovementCounts(end+1)=traceGlobalCount;
            info.SeekingGlobalGain(end+1)=seekGlobalGain;
            info.TracingGlobalGain(end+1)=traceGlobalGain;
        end
        modeImproved=Best.Cost<modeBestBefore;
        improved=Best.Cost<oldBest;
        info.RecoveryImprovementPerRound(end+1)=recoveryImproved;
        oldStall=stall;
        if improved
            stall=0;
        else
            stall=stall+1;
        end
        newCenter=mean(pop,1);
        newDiversity=mean(sqrt(sum((pop-newCenter).^2,2)));
        globalReward=max(0,(oldBest-Best.Cost)/(abs(oldBest)+eps));
        seekSuccessHistory(end+1)=roundSeekSuccess;
        seekEvaluationHistory(end+1)=roundSeekEvaluations;
        traceSuccessHistory(end+1)=roundTraceSuccess;
        traceEvaluationHistory(end+1)=roundTraceEvaluations;
        seekGainHistory(end+1)=roundSeekGain;
        traceGainHistory(end+1)=roundTraceGain;
        localGain=max(0,(oldFitness(evaluated)-fitness(evaluated))./ ...
            (abs(oldFitness(evaluated))+eps));
        if isempty(localGain)
            populationReward=0;
        else
            populationReward=mean(localGain);
        end
        modeSuccessRate=(roundSeekSuccess+roundTraceSuccess)/ ...
            max(1,roundSeekEvaluations+roundTraceEvaluations);
        modeEfficiency=(roundSeekGain+roundTraceGain)/ ...
            max(1,roundSeekEvaluations+roundTraceEvaluations);
        info.SeekingSuccessHistory(end+1)=roundSeekSuccess/ ...
            max(1,roundSeekEvaluations);
        info.TracingSuccessHistory(end+1)=roundTraceSuccess/ ...
            max(1,roundTraceEvaluations);
        info.ModeSuccessRateHistory(end+1)=modeSuccessRate;
        info.ModeEfficiencyHistory(end+1)=modeEfficiency;
        if familyScheduler && useRL && strcmp(familyReward,'seeking')
            reward=2*roundSeekSuccess/max(1,roundSeekEvaluations)-1;
            if seekingImproved
                reward=10;
            end
        elseif modeAwareV2
            globalEfficiency=max(0,(oldBest-Best.Cost)/ ...
                (abs(oldBest)+abs(Best.Cost)+eps));
            reward=5*globalEfficiency+modeEfficiency;
        elseif modeAwareV41
            reward=2*modeSuccessRate-1;
            if modeImproved
                reward=10;
            end
        elseif modeAwareV4
            reward=2*modeSuccessRate-1;
            if improved
                reward=10;
            end
        elseif modeAware || modeSampleV3
            reward=2*modeSuccessRate-1;
            if improved
                reward=10;
            elseif oldStall>=10 && action==4
                reward=max(reward,0.5);
            end
        elseif paperMode
            reward=-1;
            if improved
                reward=10;
            elseif oldStall>=10 && (action==3 || action==4)
                reward=0.5;
            end
        elseif useContinuousReward
            reward=0.70*globalReward+0.30*populationReward;
        else
            reward=-1;
            if improved
                reward=10;
            elseif stall>=10 && action==4
                reward=0.5;
            end
        end
        info.RewardHistory(end+1)=reward;
        info.GlobalRewardHistory(end+1)=globalReward;
        info.PopulationRewardHistory(end+1)=populationReward;
        if useRL
            nextProgress=(info.Evaluations-sizepop)/max(1,budget-sizepop);
            nextRatio=newDiversity/max(initialDiversity,eps);
            if familyScheduler
                nextFamilyStatus=FamilyStatus(classicSamples,rangeSamples, ...
                    minimumSamples,modeThreshold);
            else
                nextFamilyStatus=2;
            end
            if modeSampleV3
                nextModeStatus=SampleModeStatus(seekSamples,traceSamples, ...
                    minimumSamples,modeThreshold);
            else
                nextModeStatus=ModeStatus(seekSuccessHistory, ...
                    seekEvaluationHistory,traceSuccessHistory, ...
                    traceEvaluationHistory,seekGainHistory, ...
                    traceGainHistory,modeWindow,modeThreshold,modeAwareV2);
            end
            if familyScheduler
                if useFamilySignal
                    nextState=ModeAwareStateIndex(nextProgress,stall, ...
                        nextFamilyStatus);
                else
                    nextState=StateIndex(nextProgress,stall,nextRatio, ...
                        false,diversityThreshold);
                end
            elseif (modeAware || modeAwareV2 || modeSampleV3) && useModeSignal
                nextState=ModeAwareStateIndex(nextProgress,stall, ...
                    nextModeStatus);
            else
                nextState=StateIndex(nextProgress,stall,nextRatio, ...
                    useDiversityState,diversityThreshold);
            end
            Q(stateIndex,action)=Q(stateIndex,action)+alpha* ...
                (reward+gamma*max(Q(nextState,:))-Q(stateIndex,action));
        end
        info.EvaluationsPerRound(end+1)=info.Evaluations-roundStart;
        info.SeekingEvaluationsPerRound(end+1)=roundSeekEvaluations;
        info.TracingEvaluationsPerRound(end+1)=roundTraceEvaluations;
        info.RecoveryEvaluationsPerRound(end+1)=roundRecovery;
    end
    T=T(1:info.Evaluations);
    info.Algorithm='DSS_RLCSO';
    info.Seed=seed;
    info.Q=Q;
    info.Stall=stall;
    info.CatStall=catStall;
    info.FinalSeekSamples=seekSamples;
    info.FinalTraceSamples=traceSamples;
    info.Seconds=toc(clockStart);
end

function cats=SelectCats(distBest,distCenter,catCount)
    [~,near]=sort(distBest);
    [~,far]=sort(distCenter,'descend');
    cats=unique([near(1:ceil(catCount/2));far(1:floor(catCount/2))],'stable');
    if numel(cats)<catCount
        extra=setdiff((1:numel(distBest))',cats,'stable');
        cats=[cats;extra(1:catCount-numel(cats))];
    end
end

function [modeStatus,rates]=SampleModeStatus(seekSamples,traceSamples,minimum,threshold)
    modeStatus=2;
    rates=[NaN NaN];
    if ~isempty(seekSamples),rates(1)=mean(seekSamples);end
    if ~isempty(traceSamples),rates(2)=mean(traceSamples);end
    if numel(seekSamples)<minimum || numel(traceSamples)<minimum
        return
    end
    if rates(1)>rates(2)+threshold
        modeStatus=1;
    elseif rates(2)>rates(1)+threshold
        modeStatus=3;
    end
end

function familyStatus=FamilyStatus(classicSamples,rangeSamples,minimum,threshold)
    familyStatus=2;
    if numel(classicSamples)<minimum || numel(rangeSamples)<minimum
        return
    end
    classicRate=mean(classicSamples);
    rangeRate=mean(rangeSamples);
    if classicRate>rangeRate+threshold
        familyStatus=1;
    elseif rangeRate>classicRate+threshold
        familyStatus=3;
    end
end

function [mr,srd,cdc,jump,peerLearn,opposition]=ActionParameters(action,rlMode)
    jump=false;
    peerLearn=false;
    opposition=false;
    if strcmp(rlMode,'modeAwareV4') || strcmp(rlMode,'modeAwareV41')
        mrValues=[0.20 0.40 0.60];
        mr=mrValues(min(action,3));
        srd=0.05;
        cdc=0.20;
        return
    end
    if strcmp(rlMode,'paper')
        switch action
            case 1
                mr=0.60; srd=0.03; cdc=0.20;
            case 2
                mr=0.40; srd=0.10; cdc=0.40; peerLearn=true;
            case 3
                mr=0.20; srd=0.15; cdc=0.60; jump=true;
            otherwise
                mr=0.20; srd=0.20; cdc=0.60; opposition=true;
        end
        return
    end
    switch action
        case 1
            mr=0.20; srd=0.05; cdc=0.20;
        case 2
            mr=0.20; srd=0.30; cdc=0.80;
        case 3
            mr=0.60; srd=0.10; cdc=0.40;
        otherwise
            mr=0.40; srd=0.25; cdc=0.70; jump=true;
    end
end

function peer=OtherCat(i,sizepop)
    peer=randi(sizepop-1);
    if peer>=i
        peer=peer+1;
    end
end

function modeStatus=ModeStatus(seekSuccess,seekEvaluations, ...
    traceSuccess,traceEvaluations,seekGain,traceGain,windowSize, ...
    threshold,useEfficiency)
    if isempty(seekSuccess)
        modeStatus=2;
        return
    end
    first=max(1,numel(seekSuccess)-windowSize+1);
    seekEvaluationsWindow=sum(seekEvaluations(first:end));
    traceEvaluationsWindow=sum(traceEvaluations(first:end));
    if useEfficiency
        if seekEvaluationsWindow<2 || traceEvaluationsWindow<2
            modeStatus=2;
            return
        end
        seekRate=sum(seekGain(first:end))/seekEvaluationsWindow;
        traceRate=sum(traceGain(first:end))/traceEvaluationsWindow;
    else
        seekRate=sum(seekSuccess(first:end))/max(1,seekEvaluationsWindow);
        traceRate=sum(traceSuccess(first:end))/max(1,traceEvaluationsWindow);
    end
    if seekRate>traceRate+threshold
        modeStatus=1;
    elseif traceRate>seekRate+threshold
        modeStatus=3;
    else
        modeStatus=2;
    end
end

function stateIndex=ModeAwareStateIndex(progress,stall,modeStatus)
    if progress<0.3
        phase=1;
    elseif progress<0.7
        phase=2;
    else
        phase=3;
    end
    if stall==0
        status=1;
    elseif stall<10
        status=2;
    else
        status=3;
    end
    stateIndex=(phase-1)*9+(status-1)*3+modeStatus;
end

function stateIndex=StateIndex(progress,stall,diversityRatio,useDiversityState,threshold)
    if progress<0.3
        phase=1;
    elseif progress<0.7
        phase=2;
    else
        phase=3;
    end
    if stall==0
        status=1;
    elseif stall<10
        status=2;
    else
        status=3;
    end
    if useDiversityState
        if diversityRatio<threshold
            diversityState=1;
        else
            diversityState=2;
        end
        stateIndex=(phase-1)*6+(status-1)*2+diversityState;
    else
        stateIndex=(phase-1)*3+status;
    end
end

function selected=CandidateScreen(copies,best,center,quota)
    candidates=2:size(copies,1);
    dBest=sum((copies(candidates,:)-best).^2,2);
    dCenter=sum((copies(candidates,:)-center).^2,2);
    [~,near]=min(dBest);
    [~,far]=max(dCenter);
    order=unique([candidates(near),candidates(far)],'stable');
    order=[order,setdiff(candidates,order,'stable')];
    selected=order(1:min(quota,numel(order)));
end

function plan=RandomCandidateScreen(pool,catIds,quota,parentCap)
    plan=cell(numel(pool),1);
    if quota==0 || isempty(catIds)
        return
    end
    pairs=zeros(0,2);
    for i=catIds(:)'
        candidateIds=2:size(pool{i},1);
        pairs=[pairs;repmat(i,numel(candidateIds),1),candidateIds(:)]; %#ok<AGROW>
    end
    pairs=pairs(randperm(size(pairs,1)),:);
    counts=zeros(numel(pool),1);
    selectedCount=0;
    for q=1:size(pairs,1)
        i=pairs(q,1);
        if counts(i)>=parentCap
            continue
        end
        plan{i}(end+1)=pairs(q,2); %#ok<AGROW>
        counts(i)=counts(i)+1;
        selectedCount=selectedCount+1;
        if selectedCount>=quota
            break
        end
    end
end

function plan=MatchedRandomScreen(pool,catIds,referencePlan)
    plan=cell(numel(pool),1);
    counts=sort(cellfun(@numel,referencePlan),'descend');
    counts=counts(counts>0);
    if isempty(counts)
        return
    end
    parents=catIds(randperm(numel(catIds),numel(counts)));
    for q=1:numel(counts)
        i=parents(q);
        plan{i}=1+randperm(size(pool{i},1)-1,counts(q));
    end
end

function plan=CompensationCandidateScreen(pool,catIds,basePlan,best, ...
        lastRealEvaluationFE,currentFE,selectionMode)
    plan=basePlan;
    counts=cellfun(@numel,plan);
    eligible=catIds(counts(catIds)<2);
    available=false(size(eligible));
    for q=1:numel(eligible)
        available(q)=numel(setdiff(2:size(pool{eligible(q)},1),plan{eligible(q)}))>0;
    end
    eligible=eligible(available);
    if isempty(eligible)
        return
    end
    if strcmp(selectionMode,'g2Age')
        age=currentFE-lastRealEvaluationFE(eligible);
        bestAge=max(age);
        eligible=eligible(age==bestAge);
    end
    parent=eligible(randi(numel(eligible)));
    candidates=setdiff(2:size(pool{parent},1),plan{parent});
    distances=sum((pool{parent}(candidates,:)-best).^2,2);
    [~,index]=min(distances);
    plan{parent}(end+1)=candidates(index);
end

function plan=SourceAwareCandidateScreen(pool,catIds,basePlan,best,center, ...
        pop,eliteVectors,lb,ub)
    plan=basePlan;
    counts=cellfun(@numel,plan);
    bestProgress=-inf;
    bestParent=0;
    bestCandidate=0;
    for q=1:numel(catIds)
        i=catIds(q);
        if counts(i)>=2
            continue
        end
        candidates=setdiff(2:size(pool{i},1),plan{i});
        if isempty(candidates)
            continue
        end
        parentDistance=norm(pop(i,:)-eliteVectors(i,:));
        denominator=max(parentDistance,1e-6*norm(ub-lb));
        candidateDistance=sqrt(sum((pool{i}(candidates,:)-eliteVectors(i,:)).^2,2));
        progress=(parentDistance-candidateDistance)/denominator;
        [value,index]=max(progress);
        if value>bestProgress
            bestProgress=value;
            bestParent=i;
            bestCandidate=candidates(index);
        end
    end
    if bestParent==0
        plan=GlobalCandidateScreen(pool,catIds,best,center,3,2);
    else
        plan{bestParent}(end+1)=bestCandidate;
    end
end

function plan=CoverageSourceAwareCandidateScreen(pool,catIds,basePlan, ...
        sourcePlan,pop,eliteVectors,lb,ub)
    plan=basePlan;
    baseCounts=cellfun(@numel,basePlan);
    sourceCounts=cellfun(@numel,sourcePlan);
    added=find(sourceCounts>baseCounts);
    if isempty(added)
        return
    end
    sourceParent=added(1);
    sourceWasUncovered=baseCounts(sourceParent)==0;
    if sourceWasUncovered
        eligible=catIds(baseCounts(catIds)==0);
    else
        eligible=catIds(baseCounts(catIds)>0 & baseCounts(catIds)<2);
    end
    if isempty(eligible)
        eligible=catIds(baseCounts(catIds)<2);
    end
    if isempty(eligible)
        return
    end
    parent=eligible(randperm(numel(eligible),1));
    candidates=setdiff(2:size(pool{parent},1),plan{parent});
    if isempty(candidates)
        return
    end
    parentDistance=norm(pop(parent,:)-eliteVectors(parent,:));
    denominator=max(parentDistance,1e-6*norm(ub-lb));
    candidateDistance=sqrt(sum((pool{parent}(candidates,:)- ...
        eliteVectors(parent,:)).^2,2));
    progress=(parentDistance-candidateDistance)/denominator;
    [~,index]=max(progress);
    plan{parent}(end+1)=candidates(index);
end

function plan=GlobalCandidateScreen(pool,catIds,best,center,quota,parentCap)
    plan=cell(numel(pool),1);
    if quota==0
        return
    end
    points=cell(numel(catIds),1);
    for q=1:numel(catIds)
        points{q}=pool{catIds(q)}(2:end,:);
    end
    points=vertcat(points{:});
    perCat=size(pool{catIds(1)},1)-1;
    parents=repelem(catIds,perCat);
    candidates=repmat((2:perCat+1)',numel(catIds),1);
    [~,near]=sort(sum((points-best).^2,2));
    [~,far]=sort(sum((points-center).^2,2),'descend');
    selected=false(size(parents));
    counts=zeros(numel(pool),1);
    % 先选 ceil(B/2) 个近优候选，再选剩余的远中心候选。
    orders={near,far};
    targets=[ceil(quota/2),quota];
    for phase=1:2
        if nnz(selected)>=targets(phase)
            continue
        end
        for q=1:numel(parents)
            index=orders{phase}(q);
            parent=parents(index);
            if ~selected(index) && counts(parent)<parentCap
                selected(index)=true;
                counts(parent)=counts(parent)+1;
                plan{parent}(end+1)=candidates(index);
            end
            if nnz(selected)>=targets(phase)
                break
            end
        end
    end
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end

