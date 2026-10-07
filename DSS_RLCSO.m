function [Best,T,info] = DSS_RLCSO(f,state,~,Particle_Number,seed)
    % 双层空间筛选 + Q-learning；modeAware 保留旧版，modeAwareV3 修正流程。
    clockStart=tic;
    sizepop=Particle_Number;
    SMP=5;
    rho=0.10;
    alpha=0.10;
    gamma=0.90;
    useCatScreen=true;
    useCandidateScreen=true;
    useRL=true;
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
    if isfield(state,'rlMode')
        rlMode=state.rlMode;
    end
    useContinuousReward=strcmp(rlMode,'continuous') || strcmp(rlMode,'v3');
    useDiversityState=strcmp(rlMode,'diversity') || strcmp(rlMode,'v3');
    paperMode=strcmp(rlMode,'paper');
    modeAware=strcmp(rlMode,'modeAware');
    modeAwareV2=strcmp(rlMode,'modeAwareV2');
    modeAwareV3=strcmp(rlMode,'modeAwareV3');
    diversityThreshold=0.50;
    pop=state.initialPopulation;
    D=size(pop,2);
    lb=state.lowerBound;
    ub=state.upperBound;
    rng(seed);
    V=0.01*(2*rand(sizepop,D)-1).*(ub-lb);
    Vmax=0.2*(ub-lb);
    budget=state.maxEvaluations;
    assert(budget>=sizepop,'Evaluation budget must cover initialization.');

    T=nan(budget,1);
    fitness=zeros(sizepop,1);
    Best.Cost=inf;
    for i=1:sizepop
        fitness(i)=f(pop(i,:));
        Best=UpdateBest(Best,pop(i,:),fitness(i));
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.InitialCost=Best.Cost;
    info.InitialPopulation=state.initialPopulation;
    info.FirstImprovementEvaluation=NaN;
    info.ActionCounts=zeros(1,4);
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
    info.ModeAware=modeAware || modeAwareV2 || modeAwareV3;
    info.ModeAwareV2=modeAwareV2;
    info.ModeAwareV3=modeAwareV3;
    info.SeekingEvaluationsPerRound=[];
    info.TracingEvaluationsPerRound=[];
    info.ModeSampleCounts=[];
    info.ModeWindowRates=[];
    info.OpportunitySelectionChanged=[];
    info.RewardHistory=[];
    info.GlobalRewardHistory=[];
    info.PopulationRewardHistory=[];
    info.DiversityStateHistory=[];
    info.ModeStateHistory=[];
    info.SeekingSuccessHistory=[];
    info.TracingSuccessHistory=[];
    info.ModeSuccessRateHistory=[];
    info.ModeEfficiencyHistory=[];
    info.StateHistory=[];
    info.StateVisitCounts=[];
    info.StateActionCounts=[];
    stall=0;
    initialCenter=mean(pop,1);
    initialDiversity=mean(sqrt(sum((pop-initialCenter).^2,2)));
    if modeAware || modeAwareV2 || modeAwareV3
        qStateCount=27;
    elseif useDiversityState
        qStateCount=18;
    else
        qStateCount=9;
    end
    info.QStateCount=qStateCount;
    info.StateVisitCounts=zeros(qStateCount,1);
    info.StateActionCounts=zeros(qStateCount,4);
    Q=zeros(qStateCount,4);
    seekSuccessHistory=[];
    seekEvaluationHistory=[];
    traceSuccessHistory=[];
    traceEvaluationHistory=[];
    seekGainHistory=[];
    traceGainHistory=[];
    modeWindow=5;
    modeThreshold=0.05;
    seekSamples=[];
    traceSamples=[];
    sampleWindow=20;
    minimumSamples=10;

    while info.Evaluations<budget
        roundStart=info.Evaluations;
        progress=(info.Evaluations-sizepop)/max(1,budget-sizepop);
        center=mean(pop,1);
        diversity=mean(sqrt(sum((pop-center).^2,2)));
        diversityRatio=diversity/max(initialDiversity,eps);
        if modeAwareV3
            [modeStatus,rates]=SampleModeStatus(seekSamples,traceSamples, ...
                minimumSamples,modeThreshold);
            info.ModeSampleCounts(end+1,:)=[numel(seekSamples) numel(traceSamples)];
            info.ModeWindowRates(end+1,:)=rates;
        else
            modeStatus=ModeStatus(seekSuccessHistory,seekEvaluationHistory, ...
                traceSuccessHistory,traceEvaluationHistory,seekGainHistory, ...
                traceGainHistory,modeWindow,modeThreshold,modeAwareV2);
        end
        if modeAware || modeAwareV2 || modeAwareV3
            stateIndex=ModeAwareStateIndex(progress,stall,modeStatus);
        else
            stateIndex=StateIndex(progress,stall,diversityRatio, ...
                useDiversityState,diversityThreshold);
        end
        epsilon=0.50-0.45*progress;
        if strcmp(actionMode,'fixed')
            action=4;
        elseif strcmp(actionMode,'fixed1')
            action=1;
        elseif strcmp(actionMode,'fixed3')
            action=3;
        elseif strcmp(actionMode,'random')
            action=randi(4);
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
        elseif useRL && rand<epsilon
            action=randi(4);
        elseif useRL
            [~,action]=max(Q(stateIndex,:));
        else
            action=1;
        end
        info.ActionCounts(action)=info.ActionCounts(action)+1;
        info.ActionHistory(end+1)=action;
        info.StateHistory(end+1)=stateIndex;
        info.StateVisitCounts(stateIndex)=info.StateVisitCounts(stateIndex)+1;
        info.StateActionCounts(stateIndex,action)= ...
            info.StateActionCounts(stateIndex,action)+1;
        info.ModeStateHistory(end+1)=modeStatus;
        [mr,srd,cdc,jump,peerLearn,opposition]=ActionParameters(action,rlMode);
        oldBest=Best.Cost;
        oldFitness=fitness;
        evaluated=false(sizepop,1);
        roundSeekEvaluations=0;
        roundSeekSuccess=0;
        roundTraceEvaluations=0;
        roundTraceSuccess=0;
        roundSeekGain=0;
        roundTraceGain=0;

        if useCatScreen
            budgetThisRound=min(ceil(rho*sizepop),budget-info.Evaluations);
            catCount=min(sizepop,max(2,ceil(budgetThisRound/2)));
        else
            budgetThisRound=min(sizepop,budget-info.Evaluations);
            catCount=sizepop;
        end
        info.DiversityHistory(end+1)=diversity;
        info.DiversityStateHistory(end+1)=diversityRatio;
        info.StallHistory(end+1)=stall;
        if useCatScreen && ~modeAwareV3
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
        elseif ~modeAwareV3
            cats=(1:sizepop)';
        end
        if ~modeAwareV3
            cats=cats(randperm(numel(cats)));
            info.SelectedCatCounts(end+1)=numel(cats);
            info.CatSelectionCounts(cats)=info.CatSelectionCounts(cats)+1;
        end

        trial=pop;
        trialVelocity=V;
        tracing=false(sizepop,1);
        seekingPool=cell(sizepop,1);
        for i=1:sizepop
            if rand<mr
                tracing(i)=true;
                if paperMode && peerLearn
                    peer=OtherCat(i,sizepop);
                    trialVelocity(i,:)=0.9*V(i,:)+1.5*rand(1,D).* ...
                        (pop(peer,:)-pop(i,:));
                elseif paperMode && action==1
                    trialVelocity(i,:)=0.4*V(i,:)+ ...
                        1.0*rand(1,D).*(Best.Vector-pop(i,:))+ ...
                        2.5*rand(1,D).*(Best.Vector-pop(i,:));
                else
                    trialVelocity(i,:)=V(i,:)+2*rand(1,D).* ...
                        (Best.Vector-pop(i,:));
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
                for j=2:SMP
                    if opposition
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
                    else
                        d=randperm(D,max(1,round(cdc*D)));
                        copies(j,d)=copies(j,d).*(1+srd*(2*rand(1,numel(d))-1));
                    end
                    copies(j,:)=max(lb,min(ub,copies(j,:)));
                end
                seekingPool{i}=copies;
            end
        end

        % V3：全部新候选先参与空间评分，再分配真实评价机会。
        if modeAwareV3
            if useCatScreen
                distBest=zeros(sizepop,1);
                distCenter=zeros(sizepop,1);
                for i=1:sizepop
                    if tracing(i)
                        candidates=trial(i,:);
                    else
                        candidates=seekingPool{i}(2:end,:); % 排除缓存父代
                    end
                    distBest(i)=min(sum((candidates-Best.Vector).^2,2));
                    distCenter(i)=max(sum((candidates-center).^2,2));
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

        remaining=budgetThisRound;
        for k=1:numel(cats)
            if remaining<=0
                break;
            end
            i=cats(k);
            if tracing(i)
                evaluated(i)=true;
                oldLocalCost=fitness(i);
                value=f(trial(i,:));
                info.Evaluations=info.Evaluations+1;
                info.TracingEvaluations=info.TracingEvaluations+1;
                info.CandidateEvaluations=info.CandidateEvaluations+1;
                roundTraceEvaluations=roundTraceEvaluations+1;
                if value<oldLocalCost
                    roundTraceSuccess=roundTraceSuccess+1;
                end
                if modeAwareV3
                    traceSamples=[traceSamples value<oldLocalCost];
                    traceSamples=traceSamples(max(1,end-sampleWindow+1):end);
                end
                roundTraceGain=roundTraceGain+max(0,(oldLocalCost-value)/ ...
                    (abs(oldLocalCost)+abs(value)+eps));
                remaining=remaining-1;
                V(i,:)=trialVelocity(i,:);
                pop(i,:)=trial(i,:);
                fitness(i)=value;
                oldCandidateBest=Best.Cost;
                Best=UpdateBest(Best,trial(i,:),value);
                if Best.Cost<oldCandidateBest && isnan(info.FirstImprovementEvaluation)
                    info.FirstImprovementEvaluation=info.Evaluations;
                end
                T(info.Evaluations)=Best.Cost;
            else
                copies=seekingPool{i};
                if useCandidateScreen
                    quota=min(2,remaining);
                    selected=CandidateScreen(copies,Best.Vector,center,quota);
                else
                    selected=2:size(copies,1);
                    selected=selected(1:min(numel(selected),remaining));
                end
                if ~isempty(selected)
                    evaluated(i)=true;
                end
                localCost=fitness(i);
                parentCost=fitness(i);
                localVector=pop(i,:);
                for j=selected
                    if remaining<=0
                        break;
                    end
                    value=f(copies(j,:));
                    info.Evaluations=info.Evaluations+1;
                    info.SeekingEvaluations=info.SeekingEvaluations+1;
                    info.CandidateEvaluations=info.CandidateEvaluations+1;
                    roundSeekEvaluations=roundSeekEvaluations+1;
                    successCost=localCost;
                    if modeAwareV3
                        successCost=parentCost;
                        seekSamples=[seekSamples value<parentCost];
                        seekSamples=seekSamples(max(1,end-sampleWindow+1):end);
                    end
                    if value<successCost
                        roundSeekSuccess=roundSeekSuccess+1;
                    end
                    roundSeekGain=roundSeekGain+max(0,(successCost-value)/ ...
                        (abs(successCost)+abs(value)+eps));
                    remaining=remaining-1;
                    if value<localCost
                        localCost=value;
                        localVector=copies(j,:);
                    end
                    oldCandidateBest=Best.Cost;
                    Best=UpdateBest(Best,copies(j,:),value);
                    if Best.Cost<oldCandidateBest && isnan(info.FirstImprovementEvaluation)
                        info.FirstImprovementEvaluation=info.Evaluations;
                    end
                    T(info.Evaluations)=Best.Cost;
                end
                pop(i,:)=localVector;
                fitness(i)=localCost;
            end
        end

        improved=Best.Cost<oldBest;
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
        if modeAwareV2
            globalEfficiency=max(0,(oldBest-Best.Cost)/ ...
                (abs(oldBest)+abs(Best.Cost)+eps));
            reward=5*globalEfficiency+modeEfficiency;
        elseif modeAware || modeAwareV3
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
            if modeAwareV3
                nextModeStatus=SampleModeStatus(seekSamples,traceSamples, ...
                    minimumSamples,modeThreshold);
            else
                nextModeStatus=ModeStatus(seekSuccessHistory, ...
                    seekEvaluationHistory,traceSuccessHistory, ...
                    traceEvaluationHistory,seekGainHistory, ...
                    traceGainHistory,modeWindow,modeThreshold,modeAwareV2);
            end
            if modeAware || modeAwareV2 || modeAwareV3
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
    end
    T=T(1:info.Evaluations);
    info.Algorithm='DSS_RLCSO';
    info.Seed=seed;
    info.Q=Q;
    info.Stall=stall;
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

function [mr,srd,cdc,jump,peerLearn,opposition]=ActionParameters(action,rlMode)
    jump=false;
    peerLearn=false;
    opposition=false;
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

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end
