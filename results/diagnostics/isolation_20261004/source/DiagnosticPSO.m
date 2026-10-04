function [Best,T,info] = DiagnosticPSO(model,state,maxgen,Particle_Number,seed,mode,fixedRoute)
    % teacher风格：pop/V/pbest/gbest数组、直接循环、独立评价函数。
    clockStart=tic;
    sizepop=Particle_Number;
    c1=1.5;
    c2=1.5;
    Vmax=0.15;
    %% 初始化：直接使用main传入的共同种群
    pop=state.initialPopulation;
    n=length(state.activeIDs);
    if strcmp(mode,'ControlOnly'),n=0;end
    D=size(pop,2);
    rng(seed);
    V=0.01*(2*rand(sizepop,D)-1);
    V(:,1:n)=3*V(:,1:n);
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
    previousRoute=zeros(sizepop,length(state.activeIDs));
    for i=1:sizepop
        [fitness(i),detail]=EvaluateDiagnostic(pop(i,:),model,state,mode,fixedRoute);
        feasible(i)=detail.feasible;
        previousRoute(i,:)=detail.route;
        if feasible(i) && isnan(info.FirstFeasibleEvaluation)
            info.FirstFeasibleEvaluation=i;
        end
        if (feasible(i)&&~Best.Detail.feasible) || (feasible(i)==Best.Detail.feasible&&fitness(i)<Best.Cost)
            Best.Vector=pop(i,:);
            Best.Route=detail.route;
            if isfield(detail,'control'),Best.Control=detail.control;end
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
    info.RouteChanges=0;info.RouteTransitions=0;


    %% 更新
    pbest=pop;
    fitnesspbest=fitness;
    feasiblepbest=feasible;
    gbest=Best.Vector;
    while info.Evaluations<info.Budget
        info.Iterations=info.Iterations+1;
        w=0.9-0.5*(info.Evaluations-sizepop)/(info.Budget-sizepop);
        for i=1:sizepop
            if info.Evaluations>=info.Budget
                break;
            end
            V(i,:)=w*V(i,:)+c1*rand(1,size(pop,2)).*(pbest(i,:)-pop(i,:)) ...
                +c2*rand(1,size(pop,2)).*(gbest-pop(i,:));
            V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
            pop(i,:)=max(0,min(1,pop(i,:)+V(i,:)));
            [fitness(i),detail]=EvaluateDiagnostic(pop(i,:),model,state,mode,fixedRoute);
            feasible(i)=detail.feasible;
            info.RouteTransitions=info.RouteTransitions+1;
            info.RouteChanges=info.RouteChanges+~isequal(previousRoute(i,:),detail.route);
            previousRoute(i,:)=detail.route;
            info.Evaluations=info.Evaluations+1;
            if feasible(i) && isnan(info.FirstFeasibleEvaluation)
                info.FirstFeasibleEvaluation=info.Evaluations;
            end
            info.FeasibleEvaluations=info.FeasibleEvaluations+feasible(i);
            if (feasible(i)&&~feasiblepbest(i)) || (feasible(i)==feasiblepbest(i)&&fitness(i)<fitnesspbest(i))
                pbest(i,:)=pop(i,:);
                fitnesspbest(i)=fitness(i);
                feasiblepbest(i)=feasible(i);
            end
            if (feasible(i)&&~Best.Detail.feasible) || (feasible(i)==Best.Detail.feasible&&fitness(i)<Best.Cost)
                Best.Vector=pop(i,:);
                Best.Route=detail.route;
                if isfield(detail,'control'),Best.Control=detail.control;end
                Best.Cost=fitness(i);
                Best.Detail=detail;
                gbest=pop(i,:);
            end
            T(info.Evaluations)=Best.Cost;
        end
    end
    info.Algorithm=['PSO / ' mode];
    info.Seconds=toc(clockStart);
    info.Improved=Best.Detail.feasible && Best.Cost<info.InitialCost-1e-8;
    T=T(1:info.Evaluations);
end
