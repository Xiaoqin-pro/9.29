function [candidate,meta]=SAQ_SeekingOperator(action,x,realX,best,pbest,parent,lb,ub,progress,stream)
% Teacher-inspired alternatives for the existing CSO Seeking candidate pool.
D=numel(x);N=size(pbest,1);k=max(1,round(.2*D));candidate=x;meta=[0 0 0];
switch action
 case 2
  peers=setdiff(1:N,parent);order=randperm(stream,numel(peers),2);a=peers(order(1));b=peers(order(2));
  dims=randperm(stream,D,k);noise=.025*(ub(dims)-lb(dims))*(1-progress).*(2*rand(stream,1,k)-1);
  candidate(dims)=x(dims)+.5*(pbest(a,dims)-pbest(b,dims))+noise;meta=[a b numel(dims)];
 case 3
  varying=find(ub>lb);assert(~isempty(varying));d=varying(randi(stream,numel(varying)));
  candidate=best;candidate(d)=best(d)+(ub(d)-lb(d))*(1-.9*progress)*randn(stream);meta=[d 0 1];
 case 4
  dims=randperm(stream,D,k);candidate=realX;candidate(dims)=lb(dims)+ub(dims)-realX(dims);meta=[0 0 numel(dims)];
 otherwise,error('Operator:InvalidAction','Only actions 2-4 are alternatives.');
end
width=ub-lb;vary=width>0;folded=mod(candidate(vary)-lb(vary),2*width(vary));
candidate(vary)=lb(vary)+width(vary)-abs(folded-width(vary));candidate(~vary)=lb(~vary);
assert(all(isfinite(candidate))&&all(candidate>=lb&candidate<=ub));
end
