function [Best,T,info] = CLPSO_CEC(f,state,~,Particle_Number,seed)
    % Liang et al. (2006), doi:10.1109/TEVC.2005.857610。
    clockStart=tic;
    sizepop=Particle_Number;
    c=1.49445;
    gap=7;
    pop=state.initialPopulation;
    D=size(pop,2);
    lb=state.lowerBound;
    ub=state.upperBound;
    budget=state.maxEvaluations;
    rng(seed);
    V=0.01*(2*rand(sizepop,D)-1).*(ub-lb);
    Vmax=0.15*(ub-lb);
    assert(sizepop>=4 && budget>=sizepop);

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
    info.RefreshCount=0;
    pbest=pop;
    pbestCost=fitness;
    Pc=0.05+0.45*(exp(10*(0:sizepop-1)'/(sizepop-1))-1)/(exp(10)-1);
    exemplar=repmat((1:sizepop)',1,D);
    stall=gap*ones(sizepop,1);

    while info.Evaluations<budget
        w=0.9-0.5*(info.Evaluations-sizepop)/max(1,budget-sizepop);
        for i=1:sizepop
            if info.Evaluations>=budget,break;end
            if stall(i)>=gap
                exemplar(i,:)=i;
                others=setdiff(1:sizepop,i);
                for d=1:D
                    if rand<Pc(i)
                        pair=others(randperm(numel(others),2));
                        [~,winner]=min(pbestCost(pair));
                        exemplar(i,d)=pair(winner);
                    end
                end
                if all(exemplar(i,:)==i)
                    exemplar(i,randi(D))=others(randi(numel(others)));
                end
                stall(i)=0;
                info.RefreshCount=info.RefreshCount+1;
            end
            target=pbest(sub2ind(size(pbest),exemplar(i,:),1:D));
            V(i,:)=w*V(i,:)+c*rand(1,D).*(target-pop(i,:));
            V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
            pop(i,:)=max(lb,min(ub,pop(i,:)+V(i,:)));
            value=f(pop(i,:));
            info.Evaluations=info.Evaluations+1;
            if value<pbestCost(i)
                pbest(i,:)=pop(i,:);
                pbestCost(i)=value;
                stall(i)=0;
            else
                stall(i)=stall(i)+1;
            end
            oldBest=Best.Cost;
            Best=UpdateBest(Best,pop(i,:),value);
            if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            T(info.Evaluations)=Best.Cost;
        end
    end
    info.Algorithm='CLPSO_CEC';
    info.Seed=seed;
    info.Seconds=toc(clockStart);
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end
