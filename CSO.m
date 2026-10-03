function [Best,T,info] = CSO(model,state,maxgen,Particle_Number,seed)
    % 猫群：Seeking(复制、部分维度变异、概率选择) + Tracing(速度追踪)。
    % Chu, Tsai & Pan (2006), doi:10.1007/978-3-540-36668-3_94。
    clockStart=tic;
    sizepop=Particle_Number;
    SMP=5;
    SRD=0.05;
    CDC=0.20;
    MR=0.20;
    c=2;
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
    Vmax=0.15;
    info.SeekingEvaluations=0;
    info.TracingEvaluations=0;
    while info.Evaluations<info.Budget
        info.Iterations=info.Iterations+1;
        tracing=false(sizepop,1);
        tracing(randperm(sizepop,max(1,round(MR*sizepop))))=true;
        for i=1:sizepop
            if info.Evaluations>=info.Budget
                break;
            end
            if tracing(i)
                V(i,:)=V(i,:)+c*rand(1,D).*(Best.Vector-pop(i,:));
                V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
                copies=max(0,min(1,pop(i,:)+V(i,:)));
                values=inf;
                flags=false;
                start=1;
            else
                % SPC=true：保留当前位置，不重复评价它。
                copies=repmat(pop(i,:),SMP,1);
                values=inf(SMP,1);
                flags=false(SMP,1);
                values(1)=fitness(i);
                flags(1)=feasible(i);
                start=2;
                for j=2:SMP
                    d=randperm(D,max(1,round(CDC*D)));
                    direction=2*(rand(1,length(d))>0.5)-1;
                    copies(j,d)=copies(j,d).*(1+SRD*direction);
                end
                copies=max(0,min(1,copies));
            end
            last=start-1;
            for j=start:size(copies,1)
                if info.Evaluations>=info.Budget
                    break;
                end
                [values(j),detail]=Fitness(copies(j,:),model,state);
                flags(j)=detail.feasible;
                info.Evaluations=info.Evaluations+1;
                last=j;
                info.FeasibleEvaluations=info.FeasibleEvaluations+flags(j);
                if tracing(i)
                    info.TracingEvaluations=info.TracingEvaluations+1;
                else
                    info.SeekingEvaluations=info.SeekingEvaluations+1;
                end
                if (flags(j)&&~Best.Detail.feasible) || (flags(j)==Best.Detail.feasible&&values(j)<Best.Cost)
                    Best.Vector=copies(j,:);
                    Best.Route=detail.route;
                    Best.Control=detail.control;
                    Best.Cost=values(j);
                    Best.Detail=detail;
                end
                T(info.Evaluations)=Best.Cost;
            end
            pool=find(isfinite(values(1:last)));
            if any(flags(pool))
                pool=pool(flags(pool));
            end
            quality=values(pool);
            span=max(quality)-min(quality);
            probability=ones(size(quality));
            if span>eps
                probability=(max(quality)-quality)/span;
            end
            probability=probability/sum(probability);
            chosen=pool(find(rand<=cumsum(probability),1));
            pop(i,:)=copies(chosen,:);
            fitness(i)=values(chosen);
            feasible(i)=flags(chosen);
        end
    end
    info.Algorithm='CSO (Cat Swarm)';
    info.Seconds=toc(clockStart);
    info.Improved=Best.Detail.feasible && Best.Cost<info.InitialCost-1e-8;
    T=T(1:info.Evaluations);
end
