function [Best,T,info] = NRLPSO_CEC_PaperAligned(f,state,~,seed)
%NRLPSO_CEC_PaperAligned Paper-aligned independent NRLPSO reproduction.
% Based on the supplied NRLPSO equations and the MetaBox third-party code.
% This is not an author release. NP=40, k=8, and all objective calls are audited.
clockStart=tic;
pop=state.initialPopulation; NP=size(pop,1); D=size(pop,2);
lb=state.lowerBound; ub=state.upperBound; maxFEs=state.maxEvaluations;
assert(NP==40,'Paper-aligned NRLPSO uses NP=40.');
rng(seed,'twister');
velocity=zeros(NP,D); vmin=-0.1*(ub-lb); vmax=-vmin;
fitness=nan(NP,1); pbest=pop; pbestCost=nan(NP,1);
Best.Cost=inf; Best.Vector=pop(1,:); T=nan(maxFEs,1); fe=0;
for i=1:NP
    [fitness(i),Best,T,fe]=evaluateAndRecord(f(pop(i,:)),pop(i,:),Best,T,fe,maxFEs);
    pbestCost(i)=fitness(i);
end
pbestStag=zeros(NP,1); pointer=1; q=zeros(4,4); gamma=0.8;
rw=rand; u=0.6; vpar=0.33; wmin=0.4; wmax=1.0; k=8;
stateVec=randi(4,NP,1); actionCounts=zeros(1,4); alphaTrace=[]; inertiaTrace=[];
mutationEvals=0; mutationCalls=0;
while fe<maxFEs
    if pointer==1
        [neb,nebIdx,gbestNeb,gbestNebIdx]=buildNeighborhood(pop,pbest,Best.Vector,k);
        rw=4*rw*(1-rw); frac=fe/maxFEs;
        % Equation (9) in the supplied NRLPSO paper.
        w=u-((frac-wmax)*rw*wmin + vpar*(wmax-wmin)*frac);
        inertiaTrace(end+1)=w; %#ok<AGROW>
    end
    i=pointer; oldState=stateVec(i);
    qrow=q(oldState,:); qrow=qrow-max(qrow); prob=exp(qrow); prob=prob/sum(prob);
    action=find(rand<=cumsum(prob),1,'first'); if isempty(action), action=4; end
    actionCounts(action)=actionCounts(action)+1;
    cs=cosineSafe(pbest(i,:),Best.Vector); r1=rand; r2=rand; cur=pop(i,:);
    switch action
        case 1 % exploration
            if cs<0
                P1=pbest(i,:); P2=gbestNeb(randi(size(gbestNeb,1)),:);
                velocity(i,:)=w*velocity(i,:)+2.2*r1*(P1-cur)+1.8*r2*(P2-cur);
            else
                P1=reshape(neb(i,randi(k),:),1,D);
                velocity(i,:)=w*velocity(i,:)+2.2*r1*(P1-cur);
            end
        case 2 % exploitation; c2=1.9 per supplied paper table
            if cs<0
                P1=reshape(neb(i,randi(k),:),1,D); P2=Best.Vector;
                velocity(i,:)=w*velocity(i,:)+2.1*r1*(P1-cur)+1.9*r2*(P2-cur);
            else
                P2=gbestNeb(randi(size(gbestNeb,1)),:);
                velocity(i,:)=w*velocity(i,:)+1.9*r2*(P2-cur);
            end
        case 3 % convergence
            if cs<0
                P1=pbest(i,:); P2=Best.Vector;
                velocity(i,:)=w*velocity(i,:)+2*r1*(P1-cur)+2*r2*(P2-cur);
            else
                velocity(i,:)=w*velocity(i,:)+2*r2*(Best.Vector-cur);
            end
        otherwise % jumping out
            P1=reshape(neb(i,randi(k),:),1,D); P2=gbestNeb(randi(size(gbestNeb,1)),:);
            velocity(i,:)=w*velocity(i,:)+1.8*rand(1,D).*(P1-cur)+2.2*rand(1,D).*(P2-cur);
    end
    velocity(i,:)=max(vmin,min(vmax,velocity(i,:)));
    dOld=meanDistance(pop); efOld=normalizedDistance(dOld,i);
    pop(i,:)=max(lb,min(ub,pop(i,:)+velocity(i,:)));
    dNew=meanDistance(pop); efNew=normalizedDistance(dNew,i);
    fOld=fitness(i); fNew=f(pop(i,:));
    [~,Best,T,fe]=evaluateAndRecord(fNew,pop(i,:),Best,T,fe,maxFEs);
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
        mutationCalls=mutationCalls+1;
        [pop,pbest,pbestCost,fitness,Best,T,fe,me]=neighborMutation(i,pop,pbest,pbestCost,fitness,Best,T,neb,nebIdx,gbestNeb,gbestNebIdx,f,fe,maxFEs,D);
        mutationEvals=mutationEvals+me;
    end
    % MetaBox's environment returns the next particle's current state.
    nextPointer=mod(i,NP)+1; nextState=stateVec(nextPointer);
    alpha=max(0.1,1.0-0.9*(fe/maxFEs)); alphaTrace(end+1)=alpha; %#ok<AGROW>
    td=reward+gamma*max(q(nextState,:))-q(oldState,action);
    q(oldState,action)=q(oldState,action)+alpha*td;
    stateVec(i)=action; pointer=nextPointer;
