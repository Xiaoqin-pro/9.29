function ConfirmLive
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
names={'N6_wide','N6_tight','N8_wide','N8_tight','N10_wide','N10_tight'};counts=[6 6 8 8 10 10];
records=cell(30,1);count=0;
for number=1:6
 cfg.nOrders=counts(number);cfg.stationFile=fullfile(root,'data','experiment_cases',[names{number} '.csv']);cfg.terrainType=2;model=CreateModel(cfg);
 for repeat=1:5
  seed=20273000+100*ceil(number/2)+repeat;
  state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs,'maxEvaluations',3000);
  D=cfg.nOrders+3*(cfg.nOrders+1);rng(seed);state.initialPopulation=rand(30,D);
  [Best,T,info]=PSO(model,state,100,30,seed);[cost,detail]=Fitness(Best.Vector,model,state);
  assert(cost==Best.Cost&&isequal(detail,Best.Detail));
  record=struct('Terrain','peaks','Scenario',names{number},'Algorithm','PSO','Run',repeat,'Seed',seed,'Evaluations',3000, ...
   'Feasible',detail.feasible,'Cost',cost,'Distance',detail.distance,'Late',detail.totalLate,'DepotLate',detail.depotLate, ...
   'TerrainViolation',detail.terrainViolation,'ObstacleViolation',detail.obstacleViolation,'AngleViolation',detail.totalAngleViolation, ...
   'FirstFeasible',info.FirstFeasibleEvaluation,'Seconds',info.Seconds);
  count=count+1;records{count}=record;
  save(fullfile(out,'trial',sprintf('live_%s_r%d.mat',names{number},repeat)),'record','model','state','Best','T','info');
  raw=struct2table(vertcat(records{1:count}));writetable(raw,fullfile(out,'live_confirmation.csv'));
  fprintf('LIVE %s r%d feasible%d late%.2f collision%d first%.0f\n',names{number},repeat,detail.feasible,detail.totalLate,detail.obstacleViolation,info.FirstFeasibleEvaluation);
 end
end
save(fullfile(out,'live_confirmation.mat'),'raw');
end
