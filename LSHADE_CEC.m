function [Best,T,info] = LSHADE_CEC(f,state,~,Particle_Number,seed)
    % 按 Tanabe/Fukunaga 的 L-SHADE 1.0.1 MATLAB 代码适配 FE 接口。
    % 来源和适配说明见 data/cec2017/baseline_sources.md。
    clockStart=tic;
    pop=state.initialPopulation;
    D=size(pop,2);
    sizepop=Particle_Number;
    initialSize=sizepop;
    minSize=4;
    pBestRate=0.11;
    archiveRate=1.4;
    memorySize=5;
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
    info.PopulationHistory=sizepop;
    info.ArchiveSizeHistory=0;
    memoryF=0.5*ones(memorySize,1);
    memoryCR=0.5*ones(memorySize,1);
    memoryPos=1;
    archive=zeros(0,D);
    archiveCapacity=round(archiveRate*sizepop);

    while info.Evaluations<budget
        [~,order]=sort(fitness);
        memoryIndex=ceil(memorySize*rand(sizepop,1));
        muF=memoryF(memoryIndex);
        muCR=memoryCR(memoryIndex);
        CR=muCR+0.1*randn(sizepop,1);
        CR(muCR==-1)=0;
        CR=max(0,min(1,CR));
        F=muF+0.1*tan(pi*(rand(sizepop,1)-0.5));
        bad=find(F<=0);
        while ~isempty(bad)
            F(bad)=muF(bad)+0.1*tan(pi*(rand(numel(bad),1)-0.5));
            bad=find(F<=0);
        end
        F=min(1,F);

        pool=[pop;archive];
        [r1,r2]=RandomParents(sizepop,size(pool,1));
        pCount=max(round(pBestRate*sizepop),2);
        pIndex=max(1,ceil(rand(1,sizepop)*pCount));
        pbest=pop(order(pIndex),:);
        mutant=pop+F.*(pbest-pop+pop(r1,:)-pool(r2,:));
        lower=repmat(lb,sizepop,1);
        upper=repmat(ub,sizepop,1);
        outside=mutant<lower;
        mutant(outside)=(pop(outside)+lower(outside))/2;
        outside=mutant>upper;
        mutant(outside)=(pop(outside)+upper(outside))/2;
        mask=rand(sizepop,D)>CR;
        jrand=sub2ind([sizepop D],(1:sizepop)',floor(rand(sizepop,1)*D)+1);
        mask(jrand)=false;
        trial=mutant;
        trial(mask)=pop(mask);

        % 最后一代只评价剩余候选；未评价的父代保留。
        count=min(sizepop,budget-info.Evaluations);
        values=fitness;
        for i=1:count
            values(i)=f(trial(i,:));
            info.Evaluations=info.Evaluations+1;
            oldBest=Best.Cost;
            Best=UpdateBest(Best,trial(i,:),values(i));
            if Best.Cost<oldBest && isnan(info.FirstImprovementEvaluation)
                info.FirstImprovementEvaluation=info.Evaluations;
            end
            T(info.Evaluations)=Best.Cost;
        end
        improved=values<fitness;
        goodF=F(improved);
        goodCR=CR(improved);
        gain=fitness(improved)-values(improved);
        archive=unique([archive;pop(improved,:)],'rows');
        if size(archive,1)>archiveCapacity
            archive=archive(randperm(size(archive,1),archiveCapacity),:);
        end
        accepted=false(sizepop,1);
        accepted(1:count)=values(1:count)<fitness(1:count);
        pop(accepted,:)=trial(accepted,:);
        fitness(accepted)=values(accepted);

        if ~isempty(goodF)
            weights=gain/sum(gain);
            memoryF(memoryPos)=sum(weights.*goodF.^2)/sum(weights.*goodF);
            if max(goodCR)==0 || memoryCR(memoryPos)==-1
                memoryCR(memoryPos)=-1;
            else
                memoryCR(memoryPos)=sum(weights.*goodCR.^2)/sum(weights.*goodCR);
            end
            memoryPos=mod(memoryPos,memorySize)+1;
        end
        plannedSize=max(minSize,round(initialSize+ ...
            (minSize-initialSize)*info.Evaluations/budget));
        if sizepop>plannedSize
            [~,order]=sort(fitness);
            pop=pop(order(1:plannedSize),:);
            fitness=fitness(order(1:plannedSize));
            sizepop=plannedSize;
            archiveCapacity=round(archiveRate*sizepop);
            if size(archive,1)>archiveCapacity
                archive=archive(randperm(size(archive,1),archiveCapacity),:);
            end
        end
        info.PopulationHistory(end+1)=sizepop;
        info.ArchiveSizeHistory(end+1)=size(archive,1);
    end
    info.Algorithm='LSHADE_CEC';
    info.Seed=seed;
    info.MemoryF=memoryF;
    info.MemoryCR=memoryCR;
    info.FinalPopulationSize=sizepop;
    info.Seconds=toc(clockStart);
end

function [r1,r2]=RandomParents(sizepop,poolSize)
    r0=1:sizepop;
    r1=floor(rand(1,sizepop)*sizepop)+1;
    bad=r1==r0;
    while any(bad)
        r1(bad)=floor(rand(1,sum(bad))*sizepop)+1;
        bad=r1==r0;
    end
    r2=floor(rand(1,sizepop)*poolSize)+1;
    bad=r2==r0 | r2==r1;
    while any(bad)
        r2(bad)=floor(rand(1,sum(bad))*poolSize)+1;
        bad=r2==r0 | r2==r1;
    end
end

function Best=UpdateBest(Best,vector,cost)
    if cost<Best.Cost
        Best.Vector=vector;
        Best.Cost=cost;
    end
end
