function [Best,T,info] = DSS_RLCSO(f,state,~,Particle_Number,seed)
    % 双层空间筛选 + Q-learning 调度的猫群优化原型。
    clockStart=tic;
    sizepop=Particle_Number;
    SMP=5;
    rho=0.10;
    alpha=0.10;
    gamma=0.90;
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
    info.CandidateEvaluations=0;
    stall=0;
    Q=zeros(9,4);

    while info.Evaluations<budget
        progress=(info.Evaluations-sizepop)/max(1,budget-sizepop);
        stateIndex=StateIndex(progress,stall);
        epsilon=0.50-0.45*progress;
        if rand<epsilon
            action=randi(4);
        else
            [~,action]=max(Q(stateIndex,:));
        end
        info.ActionCounts(action)=info.ActionCounts(action)+1;
        [mr,srd,cdc,jump]=ActionParameters(action);
        oldBest=Best.Cost;
        budgetThisRound=min(ceil(rho*sizepop),budget-info.Evaluations);
        catCount=min(sizepop,max(2,ceil(budgetThisRound/2)));
        center=mean(pop,1);
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
        remaining=budgetThisRound;

        for k=1:numel(cats)
            if remaining<=0
                break;
            end
            i=cats(k);
            if rand<mr
                V(i,:)=V(i,:)+2*rand(1,D).*(Best.Vector-pop(i,:));
                V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
                if jump
                    sigma=0.10*(1-progress);
                    trial=Best.Vector+sigma*randn(1,D).*(ub-lb);
                else
                    trial=pop(i,:)+V(i,:);
                end
                trial=max(lb,min(ub,trial));
                value=f(trial);
                info.Evaluations=info.Evaluations+1;
                info.CandidateEvaluations=info.CandidateEvaluations+1;
                remaining=remaining-1;
                if value<fitness(i)
                    pop(i,:)=trial;
                    fitness(i)=value;
                end
                Best=UpdateBest(Best,trial,value);
                T(info.Evaluations)=Best.Cost;
            else
                copies=repmat(pop(i,:),SMP,1);
                for j=2:SMP
                    if jump
                        sigma=0.10*(1-progress);
                        copies(j,:)=Best.Vector+sigma*randn(1,D).*(ub-lb);
                    else
                        d=randperm(D,max(1,round(cdc*D)));
                        copies(j,d)=copies(j,d)+srd*(ub(d)-lb(d)) ...
                            .*(2*rand(1,numel(d))-1);
                    end
                    copies(j,:)=max(lb,min(ub,copies(j,:)));
                end
                quota=min(2,remaining);
                selected=CandidateScreen(copies,Best.Vector,center,quota);
                localCost=fitness(i);
                localVector=pop(i,:);
                for j=selected
                    if remaining<=0
                        break;
                    end
                    value=f(copies(j,:));
                    info.Evaluations=info.Evaluations+1;
                    info.CandidateEvaluations=info.CandidateEvaluations+1;
                    remaining=remaining-1;
                    if value<localCost
                        localCost=value;
                        localVector=copies(j,:);
                    end
                    Best=UpdateBest(Best,copies(j,:),value);
                    T(info.Evaluations)=Best.Cost;
                end
                pop(i,:)=localVector;
                fitness(i)=localCost;
            end
        end

        improved=Best.Cost<oldBest;
        if improved
            stall=0;
            if isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
        else
            stall=stall+1;
        end
        reward=-1;
        if improved
            reward=10;
        elseif stall>=10 && action==4
            reward=0.5;
        end
        nextState=StateIndex((info.Evaluations-sizepop)/max(1,budget-sizepop),stall);
        Q(stateIndex,action)=Q(stateIndex,action)+alpha* ...
            (reward+gamma*max(Q(nextState,:))-Q(stateIndex,action));
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

function stateIndex=StateIndex(progress,stall)
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
    stateIndex=(phase-1)*3+status;
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
