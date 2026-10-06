function [Best,T,info] = SCSO(model,state,maxgen,Particle_Number,seed)
    %SCSO Sand Cat Swarm Optimization，保留统一FE预算和可行性优先规则。
    % 原始SCSO使用递减感知范围，在搜索和捕获两个阶段更新位置。
    clockStart=tic;
    sizepop=Particle_Number;
    pop=state.initialPopulation;
    D=size(pop,2);
    rng(seed);
    budget=sizepop*(maxgen+1);
    if isfield(state,'maxEvaluations')
        budget=state.maxEvaluations;
    end
    assert(sizepop>=4 && budget>=sizepop,'Use at least 4 particles and a budget covering initialization.');

    fitness=zeros(sizepop,1);
    feasible=false(sizepop,1);
    T=nan(budget,1);
    Best.Cost=inf;
    Best.Detail.feasible=false;
    info.FirstFeasibleEvaluation=NaN;

    %% 共同初始种群
    for i=1:sizepop
        [fitness(i),detail]=Fitness(pop(i,:),model,state);
        feasible(i)=detail.feasible;
        if feasible(i) && isnan(info.FirstFeasibleEvaluation)
            info.FirstFeasibleEvaluation=i;
        end
        Best=UpdateBest(Best,pop(i,:),fitness(i),detail);
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.Budget=budget;
    info.FeasibleEvaluations=sum(feasible);
    info.InitialCost=Best.Cost;
    info.InitialFeasible=Best.Detail.feasible;
    info.InitialPopulation=state.initialPopulation;
    info.Seed=seed;
    info.Iterations=0;

    %% 感知范围从2线性下降到0；|R|>1为搜索，否则为捕获。
    while info.Evaluations<info.Budget
        info.Iterations=info.Iterations+1;
        rG=2*(1-(info.Evaluations-sizepop)/(info.Budget-sizepop));
        for i=1:sizepop
            if info.Evaluations>=info.Budget
                break;
            end
            R=2*rG*rand-rG;
            sensitivity=rG*rand;
            theta=2*pi*rand;
            randomIndex=randi(sizepop);
            if abs(R)>1
                candidate=sensitivity*(pop(randomIndex,:)-rand(1,D).*pop(i,:));
            else
                randomPosition=rand(1,D).*Best.Vector-pop(i,:);
                candidate=Best.Vector-sensitivity*randomPosition*cos(theta);
            end
            candidate=max(0,min(1,candidate));
            [candidateCost,candidateDetail]=Fitness(candidate,model,state);
            info.Evaluations=info.Evaluations+1;
            feasible(i)=candidateDetail.feasible;
            fitness(i)=candidateCost;
            info.FeasibleEvaluations=info.FeasibleEvaluations+candidateDetail.feasible;
            if candidateDetail.feasible && isnan(info.FirstFeasibleEvaluation)
                info.FirstFeasibleEvaluation=info.Evaluations;
            end
            pop(i,:)=candidate;
            Best=UpdateBest(Best,candidate,candidateCost,candidateDetail);
            T(info.Evaluations)=Best.Cost;
        end
    end
    info.Algorithm='SCSO';
    info.Seconds=toc(clockStart);
    info.Improved=Best.Detail.feasible && Best.Cost<info.InitialCost-1e-8;
    T=T(1:info.Evaluations);
end

function Best=UpdateBest(Best,vector,cost,detail)
    better=(detail.feasible && ~Best.Detail.feasible) || ...
        (detail.feasible==Best.Detail.feasible && cost<Best.Cost);
    if better
        Best.Vector=vector;
        Best.Route=detail.route;
        Best.Control=detail.control;
        Best.Cost=cost;
        Best.Detail=detail;
    end
end
