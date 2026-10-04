function VerifyFinal
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
names={'N6_wide','N6_tight','N8_wide','N8_tight','N10_wide','N10_tight'};ns=[6 6 8 8 10 10];
for number=1:6
 cfg.nOrders=ns(number);cfg.stationFile=fullfile(root,'data','experiment_cases',[names{number} '.csv']);
 times=[];
 for map=1:3
  cfg.terrainType=map;model=CreateModel(cfg);xy=reshape([model.orders.xy],2,[])';xyz=reshape([model.orders.xyz],3,[])';
  ground=interp2(model.X,model.Y,model.terrainZ,xy(:,1),xy(:,2));assert(max(abs(xyz(:,3)-ground-8))<1e-10);
  tw=[[model.orders.ready];[model.orders.due]];if map==1,times=tw;else,assert(isequal(times,tw));end
  assert(model.nControlPoints==1&&model.minControlRatio==.2&&model.maxControlRatio==.8&&model.minHeightOffset==0&&model.maxHeightOffset==12&&model.maxSideOffset==15);
  check=load(fullfile(out,sprintf('witness_%s_%s.mat',model.terrainName,names{number})));
  assert(check.ok && check.detail.feasible);c=check.control;
  keys=zeros(1,ns(number));keys(check.route)=linspace(.05,.95,ns(number));
  c(:,:,1)=(c(:,:,1)-.2)/.6;c(:,:,2)=(c(:,:,2)+15)/30;c(:,:,3)=c(:,:,3)/12;
  state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs);
  [cost,detail]=Fitness([keys c(:)'],model,state);assert(detail.feasible&&abs(cost-check.detail.distance-.05*check.detail.totalWaiting-2*check.detail.totalSmoothness)<1e-8);
  save(fullfile(out,sprintf('final_model_%d_%s.mat',map,names{number})),'model');
 end
 cfg.terrainType=2;model=CreateModel(cfg);
 for repeat=1:5
  v=load(fullfile(out,'trial',sprintf('live_%s_r%d.mat',names{number},repeat)));
  [cost,detail]=Fitness(v.Best.Vector,model,v.state);assert(cost==v.Best.Cost&&isequal(detail,v.Best.Detail));
  assert(v.info.Evaluations==3000&&numel(v.T)==3000&&all(diff(v.T)<=1e-8));
  rng(v.info.Seed);expected=rand(30,ns(number)+3*(ns(number)+1));assert(isequal(expected,v.state.initialPopulation));
 end
end
% master appointment consistency and nested IDs/time preferences
for group=1:3
 wide=readmatrix(fullfile(root,'data','experiment_cases',[names{2*group-1} '.csv']));
 tight=readmatrix(fullfile(root,'data','experiment_cases',[names{2*group} '.csv']));
 assert(isequal(wide(:,[1 2 3 6 7 8 9]),tight(:,[1 2 3 6 7 8 9])));
 assert(all(wide(:,4)<=tight(:,4))&&all(wide(:,5)>=tight(:,5)));
 if group>1,assert(all(ismember(previous,wide(:,1))));end;previous=wide(:,1);
end
% K1 limits, hand schedule, pure-random budgets and reproducibility with all algorithms.
[model.X,model.Y]=meshgrid(linspace(0,20,51));model.terrainZ=zeros(51);model.mapSize=[20 20];
model.speed=1;model.minClearance=1;model.obstacleSafety=0;model.maxAltitude=15;
model.maxClimbAngle=25;model.maxTurnAngle=120;model.smoothWeight=2;model.nControlPoints=1;
model.minControlRatio=.2;model.maxControlRatio=.8;model.maxSideOffset=4;model.minHeightOffset=0;model.maxHeightOffset=4;
model.depot=[0 0 4];model.depotReady=0;model.depotDue=30;model.obstacles=struct('x',{},'y',{},'r',{},'zMin',{},'zMax',{});
model.orders=struct('stationID',{1,2},'xyz',{[3 0 4],[3 4 4]},'ready',{10,0},'due',{12,20},'service',{2,1});
state=struct('time',0,'position',model.depot,'activeIDs',[1 2]);controls=zeros(3,1,3);controls(:,:,1)=.5;controls(:,:,2)=.5;controls(:,:,3)=0;
x=[.1 .9 controls(:)'];[cost,detail]=Fitness(x,model,state);
assert(detail.feasible&&abs(detail.distance-12)<1e-10&&abs(detail.totalWaiting-7)<1e-10&&abs(detail.finishTime-22)<1e-10);
assert(isequal(size(detail.control),[3 1 3]));assert(all(detail.control(:,:,3)==0));
m=model;m.orders(2).due=15;[~,late]=Fitness(x,m,state);assert(~late.feasible&&late.totalLate==1);
m=model;m.depotDue=21;[~,late]=Fitness(x,m,state);assert(~late.feasible&&late.depotLate==1);
% Boundary of top-of-domain h=4 and lambda=.2/.8 remains exact.
high=x;high(9:11)=1;[~,detail]=Fitness(high,model,state);assert(all(detail.control(:,:,3)==4));
rng(456);state.initialPopulation=rand(8,11);state.maxEvaluations=113;
algorithms={'PSO','CSO','CLPSO','GWO'};
for k=1:4
 profile clear;profile on;[Best,T,info]=feval(algorithms{k},model,state,20,8,123);profile off;p=profile('info');
 calls=p.FunctionTable(strcmp({p.FunctionTable.FunctionName},'Fitness'));assert(numel(calls)==1&&calls.NumCalls==113);
 [Again,S]=feval(algorithms{k},model,state,20,8,123);assert(isequal(Best,Again)&&isequal(T,S));
 assert(isequal(info.InitialPopulation,state.initialPopulation)&&info.Evaluations==113);
 assert(all(diff(T)<=1e-8)&&Best.Detail.feasible==~isnan(info.FirstFeasibleEvaluation));
 fprintf('PASS %s K1 profilerFE113, replay and pure random population.\n',algorithms{k});
end
fprintf('PASS 18 feasible witnesses, 30 final holdouts, nested heterogeneous CSV and hand K1 schedules.\n');
end
