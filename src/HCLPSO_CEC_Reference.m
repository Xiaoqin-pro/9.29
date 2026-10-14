function [Best,T,info] = HCLPSO_CEC_Reference(f,state,~,N,seed)
% HCLPSO_CEC_Reference
% Continuous CEC adapter based on the public NEORL HCLPSO implementation.
% Reference snapshot: work/external/neorl_source_20261013,
% commit ebe03dcdb6def8c74e185300500841003ca49fbb.
%
% The adapter preserves the caller supplied initial population, counts every
% objective call including initialization, clips continuous coordinates at the
% CEC boundary, and truncates the final generation at the exact FE budget.
clockStart=tic;
assert(N==50,'Formal HCLPSO comparison uses N=50.');
g1=20; g2=N-g1; assert(g1<g2);
pop=state.initialPopulation; D=size(pop,2);
lb=state.lowerBound; ub=state.upperBound; budget=state.maxEvaluations;
assert(size(pop,1)==N && budget>=N && budget==floor(budget));
assert(all(isfinite(pop),'all') && all(pop>=lb & pop<=ub,'all'));
rng(seed,'twister');
range=ub-lb;
V=(-0.2+0.4*rand(N,D)).*range;
T=nan(budget,1); fitness=zeros(N,1); Best.Cost=inf; Best.Vector=pop(1,:);
fe=0;
for i=1:N
    fitness(i)=f(pop(i,:)); fe=fe+1;
    if fitness(i)<Best.Cost, Best.Cost=fitness(i); Best.Vector=pop(i,:); end
    T(fe)=Best.Cost;
end
pbest=pop; pbestCost=fitness; slope=zeros(N,1);
[~,bestIdx]=min(pbestCost); Best.Vector=pbest(bestIdx,:); Best.Cost=pbestCost(bestIdx);
maxGen=max(1,ceil((budget-N)/N));
idx=0:maxGen-1;
weight=0.99-0.79*idx/maxGen;
K=3-1.5*idx/maxGen;
c1=2.5-2*idx/maxGen;
c2=0.5+2*idx/maxGen;
% Source Pc is monotone over particles, with lower values in exploration.
j=linspace(0,10,N)'; Pc=0.25*(exp(j)-1)/(exp(10)-1);
friend=zeros(N,D); friendPos=zeros(N,D);
for i=1:g1
    [friend(i,:),friendPos(i,:)]=refreshFriend(i,g1,friend(i,:),pbest,pbestCost,Pc(i));
end
for i=g1+1:N
    [friend(i,:),friendPos(i,:)]=refreshFriend(i,N,friend(i,:),pbest,pbestCost,Pc(i));
end
first=NaN; iterations=0; refresh=0; outside=0;
while fe<budget
    k=min(iterations+1,maxGen); iterations=iterations+1;
    % Exploration group: comprehensive-learning cognitive movement.
    for i=1:g1
        if slope(i)>5
            [friend(i,:),friendPos(i,:)]=refreshFriend(i,g1,friend(i,:),pbest,pbestCost,Pc(i));
            slope(i)=0; refresh=refresh+1;
        end
        step=K(k)*rand(1,D).*(friendPos(i,:)-pop(i,:));
        V(i,:)=weight(k)*V(i,:)+step;
        V(i,:)=max(-0.2*range,min(0.2*range,V(i,:)));
        pop(i,:)=max(lb,min(ub,pop(i,:)+V(i,:)));
    end
    % Exploitation group: cognitive plus global-best movement.
    for i=g1+1:N
        if slope(i)>5
            [friend(i,:),friendPos(i,:)]=refreshFriend(i,N,friend(i,:),pbest,pbestCost,Pc(i));
            slope(i)=0; refresh=refresh+1;
        end
        step=c1(k)*rand(1,D).*(friendPos(i,:)-pop(i,:)) + ...
             c2(k)*rand(1,D).*(Best.Vector-pop(i,:));
        V(i,:)=weight(k)*V(i,:)+step;
        V(i,:)=max(-0.2*range,min(0.2*range,V(i,:)));
        pop(i,:)=max(lb,min(ub,pop(i,:)+V(i,:)));
    end
    % Evaluate the moved population in particle order, with exact FE cap.
    for i=1:N
        if fe>=budget, break; end
        value=f(pop(i,:)); fe=fe+1;
        if value<pbestCost(i)
            pbest(i,:)=pop(i,:); pbestCost(i)=value; slope(i)=0;
        else
            slope(i)=slope(i)+1;
        end
        if value<Best.Cost
            Best.Cost=value; Best.Vector=pop(i,:);
            if isnan(first), first=fe; end
        elseif pbestCost(i)<Best.Cost
            Best.Cost=pbestCost(i); Best.Vector=pbest(i,:);
        end
        T(fe)=Best.Cost;
    end
    % Rebuild exemplars after the generation, as in the public reference.
    for i=1:g1
        if slope(i)>5
            [friend(i,:),friendPos(i,:)]=refreshFriend(i,g1,friend(i,:),pbest,pbestCost,Pc(i));
            slope(i)=0; refresh=refresh+1;
        end
    end
    for i=g1+1:N
        if slope(i)>5
            [friend(i,:),friendPos(i,:)]=refreshFriend(i,N,friend(i,:),pbest,pbestCost,Pc(i));
            slope(i)=0; refresh=refresh+1;
        end
    end
end
T=T(1:fe);
info=struct('Algorithm','HCLPSO-CEC-ReferenceAdapter', ...
    'Seed',seed,'Evaluations',fe,'InitialCost',T(N), ...
    'InitialPopulation',state.initialPopulation,'Seconds',toc(clockStart), ...
    'Iterations',iterations,'FirstImprovementEvaluation',first, ...
    'ExplorationGroup',g1,'ExploitationGroup',g2,'SkippedOutside',outside, ...
    'BoundaryClips',NaN,'RefreshCount',refresh,'ReferenceCommit', ...
    'ebe03dcdb6def8c74e185300500841003ca49fbb');
end

function [indices,vector] = refreshFriend(i,friendCount,oldIndices,pbest,pbestCost,pc)
D=size(pbest,2); indices=oldIndices;
for d=1:D
    a=randi(friendCount); b=randi(friendCount);
    if pbestCost(a)<pbestCost(b), winner=a; else, winner=b; end
    % Public reference: toss=ceil(U-Pc), with self retained where toss=1.
    toss=ceil(rand-pc);
    if toss==0, indices(d)=winner; else, indices(d)=i; end
end
if all(indices==i)
    indices(randi(D))=randi(friendCount);
end
vector=zeros(1,D);
for d=1:D, vector(d)=pbest(indices(d),d); end
end
