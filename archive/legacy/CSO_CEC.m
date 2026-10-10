function [Best,T,info] = CSO_CEC(f,state,~,Particle_Number,seed)
    clockStart=tic;
    sizepop=Particle_Number;
    SMP=5;
    SRD=0.05;
    CDC=0.20;
    MR=0.20;
    c=2;
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
    info.SeekingEvaluations=0;
    info.TracingEvaluations=0;

    while info.Evaluations<budget
        tracing=false(sizepop,1);
        tracing(randperm(sizepop,max(1,round(MR*sizepop))))=true;
        for i=1:sizepop
            if info.Evaluations>=budget
                break;
            end
            if tracing(i)
                V(i,:)=V(i,:)+c*rand(1,D).*(Best.Vector-pop(i,:));
                V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
                pop(i,:)=max(lb,min(ub,pop(i,:)+V(i,:)));
                value=f(pop(i,:));
                info.Evaluations=info.Evaluations+1;
                info.TracingEvaluations=info.TracingEvaluations+1;
                oldBest=Best.Cost;
                Best=UpdateBest(Best,pop(i,:),value);
                if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                    info.FirstImprovementEvaluation=info.Evaluations;
                end
                fitness(i)=value;
                T(info.Evaluations)=Best.Cost;
            else
                copies=repmat(pop(i,:),SMP,1);
                values=inf(SMP,1);
                tested=false(SMP,1);
                values(1)=fitness(i);
                tested(1)=true;
                for j=2:SMP
                    if info.Evaluations>=budget
                        break;
                    end
                    d=randperm(D,max(1,round(CDC*D)));
                    copies(j,d)=copies(j,d).*(1+SRD*(2*rand(1,numel(d))-1));
                    copies(j,:)=max(lb,min(ub,copies(j,:)));
                    values(j)=f(copies(j,:));
                    tested(j)=true;
                    info.Evaluations=info.Evaluations+1;
                    info.SeekingEvaluations=info.SeekingEvaluations+1;
                    oldBest=Best.Cost;
                    Best=UpdateBest(Best,copies(j,:),values(j));
                    if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                        info.FirstImprovementEvaluation=info.Evaluations;
                    end
                    T(info.Evaluations)=Best.Cost;
                end
                pool=find(tested);
                quality=values(pool);
                span=max(quality)-min(quality);
                probability=ones(size(quality));
                if span>eps
                    probability=(max(quality)-quality)/span;
                end
                probability=probability/sum(probability);
                chosen=pool(find(rand<=cumsum(probability),1));
                if isempty(chosen),chosen=pool(end);end
                pop(i,:)=copies(chosen,:);
                fitness(i)=values(chosen);
            end
        end
    end
    T=T(1:info.Evaluations);
    info.Algorithm='CSO_CEC';
    info.Seed=seed;
    info.Seconds=toc(clockStart);
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end

