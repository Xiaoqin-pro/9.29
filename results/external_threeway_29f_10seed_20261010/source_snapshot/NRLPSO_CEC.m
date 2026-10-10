function [Best,T,info] = NRLPSO_CEC(f,state,N,seed)
% NRLPSO_CEC
% MATLAB adapter of the public MetaBox NRLPSO_Optimizer implementation.
% This is a third-party reimplementation adapter, not an author release.
clockStart=tic;
NP=N; pop=state.initialPopulation; D=size(pop,2);
lb=state.lowerBound; ub=state.upperBound; maxFEs=state.maxEvaluations;
rng(seed,'twister');
assert(size(pop,1)==NP && maxFEs>=NP);
velocity=zeros(NP,D); vmin=-0.1*(ub-lb); vmax=-vmin;
fitness=zeros(NP,1); pbest=pop; pbestCost=zeros(NP,1);
Best.Cost=inf; Best.Vector=pop(1,:); T=nan(maxFEs,1); fe=0;
for i=1:NP
    fitness(i)=f(pop(i,:)); fe=fe+1; pbestCost(i)=fitness(i);
    if fitness(i)<Best.Cost, Best.Cost=fitness(i); Best.Vector=pop(i,:); end
    T(fe)=Best.Cost;
end
pbestStag=zeros(NP,1); pointer=1; q=zeros(4,4); gamma=0.8;
maxSteps=max(1,ceil((maxFEs-NP)/NP)); learnStep=0; alpha=1.0;
rw=rand; u=0.6; vpar=0.33; wmin=0.4; wmax=1.0; k=min(5,NP-1);
stateVec=randi(4,NP,1);
info=struct(); info.Algorithm='NRLPSO_CEC_third_party_adapter'; info.Seed=seed;
info.Evaluations=fe; info.InitialCost=Best.Cost; info.InitialPopulation=pop;
info.NP=NP; info.k=k; info.QTable=zeros(4,4); info.MutationEvaluations=0;
while fe<maxFEs
    if pointer==1
        [pbestNeb,pbestNebIdx,gbestNeb,gbestNebIdx]=buildNeighborhood(pop,pbest,Best.Vector,k);
        rw=4*rw*(1-rw);
        frac=fe/maxFEs;
        w=u-(frac*rw*wmin+vpar*(wmax-wmin)*frac);
    end
    i=pointer;
    qrow=q(stateVec(i),:); qrow=qrow-max(qrow); pr=exp(qrow); pr=pr/sum(pr);
    action=find(rand<=cumsum(pr),1,'first');
    if isempty(action), action=4; end
    cs=cosineSafe(pbest(i,:),Best.Vector);
    r1=rand; r2=rand; cur=pop(i,:);
    switch action
        case 1 % exploration
            if cs<0
                P1=pbest(i,:); P2=gbestNeb(randi(size(gbestNeb,1)),:);
                velocity(i,:)=w*velocity(i,:)+2.2*r1*(P1-cur)+1.8*r2*(P2-cur);
            else
                P1=pbestNeb(i,randi(k),:); P1=reshape(P1,1,D);
                velocity(i,:)=w*velocity(i,:)+2.2*r1*(P1-cur);
            end
        case 2 % exploitation
            if cs<0
                P1=pbestNeb(i,randi(k),:); P1=reshape(P1,1,D); P2=Best.Vector;
                velocity(i,:)=w*velocity(i,:)+2.1*r1*(P1-cur)+1.8*r2*(P2-cur);
            else
                P2=gbestNeb(randi(size(gbestNeb,1)),:);
                velocity(i,:)=w*velocity(i,:)+1.8*r2*(P2-cur);
            end
        case 3 % convergence
            if cs<0
                P1=pbest(i,:); P2=Best.Vector;
                velocity(i,:)=w*velocity(i,:)+2*r1*(P1-cur)+2*r2*(P2-cur);
            else
                velocity(i,:)=w*velocity(i,:)+2*r2*(Best.Vector-cur);
            end
        otherwise % jumping out
            P1=pbestNeb(i,randi(k),:); P1=reshape(P1,1,D);
            P2=gbestNeb(randi(size(gbestNeb,1)),:);
            velocity(i,:)=w*velocity(i,:)+1.8*rand(1,D).*(P1-cur)+2.2*rand(1,D).*(P2-cur);
    end
    velocity(i,:)=max(vmin,min(vmax,velocity(i,:)));
    dOld=meanDistance(pop); efOld=normalizedDistance(dOld,i);
    pop(i,:)=max(lb,min(ub,pop(i,:)+velocity(i,:)));
    dNew=meanDistance(pop); efNew=normalizedDistance(dNew,i);
    fOld=fitness(i); fNew=f(pop(i,:)); fe=fe+1;
    if isnan(efOld), efOld=0; end; if isnan(efNew), efNew=0; end
    cond1=fNew<fOld; cond2=efNew>efOld;
    if cond1 && cond2, reward=2; elseif cond1, reward=1; elseif cond2, reward=0; else, reward=-2; end
    fitness(i)=fNew;
    if fNew<pbestCost(i)
        pbest(i,:)=pop(i,:); pbestCost(i)=fNew; pbestStag(i)=0;
    else
        pbestStag(i)=pbestStag(i)+1;
    end
    if pbestStag(i)>=2 && fe<maxFEs
        [pop,pbest,pbestCost,fitness,Best,fe,me]=neighborMutation(i,pop,pbest,pbestCost,fitness,Best,pbestNeb,pbestNebIdx,gbestNeb,gbestNebIdx,f,fe,maxFEs,D);
        info.MutationEvaluations=info.MutationEvaluations+me;
    end
    if fNew<Best.Cost, Best.Cost=fNew; Best.Vector=pop(i,:); end
    stateNext=action;
    td=reward+gamma*max(q(stateNext,:))-q(stateVec(i),action);
    q(stateVec(i),action)=q(stateVec(i),action)+alpha*td;
    stateVec(i)=stateNext;
    learnStep=learnStep+1; alpha=1-(1-0.1)*min(1,learnStep/maxSteps);
    if fe>=1, T(fe)=Best.Cost; end
    pointer=pointer+1; if pointer>NP, pointer=1; end
