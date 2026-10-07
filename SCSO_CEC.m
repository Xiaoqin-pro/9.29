function [Best,T,info] = SCSO_CEC(f,state,~,Particle_Number,seed)
    % SCSO 的 CEC2017 统一 FE 接口；搜索/捕获由感知范围控制。
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

    while info.Evaluations<budget
        rG=2*(1-(info.Evaluations-sizepop)/max(1,budget-sizepop));
        for i=1:sizepop
            if info.Evaluations>=budget,break;end
            R=2*rG*rand-rG;
            sensitivity=rG*rand;
            theta=2*pi*rand;
            randomIndex=randi(sizepop);
            if abs(R)>1
                trial=sensitivity*(pop(randomIndex,:)-rand(1,D).*pop(i,:));
            else
                distance=abs(rand(1,D).*Best.Vector-pop(i,:));
                trial=Best.Vector-sensitivity*distance*cos(theta);
            end
            trial=max(lb,min(ub,trial));
            value=f(trial);
            info.Evaluations=info.Evaluations+1;
            oldBest=Best.Cost;
            Best=UpdateBest(Best,trial,value);
            if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            pop(i,:)=trial;
            fitness(i)=value;
            T(info.Evaluations)=Best.Cost;
        end
    end
    T=T(1:info.Evaluations);
    info.Algorithm='SCSO_CEC';
    info.Seed=seed;
    info.Seconds=toc(clockStart);
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end
