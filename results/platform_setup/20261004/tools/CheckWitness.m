function CheckWitness
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));addpath(out);
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
names={'N6_wide','N6_tight','N8_wide','N8_tight','N10_wide','N10_tight'};counts=[6 6 8 8 10 10];
rows=cell(18,1);row=0;
for map=1:3
 cfg.terrainType=map;cfg.stationFile=fullfile(root,'data','experiment_cases','N10_wide.csv');cfg.nOrders=10;
 base=CreateModel(cfg);nodes=[base.depot;reshape([base.orders.xyz],3,[])'];M=size(nodes,1);lengths=inf(M);controls=cell(M);
 for i=1:M
  for j=1:M
   if i==j,continue;end
   move=nodes(j,:)-nodes(i,:);side=[-move(2) move(1)]/norm(move(1:2));
   for lambda=.2:.15:.8
    for d=-15:3:15
     for h=0:2:12
      c=nodes(i,:)+lambda*move;c(1:2)=c(1:2)+d*side;c(3)=c(3)+h;
      p=EvaluatePath([nodes(i,:);c;nodes(j,:)],base);
      if p.isFeasible && p.distance<lengths(i,j)
       lengths(i,j)=p.distance;controls{i,j}=[lambda d h];
      end
     end
    end
   end
  end
 end
 for number=1:6
  cfg.stationFile=fullfile(root,'data','experiment_cases',[names{number} '.csv']);cfg.nOrders=counts(number);model=CreateModel(cfg);n=cfg.nOrders;
  [~,indices]=ismember([model.orders.stationID],[base.orders.stationID]);indices=[1 indices+1];dist=lengths(indices,indices);candidate=controls(indices,indices);
  dp=inf(2^n,n);previous=zeros(2^n,n);
  for j=1:n
   arrival=dist(1,j+1)/model.speed;start=max(arrival,model.orders(j).ready);
   if isfinite(start)&&start<=model.orders(j).due,dp(2^(j-1)+1,j)=start+model.orders(j).service;end
  end
  for mask=1:2^n-1
   for last=1:n
    time=dp(mask+1,last);if ~isfinite(time),continue;end
    for next=1:n
     if bitget(mask,next),continue;end
     arrival=time+dist(last+1,next+1)/model.speed;start=max(arrival,model.orders(next).ready);newmask=bitset(mask,next);
     if start<=model.orders(next).due && start+model.orders(next).service<dp(newmask+1,next)
      dp(newmask+1,next)=start+model.orders(next).service;previous(newmask+1,next)=last;
     end
    end
   end
  end
  [finish,last]=min(dp(end,:)+dist(2:end,1)'/model.speed);ok=isfinite(finish)&&finish<=model.depotDue;
  route=zeros(1,n);control=zeros(n+1,1,3);cost=NaN;detail=[];
  if ok
   mask=2^n-1;
   for k=n:-1:1,route(k)=last;before=previous(mask+1,last);mask=bitset(mask,last,0);last=before;end
   legs=[0 route 0];
   for k=1:n+1,control(k,1,:)=candidate{legs(k)+1,legs(k+1)+1};end
   keys=zeros(1,n);keys(route)=linspace(.05,.95,n);x=control;
   x(:,:,1)=(x(:,:,1)-model.minControlRatio)/(model.maxControlRatio-model.minControlRatio);
   x(:,:,2)=(x(:,:,2)+model.maxSideOffset)/(2*model.maxSideOffset);
   x(:,:,3)=(x(:,:,3)-model.minHeightOffset)/(model.maxHeightOffset-model.minHeightOffset);
   state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs);position=[keys x(:)'];
   [cost,detail]=Fitness(position,model,state);assert(detail.feasible);
  end
  row=row+1;rows{row}=struct('Terrain',model.terrainName,'Scenario',names{number},'WitnessFound',ok,'ReturnTime',finish,'Cost',cost);
  save(fullfile(out,sprintf('witness_%s_%s.mat',model.terrainName,names{number})),'model','route','control','detail','ok');
  fprintf('WITNESS %s %s found%d return%.2f\n',model.terrainName,names{number},ok,finish);
 end
end
report=struct2table(vertcat(rows{:}));writetable(report,fullfile(out,'witness_checks.csv'));
end