end
if fe<maxFEs, T(fe+1:maxFEs)=Best.Cost; end
info.Evaluations=fe; info.QTable=q; info.Seconds=toc(clockStart);
end

function [pneb,pidx,gneb,gidx]=buildNeighborhood(pop,pbest,gbest,k)
NP=size(pop,1); D=size(pop,2); pneb=zeros(NP,k,D); pidx=zeros(NP,k);
for i=1:NP
    d=sum((pop(i,:)-pbest).^2,2); d(i)=inf; [~,ord]=sort(d); ord=ord(1:k); pidx(i,:)=ord; pneb(i,:,:)=pbest(ord,:);
end
d=sum((pop-gbest).^2,2); [~,ord]=sort(d); ord=ord(1:k); gidx=ord(:); gneb=pop(ord,:);
end
function d=meanDistance(pop)
D2=pdist2(pop,pop); d=sum(D2,2)/max(1,size(pop,1)-1);
end
function e=normalizedDistance(d,i)
dmin=min(d); dmax=max(d); if dmax<=dmin, e=0; else, e=(d(i)-dmin)/(dmax-dmin); end
end
function c=cosineSafe(a,b)
den=norm(a)*norm(b); if den==0, c=0; else, c=(a*b')/den; end
end
function [pop,pbest,pbestCost,fitness,Best,fe,me]=neighborMutation(i,pop,pbest,pbestCost,fitness,Best,pneb,pidx,gneb,gidx,f,fe,maxFEs,D)
me=0;
if fe>=maxFEs, return; end
P=pneb(i,:,:); P=reshape(P,size(P,2),D); d=sqrt(sum((P-pbest(i,:)).^2,2)); [~,o]=sort(d); P1=P(o(1),:); P2=P(o(end),:); P3=pbest(i,:)+rand(1,D).*(P1-P2);
cost=f(P3); fe=fe+1; me=me+1;
if cost<pbestCost(i), pbest(i,:)=P3; pbestCost(i)=cost; else, j=pidx(i,o(end)); pop(j,:)=P3; fitness(j)=cost; end
if fe>=maxFEs, return; end
P=gneb; d=sqrt(sum((P-Best.Vector).^2,2)); [~,o]=sort(d); P1=P(o(1),:); P2=P(o(end),:); P3=Best.Vector+rand(1,D).*(P1-P2);
cost=f(P3); fe=fe+1; me=me+1;
if cost<Best.Cost, Best.Cost=cost; Best.Vector=P3; else, j=gidx(o(end)); pop(j,:)=P3; fitness(j)=cost; end
end
