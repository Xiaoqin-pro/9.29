function [Best,T,info] = CLPSO(model,state,maxgen,Particle_Number,seed)
    % 逐维综合学习：两粒子竞争选择pbest，连续7代未改善刷新学习对象。
    % Liang et al. (2006), doi:10.1109/TEVC.2005.857610。
    clockStart=tic;
    sizepop=Particle_Number;
    c=1.49445;
    gap=7;
    Vmax=0.15;
    %% 初始化：直接使用main传入的共同种群
    pop=state.initialPopulation;
    n=length(state.activeIDs);
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
    for i=1:sizepop
        [fitness(i),detail]=Fitness(pop(i,:),model,state);
        feasible(i)=detail.feasible;
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
    D=size(pop,2);
    pbest=pop;
    fitnesspbest=fitness;
    feasiblepbest=feasible;
    Pc=0.05+0.45*(exp(10*(0:sizepop-1)'/(sizepop-1))-1)/(exp(10)-1);
    exemplar=repmat((1:sizepop)',1,D);
    stall=gap*ones(sizepop,1);
    info.RefreshCount=0;
    while info.Evaluations<info.Budget
        info.Iterations=info.Iterations+1;
        w=0.9-0.5*(info.Evaluations-sizepop)/(info.Budget-sizepop);
        for i=1:sizepop
            if info.Evaluations>=info.Budget
                break;
            end
            if stall(i)>=gap
                exemplar(i,:)=i;
                others=setdiff(1:sizepop,i);
                for d=1:D
                    if rand<Pc(i)
                        pair=others(randperm(length(others),2));
                        a=pair(1);
                        b=pair(2);
                        if (feasiblepbest(b)&&~feasiblepbest(a)) || (feasiblepbest(b)==feasiblepbest(a)&&fitnesspbest(b)<fitnesspbest(a))
                            a=b;
                        end
                        exemplar(i,d)=a;
                    end
                end
                if all(exemplar(i,:)==i)
                    exemplar(i,randi(D))=others(randi(length(others)));
                end
                stall(i)=0;
                info.RefreshCount=info.RefreshCount+1;
            end
            target=pbest(sub2ind(size(pbest),exemplar(i,:),1:D));
            V(i,:)=w*V(i,:)+c*rand(1,D).*(target-pop(i,:));
            V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
            pop(i,:)=max(0,min(1,pop(i,:)+V(i,:)));
            [fitness(i),detail]=Fitness(pop(i,:),model,state);
            feasible(i)=detail.feasible;
            info.Evaluations=info.Evaluations+1;
            info.FeasibleEvaluations=info.FeasibleEvaluations+feasible(i);
            if (feasible(i)&&~feasiblepbest(i)) || (feasible(i)==feasiblepbest(i)&&fitness(i)<fitnesspbest(i))
                pbest(i,:)=pop(i,:);
                fitnesspbest(i)=fitness(i);
                feasiblepbest(i)=feasible(i);
                stall(i)=0;
            else
                stall(i)=stall(i)+1;
            end
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
    info.Algorithm='CLPSO';
    info.Seconds=toc(clockStart);
    info.Improved=Best.Detail.feasible && Best.Cost<info.InitialCost-1e-8;
    T=T(1:info.Evaluations);
end