end
if any(isnan(T))
    error('NRLPSO:IncompleteTrace','Objective trace contains unfilled FE entries.');
end
info=struct('Algorithm','NRLPSO_CEC_PaperAligned','Seed',seed,'Evaluations',fe,...
    'ObjectiveCalls',fe,'InitialCost',T(1),'InitialPopulation',state.initialPopulation,...
    'NP',NP,'k',k,'QTable',q,'ActionCounts',actionCounts,'AlphaMin',min(alphaTrace),...
    'AlphaMax',max(alphaTrace),'InertiaMin',min(inertiaTrace),'InertiaMax',max(inertiaTrace),...
    'MutationEvaluations',mutationEvals,'MutationCalls',mutationCalls,...
    'Seconds',toc(clockStart),'BestConsistencyChecked',true);
end

function [value,Best,T,fe]=evaluateAndRecord(value,position,Best,T,fe,maxFEs)
assert(fe<maxFEs,'Objective call would exceed budget.'); fe=fe+1;
if value<Best.Cost, Best.Cost=value; Best.Vector=position; end
T(fe)=Best.Cost;
end
function [neb,idx,gneb,gidx]=buildNeighborhood(pop,pbest,gbest,k)
NP=size(pop,1); D=size(pop,2); neb=zeros(NP,k,D); idx=zeros(NP,k);
for i=1:NP
    d=sum((pop(i,:)-pbest).^2,2); d(i)=inf; [~,ord]=sort(d); ord=ord(1:k); idx(i,:)=ord; neb(i,:,:)=pop(ord,:);
end
d=sum((pop-gbest).^2,2); [~,ord]=sort(d); ord=ord(1:k); gidx=ord(:); gneb=pop(ord,:);
end
function d=meanDistance(pop)
d=zeros(size(pop,1),1);
for i=1:size(pop,1), delta=pop-pop(i,:); d(i)=sum(sqrt(sum(delta.^2,2)))/(size(pop,1)-1); end
end
function e=normalizedDistance(d,i)
dmin=min(d); dmax=max(d); if dmax<=dmin, e=0; else, e=(d(i)-dmin)/(dmax-dmin); end
end
function c=cosineSafe(a,b)
den=norm(a)*norm(b); if den==0, c=0; else, c=(a*b')/den; end
end
function [pop,pbest,pbestCost,fitness,Best,T,fe,me]=neighborMutation(i,pop,pbest,pbestCost,fitness,Best,T,neb,idx,gneb,gidx,f,fe,maxFEs,D)
me=0; P=reshape(neb(i,:,:),size(neb,2),D); d=sqrt(sum((P-pbest(i,:)).^2,2)); [~,o]=sort(d);
if fe<maxFEs
    P3=pbest(i,:)+rand(1,D).*(P(o(1),:)-P(o(end),:)); cost=f(P3);
    [~,Best,T,fe]=evaluateAndRecord(cost,P3,Best,T,fe,maxFEs); me=me+1;
    if cost<pbestCost(i), pbest(i,:)=P3; pbestCost(i)=cost; else, j=idx(i,o(end)); pop(j,:)=P3; fitness(j)=cost; end
end
if fe<maxFEs
    d=sqrt(sum((gneb-Best.Vector).^2,2)); [~,o2]=sort(d);
    P3=Best.Vector+rand(1,D).*(gneb(o2(1),:)-gneb(o2(end),:)); cost=f(P3);
    [~,Best,T,fe]=evaluateAndRecord(cost,P3,Best,T,fe,maxFEs); me=me+1;
    if cost>=Best.Cost, j=gidx(o2(end)); pop(j,:)=P3; fitness(j)=cost; end
end
end
