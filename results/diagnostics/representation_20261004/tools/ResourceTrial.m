function ResourceTrial
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
cfg.stationFile=fullfile(root,'data','experiment_cases','N10_wide.csv');cfg.nOrders=10;cfg.terrainType=2;
rows=cell(12,1);count=0;
for K=[1 2]
 cfg.nControlPoints=K;model=CreateModel(cfg);D=10+3*11*K;
 for repeat=1:3
  seed=20274000+repeat;rng(seed);fullPopulation=rand(60,D);
  for P=[30 60]
   state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs, ...
    'maxEvaluations',10000,'initialPopulation',fullPopulation(1:P,:));
   [Best,T,info]=PSO(model,state,ceil(10000/P),P,seed);[cost,detail]=Fitness(Best.Vector,model,state);
   assert(cost==Best.Cost&&info.Evaluations==10000&&numel(T)==10000);
   record=struct('K',K,'Population',P,'Dimension',D,'Run',repeat,'Seed',seed, ...
    'Evaluations',10000,'Feasible',detail.feasible,'Distance',detail.distance,'Cost',cost, ...
    'Late',detail.totalLate,'DepotLate',detail.depotLate,'Obstacle',detail.obstacleViolation, ...
    'Terrain',detail.terrainViolation,'Angle',detail.totalAngleViolation, ...
    'FirstFeasible',info.FirstFeasibleEvaluation,'Seconds',info.Seconds);
   count=count+1;rows{count}=record;
   save(fullfile(out,'runs',sprintf('K%d_P%d_r%d.mat',K,P,repeat)),'record','model','state','Best','T','info');
   raw=struct2table(vertcat(rows{1:count}));writetable(raw,fullfile(out,'raw.csv'));
   fprintf('K%d P%d r%d feasible%d distance%.2f late%.2f collision%d first%.0f\n', ...
    K,P,repeat,detail.feasible,detail.distance,detail.totalLate,detail.obstacleViolation,info.FirstFeasibleEvaluation);
  end
 end
end
save(fullfile(out,'resource_results.mat'),'raw');
end
