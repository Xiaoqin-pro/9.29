function [Best,T,info] = PSO_CEC(f,state,~,Particle_Number,seed)
    clockStart=tic;
    sizepop=Particle_Number;
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
    Best.Cost=inf;
    fitness=zeros(sizepop,1);
    for i=1:sizepop
        fitness(i)=f(pop(i,:));
        Best=UpdateBest(Best,pop(i,:),fitness(i));
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.InitialCost=Best.Cost;
    info.InitialPopulation=state.initialPopulation;
    info.FirstImprovementEvaluation=NaN;
    pbest=pop;
    pbestCost=fitness;
    gbest=Best.Vector;

    while info.Evaluations<budget
        w=0.9-0.5*(info.Evaluations-sizepop)/max(1,budget-sizepop);
        for i=1:sizepop
            if info.Evaluations>=budget
                break;
            end
            V(i,:)=w*V(i,:)+1.5*rand(1,D).*(pbest(i,:)-pop(i,:)) ...
                +1.5*rand(1,D).*(gbest-pop(i,:));
            V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
            pop(i,:)=max(lb,min(ub,pop(i,:)+V(i,:)));
            value=f(pop(i,:));
            info.Evaluations=info.Evaluations+1;
            if value<pbestCost(i)
                pbest(i,:)=pop(i,:);
                pbestCost(i)=value;
            end
            oldBest=Best.Cost;
            Best=UpdateBest(Best,pop(i,:),value);
            if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            gbest=Best.Vector;
            T(info.Evaluations)=Best.Cost;
        end
    end
    T=T(1:info.Evaluations);
    info.Algorithm='PSO_CEC';
    info.Seed=seed;
    info.Seconds=toc(clockStart);
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end

