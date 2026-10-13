function [Best,T,info]=SPSO2011_MatlabOracle(f,state,~,N,seed)
% Independent translation of pure standard C mechanics, test-only KISS stream.
D=size(state.initialPopulation,2);budget=state.maxEvaluations;lb=state.lowerBound;ub=state.upperBound;
u32=uint64(4294967295);x=bitor(uint64(seed),uint64(1));y=bitor(uint64(seed),uint64(2));z=bitor(uint64(seed),uint64(4));q=bitor(uint64(seed),uint64(8));carry=uint64(0);draws=0;
pos=state.initialPopulation;vel=zeros(N,D);
for s=1:N
 for d=1:D
  uniform(lb(d),ub(d)); % original random-position draw discarded for shared p0
  vel(s,d)=uniform(lb(d)-pos(s,d),ub(d)-pos(s,d));
 end
end
cost=zeros(N,1);T=nan(budget,1);fe=0;Best.Cost=inf;
for i=1:N
 cost(i)=f(pos(i,:));fe=fe+1;if cost(i)<Best.Cost,Best.Cost=cost(i);Best.Vector=pos(i,:);end;T(fe)=Best.Cost;
end
pbest=pos;pcost=cost;links=eye(N)>0;prob=1-(1-1/N)^3;w=1/(2*log(2));c=.5+log(2);
rebuild=true;iterations=0;rebuilds=0;clips=0;previous=Best.Cost;
while fe<budget
 iterations=iterations+1;
 if rebuild
  rebuilds=rebuilds+1;
  for receiver=1:N
   for donor=1:N
    if donor==receiver,continue;end
    links(donor,receiver)=uniform(0,1)<prob;
   end
  end
 end
 for s=1:N
  if fe>=budget,break;end
  donors=find(links(:,s));g=donors(1);
  for donor=donors'
   if pcost(donor)<pcost(g),g=donor;end
  end
  vel(s,:)=w*vel(s,:);PX=pbest(s,:)-pos(s,:);
  if g~=s,GX=pbest(g,:)-pos(s,:);
  else
   other=s;while other==s,other=min(N,floor(uniform(0,N))+1);end %#ok<NASGU> unused reference draw
  end
  if g==s,Gr=.5*pos(s,:)+.5*(pos(s,:)+c*PX);
  else,Gr=(1/3)*pos(s,:)+(1/3)*(pos(s,:)+c*PX);Gr=Gr+(1/3)*(pos(s,:)+c*GX);end
  V1=Gr-pos(s,:);total=0;
  for d=1:D,total=total+abs(pos(s,d)-Gr(d))^2;end
  radius=sqrt(total);direction=zeros(1,D);length2=0;
  for d=1:D
   accepted=false;
   while ~accepted
    a=2*uniform(0,1)-1;b=2*uniform(0,1)-1;t=a*a+b*b;accepted=t<1;
   end
   scale=sqrt(-2*log(t)/t);n=a*scale;if uniform(0,1)<.5,n=-n;end
   direction(d)=n;length2=length2+n*n;
  end
  r=uniform(0,1);ball=zeros(1,D);L=sqrt(length2);
  for d=1:D,ball(d)=radius*r*direction(d)/L;end
  vel(s,:)=vel(s,:)+V1+ball;pos(s,:)=pos(s,:)+vel(s,:);
  for d=1:D
   if pos(s,d)<lb(d),pos(s,d)=lb(d);vel(s,d)=-.5*vel(s,d);clips=clips+1;
   elseif pos(s,d)>ub(d),pos(s,d)=ub(d);vel(s,d)=-.5*vel(s,d);clips=clips+1;end
  end
  cost(s)=f(pos(s,:));fe=fe+1;
  if cost(s)<pcost(s),pbest(s,:)=pos(s,:);pcost(s)=cost(s);end
  if cost(s)<Best.Cost,Best.Cost=cost(s);Best.Vector=pos(s,:);end;T(fe)=Best.Cost;
 end
 rebuild=~(Best.Cost<previous);previous=Best.Cost;
end
info=struct('Evaluations',fe,'Iterations',iterations,'TopologyRebuilds',rebuilds,'UniformDraws',draws,'BoundaryClips',clips, ...
 'KissX',double(x),'KissY',double(y),'KissZ',double(z),'KissW',double(q),'KissCarry',double(carry));
 function value=uniform(a,b)
  x=bitand(x*uint64(69069)+uint64(1),u32);
  y=bitxor(y,bitand(bitshift(y,13),u32));y=bitxor(y,bitshift(y,-17));y=bitxor(y,bitand(bitshift(y,5),u32));
  k=bitshift(z,-2)+bitshift(q,-3)+bitshift(carry,-2);
  m=bitand(q+q+z+carry,u32);z=q;q=m;carry=bitshift(k,-30);
  randval=double(bitand(x+y+q,u32))/4294967295;draws=draws+1;value=a+randval*(b-a);
 end
end
