function [Best,T,info] = GWO(model,state,maxgen,Particle_Number,seed)
    % alpha/beta/delta三领导者引导；a从2降到0。保存历史最优三领导者。
    % Mirjalili et al. (2014), doi:10.1016/j.advengsoft.2013.12.007。
    clockStart=tic;
    sizepop=Particle_Number;
    %% 初始化：直接使用main传入的共同种群
    pop=state.initialPopulation;
    D=size(pop,2);
    rng(seed);
    rand(sizepop,D); % 与其他算法初始化后的随机数序列对齐，不引入速度变量。
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
    for i=1:sizepop
        [fitness(i),detail]=Fitness(pop(i,:),model,state);
        feasible(i)=detail.feasible;
        if feasible(i) && isnan(info.FirstFeasibleEvaluation)
            info.FirstFeasibleEvaluation=i;
        end
        if (feasible(i)&&~Best.Detail.feasible) || (feasible(i)==Best.Detail.feasible&&fitness(i)<Best.Cost)
            Best.Vector=pop(i,:);
            Best.Route=detail.route;
            Best.Control=detail.control;
            Best.Cost=fitness(i);
            Best.Detail=detail;
        end
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.Budget=budget;
    info.FeasibleEvaluations=sum(feasible);
    info.InitialCost=Best.Cost;
    info.InitialFeasible=Best.Detail.feasible;
    info.InitialPopulation=pop;
    info.Seed=seed;
    info.Iterations=0;

    %% 更新
    [~,index]=sortrows([~feasible fitness],[1 2]);
    leaders=pop(index(1:3),:);
    leaderCost=fitness(index(1:3));
    leaderFeasible=feasible(index(1:3));
    D=size(pop,2);
    while info.Evaluations<info.Budget
        info.Iterations=info.Iterations+1;
        a=2*(1-(info.Evaluations-sizepop)/(info.Budget-sizepop));
        currentLeaders=leaders;
        for i=1:sizepop
            if info.Evaluations>=info.Budget
                break;
            end
            X=zeros(3,D);
            for j=1:3
                A=2*a*rand(1,D)-a;
                C=2*rand(1,D);
                X(j,:)=currentLeaders(j,:)-A.*abs(C.*currentLeaders(j,:)-pop(i,:));
            end
            pop(i,:)=max(0,min(1,mean(X,1)));
            [fitness(i),detail]=Fitness(pop(i,:),model,state);
            feasible(i)=detail.feasible;
            info.Evaluations=info.Evaluations+1;
            if feasible(i) && isnan(info.FirstFeasibleEvaluation)
                info.FirstFeasibleEvaluation=info.Evaluations;
            end
            info.FeasibleEvaluations=info.FeasibleEvaluations+feasible(i);
            pool=[leaders;pop(i,:)];
            values=[leaderCost;fitness(i)];
            flags=[leaderFeasible;feasible(i)];
            [~,index]=sortrows([~flags values],[1 2]);
            leaders=pool(index(1:3),:);
            leaderCost=values(index(1:3));
            leaderFeasible=flags(index(1:3));
            if (feasible(i)&&~Best.Detail.feasible) || (feasible(i)==Best.Detail.feasible&&fitness(i)<Best.Cost)
                Best.Vector=pop(i,:);
                Best.Route=detail.route;
                Best.Control=detail.control;
                Best.Cost=fitness(i);
                Best.Detail=detail;
            end
            T(info.Evaluations)=Best.Cost;
        end
    end
    info.Algorithm='GWO';
    info.Seconds=toc(clockStart);
    info.Improved=Best.Detail.feasible && Best.Cost<info.InitialCost-1e-8;
    T=T(1:info.Evaluations);
end
