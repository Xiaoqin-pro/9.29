function [Best,T,info] = GWO_CEC(f,state,~,Particle_Number,seed)
    % Mirjalili et al. (2014), CEC2017 统一 FE 接口。
    clockStart=tic;
    sizepop=Particle_Number;
    pop=state.initialPopulation;
    D=size(pop,2);
    lb=state.lowerBound;
    ub=state.upperBound;
    budget=state.maxEvaluations;
    assert(sizepop>=4 && budget>=sizepop);
    rng(seed);

    fitness=zeros(sizepop,1);
    T=nan(budget,1);
    Best.Cost=inf;
    for i=1:sizepop
        fitness(i)=f(pop(i,:));
        Best=UpdateBest(Best,pop(i,:),fitness(i));
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.InitialCost=Best.Cost;
    info.InitialPopulation=pop;
    info.FirstImprovementEvaluation=NaN;
    leaders=pop;
    leaderCost=fitness;

    while info.Evaluations<budget
        [~,order]=sort(leaderCost);
        alpha=leaders(order(1),:);
        beta=leaders(order(2),:);
        delta=leaders(order(3),:);
        a=2*(1-(info.Evaluations-sizepop)/max(1,budget-sizepop));
        for i=1:sizepop
            if info.Evaluations>=budget,break;end
            X=zeros(3,D);
            leadersNow={alpha,beta,delta};
            for j=1:3
                A=2*a*rand(1,D)-a;
                C=2*rand(1,D);
                X(j,:)=leadersNow{j}-A.*abs(C.*leadersNow{j}-pop(i,:));
            end
            trial=max(lb,min(ub,mean(X,1)));
            value=f(trial);
            info.Evaluations=info.Evaluations+1;
            oldBest=Best.Cost;
            Best=UpdateBest(Best,trial,value);
            if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            if value<fitness(i)
                pop(i,:)=trial;
                fitness(i)=value;
            end
            leaders(i,:)=pop(i,:);
            leaderCost(i)=fitness(i);
            T(info.Evaluations)=Best.Cost;
        end
    end
    T=T(1:info.Evaluations);
    info.Algorithm='GWO_CEC';
    info.Seed=seed;
    info.Seconds=toc(clockStart);
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end
