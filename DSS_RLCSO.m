function [Best,T,info] = DSS_RLCSO(f,state,~,Particle_Number,seed)
    % DSS-RLCSO V2：全体试探位置 + 双层空间筛选 + Q-learning。
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
    info.RewardHistory=[];
    info.GlobalRewardHistory=[];
    info.PopulationRewardHistory=[];
    info.DiversityStateHistory=[];
    stall=0;
    initialCenter=mean(pop,1);
    initialDiversity=mean(sqrt(sum((pop-initialCenter).^2,2)));
    if useDiversityState
        qStateCount=18;
    else
        qStateCount=9;
    end
    info.QStateCount=qStateCount;
    Q=zeros(qStateCount,4);

    while info.Evaluations<budget
        roundStart=info.Evaluations;
        progress=(info.Evaluations-sizepop)/max(1,budget-sizepop);
        center=mean(pop,1);
        diversity=mean(sqrt(sum((pop-center).^2,2)));
        diversityRatio=diversity/max(initialDiversity,eps);
        stateIndex=StateIndex(progress,stall,diversityRatio, ...
            useDiversityState,diversityThreshold);
        epsilon=0.50-0.45*progress;
        if strcmp(actionMode,'fixed')
            action=4;
        elseif strcmp(actionMode,'random')
            action=randi(4);
        elseif useRL && rand<epsilon
            action=randi(4);
        elseif useRL
            [~,action]=max(Q(stateIndex,:));
        else
            action=1;
        end
        info.ActionCounts(action)=info.ActionCounts(action)+1;
        info.ActionHistory(end+1)=action;
        [mr,srd,cdc,jump]=ActionParameters(action);
        oldBest=Best.Cost;
        oldFitness=fitness;
        evaluated=false(sizepop,1);

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
        if useCatScreen
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
        else
            cats=(1:sizepop)';
        end
        cats=cats(randperm(numel(cats)));
        info.SelectedCatCounts(end+1)=numel(cats);
        info.CatSelectionCounts(cats)=info.CatSelectionCounts(cats)+1;

        trial=pop;
        trialVelocity=V;
        tracing=false(sizepop,1);
        seekingPool=cell(sizepop,1);
        for i=1:sizepop
            if rand<mr
                tracing(i)=true;
                trialVelocity(i,:)=V(i,:)+2*rand(1,D).*(Best.Vector-pop(i,:));
                trialVelocity(i,:)=max(-Vmax,min(Vmax,trialVelocity(i,:)));
                if jump
                    sigma=0.10*(1-progress);
                    trial(i,:)=Best.Vector+sigma*randn(1,D).*(ub-lb);
                else
                    trial(i,:)=pop(i,:)+trialVelocity(i,:);
                end
                trial(i,:)=max(lb,min(ub,trial(i,:)));
            else
                copies=repmat(pop(i,:),SMP,1);
                for j=2:SMP
                    if jump
                        sigma=0.10*(1-progress);
                        copies(j,:)=Best.Vector+sigma*randn(1,D).*(ub-lb);
                    else
                        d=randperm(D,max(1,round(cdc*D)));
                        copies(j,d)=copies(j,d).*(1+srd*(2*rand(1,numel(d))-1));
                    end
                    copies(j,:)=max(lb,min(ub,copies(j,:)));
                end
                seekingPool{i}=copies;
            end
        end

        remaining=budgetThisRound;
        for k=1:numel(cats)
            if remaining<=0
                break;
            end
            i=cats(k);
            if tracing(i)
                evaluated(i)=true;
                value=f(trial(i,:));
                info.Evaluations=info.Evaluations+1;
                info.TracingEvaluations=info.TracingEvaluations+1;
                info.CandidateEvaluations=info.CandidateEvaluations+1;
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
                localVector=pop(i,:);
                for j=selected
                    if remaining<=0
                        break;
                    end
                    value=f(copies(j,:));
                    info.Evaluations=info.Evaluations+1;
                    info.SeekingEvaluations=info.SeekingEvaluations+1;
                    info.CandidateEvaluations=info.CandidateEvaluations+1;
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
        if improved
            stall=0;
        else
            stall=stall+1;
        end
        newCenter=mean(pop,1);
        newDiversity=mean(sqrt(sum((pop-newCenter).^2,2)));
        globalReward=max(0,(oldBest-Best.Cost)/(abs(oldBest)+eps));
        localGain=max(0,(oldFitness(evaluated)-fitness(evaluated))./ ...
            (abs(oldFitness(evaluated))+eps));
        if isempty(localGain)
            populationReward=0;
        else
            populationReward=mean(localGain);
        end
        if useContinuousReward
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
            nextState=StateIndex(nextProgress,stall,nextRatio, ...
                useDiversityState,diversityThreshold);
            Q(stateIndex,action)=Q(stateIndex,action)+alpha* ...
                (reward+gamma*max(Q(nextState,:))-Q(stateIndex,action));
        end
        info.EvaluationsPerRound(end+1)=info.Evaluations-roundStart;
    end
    T=T(1:info.Evaluations);
    info.Algorithm='DSS_RLCSO';
    info.Seed=seed;
    info.Q=Q;
    info.Stall=stall;
    info.Seconds=toc(clockStart);
end

function [mr,srd,cdc,jump]=ActionParameters(action)
    jump=false;
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
