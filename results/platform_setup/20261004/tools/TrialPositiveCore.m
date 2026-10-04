function TrialPositiveCore
root='D:\111\Desktop\噜噜\9.29';out=fileparts(mfilename('fullpath'));addpath(root);addpath(fullfile(out,'corridor'),'-begin');
d=load(fullfile(out,'input','experiment_cases.mat'),'Cases');base=d.Cases{2,1}.Model;P=30;FE=3000;
% 固定预约中心来自站点任务顺序，但不依赖任何算法轨迹；三类紧迫度公开写入CSV。
scenarios={struct('name','N6_wide','ids',[1 5 9 13 17 20],'scale',1.2), ...
 struct('name','N6_tight','ids',[1 5 9 13 17 20],'scale',0.8), ...
 struct('name','N8_wide','ids',[1 3 5 8 10 13 16 20],'scale',1.2), ...
 struct('name','N8_tight','ids',[1 3 5 8 10 13 16 20],'scale',0.8), ...
 struct('name','N10_wide','ids',[1 3 5 7 9 11 13 15 17 20],'scale',1.2), ...
 struct('name','N10_tight','ids',[1 3 5 7 9 11 13 15 17 20],'scale',0.8)};
% 预约中心与各站空间任务尺度固定；不使用参考航迹/PSO解。
centers=repmat([75 95 115],1,7);centers=centers(1:20);
classWidth=repmat([120 160 200],1,7);classWidth=classWidth(1:20);
rows=cell(18,1);count=0;
for q=1:6
 sc=scenarios{q};ids=sc.ids;n=length(ids);cfg=load(fullfile(root,'data','experiment_cases.mat'),'cfg');cfg=cfg.cfg;cfg.terrainType=2;cfg.nOrders=20;cfg.nControlPoints=1;cfg.maxSideOffset=15;cfg.maxHeightOffset=12;cfg.minControlRatio=.2;cfg.maxControlRatio=.8;model=CreateModel(cfg);model.orders=model.orders(ids);model.nOrders=n;model.activeIDs=1:n;model.selectedCustomerIDs=[model.orders.stationID];
 for i=1:n
   c=centers(ids(i));w=classWidth(ids(i))*sc.scale;model.orders(i).id=i;model.orders(i).ready=max(0,c-w/2);model.orders(i).due=c+w/2;model.orders(i).service=3;
 end
 state=struct('time',0,'position',model.depot,'activeIDs',1:n,'maxEvaluations',FE);
 for r=1:3
  seed=20266000+100*ceil(q/2)+r;rng(seed);state.initialPopulation=rand(P,n+3*(n+1)*model.nControlPoints);
  [Best,T,info]=PSO(model,state,ceil(FE/P),P,seed);[cost,detail]=Fitness(Best.Vector,model,state);count=count+1;
  save(fullfile(out,'trial',sprintf('positive_%s_r%d.mat',sc.name,r)),'model','state','Best','T','info');
  rows{count}=struct('Scenario',sc.name,'N',n,'Scale',sc.scale,'Run',r,'Seed',seed,'Feasible',detail.feasible,'Late',detail.totalLate,'Terrain',detail.terrainViolation,'Obstacle',detail.obstacleViolation,'Angle',detail.totalAngleViolation,'Distance',detail.distance,'ReturnTime',detail.finishTime);
  fprintf('%s r%d feasible=%d late=%.2f terrain=%.2f obstacle=%d angle=%.2f distance=%.2f\n',sc.name,r,detail.feasible,detail.totalLate,detail.terrainViolation,detail.obstacleViolation,detail.totalAngleViolation,detail.distance);
 end
 x=[model.orders];data=[[x.stationID]' [x.ready]' [x.due]' [x.service]'];writematrix(data,fullfile(out,[sc.name '.csv']));
end
raw=struct2table(vertcat(rows{:}));writetable(raw,fullfile(out,'positive_trial.csv'));save(fullfile(out,'positive_trial.mat'),'raw','scenarios','centers','classWidth');
end
