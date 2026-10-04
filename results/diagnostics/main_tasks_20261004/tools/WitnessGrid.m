function WitnessGrid
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));addpath(out);
v=load(fullfile(out,'input','N20_wide_model.mat'));model=v.model;nodes=[model.depot;reshape([model.orders.xyz],3,[])'];
M=size(nodes,1);dist=inf(M);controls=cell(M);
for i=1:M
 for j=i+1:M
  move=nodes(j,:)-nodes(i,:);side=[-move(2) move(1)]/norm(move(1:2));best=inf;
  for lambda=[.25 .35 .5 .65 .75]
   for d=-15:3:15
    for h=0:2:12
     c=nodes(i,:)+lambda*move;c(1:2)=c(1:2)+d*side;c(3)=c(3)+h;
     p=EvaluatePath([nodes(i,:);c;nodes(j,:)],model);
     if p.isFeasible&&p.distance<best,best=p.distance;bestcontrol=[lambda d h];end
    end
   end
  end
  if isfinite(best)
   dist(i,j)=best;dist(j,i)=best;controls{i,j}=bestcontrol;controls{j,i}=[1-bestcontrol(1) -bestcontrol(2) bestcontrol(3)];
  end
 end
end
save(fullfile(out,'witness_graph.mat'),'model','nodes','dist','controls');
fprintf('WITNESS graph: %d/%d feasible undirected links at K1 (exactly embed into K2 when lambda .25-.75).\n',sum(isfinite(dist(:)))/2,M*(M-1)/2);
end
