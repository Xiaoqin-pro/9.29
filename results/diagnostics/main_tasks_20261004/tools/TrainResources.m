function TrainResources
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
cfg.nControlPoints=2;cfg.nOrders=15;cfg.terrainType=2;cfg.stationFile=fullfile(out,'input','N15_wide.csv');
model=CreateModel(cfg);D=15+6*16;rows=cell(12,1);count=0;
for repeat=1:3
 seed=20275000+repeat;rng(seed);allPositions=rand(60,D);
 for P=[30 60]
  for FE=[10000 30000]
   file=fullfile(out,'runs',sprintf('train_P%d_FE%d_r%d.mat',P,FE,repeat));
   state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs,'maxEvaluations',FE, ...
    'initialPopulation',allPositions(1:P,:));
   if isfile(file)
    d=load(file,'Best','T','info');Best=d.Best;T=d.T;info=d.info;
   else
    [Best,T,info]=PSO(model,state,ceil(FE/P),P,seed);
   end
   [cost,detail]=Fitness(Best.Vector,model,state);
   assert(cost==Best.Cost&&info.Evaluations==FE&&numel(T)==FE&&isequal(info.InitialPopulation,state.initialPopulation));
   record=struct('Phase','Training','Scenario','N15_wide','K',2,'Dimension',D,'Population',P, ...
    'Run',repeat,'Seed',seed,'Evaluations',FE,'Feasible',detail.feasible,'Cost',cost,'Distance',detail.distance, ...
    'Smoothness',detail.totalSmoothness,'Late',detail.totalLate,'DepotLate',detail.depotLate,'ReturnTime',detail.finishTime, ...
    'TerrainViolation',detail.terrainViolation,'ObstacleViolation',detail.obstacleViolation, ...
    'AngleViolation',detail.totalAngleViolation,'MapViolation',detail.mapViolation,'AltitudeViolation',detail.altitudeViolation, ...
    'MaxTurnAngle',detail.maxTurnAngle,'MaxClimbAngle',detail.maxClimbAngle, ...
    'FirstFeasibleEvaluation',info.FirstFeasibleEvaluation,'Seconds',info.Seconds,'File',file);
   save(file,'record','Best','T','info','model','state','cfg');
   count=count+1;rows{count}=record;raw=struct2table(vertcat(rows{1:count}));writetable(raw,fullfile(out,'training_raw.csv'));
   fprintf('TRAIN K2 N15-wide P%d FE%d seed%d feasible%d obstacle%d late%.2f cost%.2f first%.0f\n', ...
    P,FE,seed,detail.feasible,detail.obstacleViolation,detail.totalLate,cost,info.FirstFeasibleEvaluation);
  end
 end
end
rows=cell(4,1);count=0;
for P=[30 60]
 for FE=[10000 30000]
  g=raw(raw.Population==P&raw.Evaluations==FE,:);good=g(g.Feasible,:);count=count+1;
  rows{count}=struct('Population',P,'Evaluations',FE,'Runs',height(g),'FeasibleCount',sum(g.Feasible), ...
   'FeasibleRate',mean(g.Feasible),'MeanFeasibleCost',mean(good.Cost),'MeanFeasibleDistance',mean(good.Distance), ...
   'MeanLate',mean(g.Late),'MeanObstacle',mean(g.ObstacleViolation),'MeanTerrain',mean(g.TerrainViolation), ...
   'MeanAngle',mean(g.AngleViolation),'MeanSeconds',mean(g.Seconds));
 end
end
summary=struct2table(vertcat(rows{:}));writetable(summary,fullfile(out,'training_summary.csv'));
if any(summary.FeasibleCount>0)
 good=summary(summary.FeasibleCount>0,:);good=sortrows(good,{'FeasibleRate','MeanFeasibleCost','Evaluations','Population'},{'descend','ascend','ascend','ascend'});
 choice=struct('Population',good.Population(1),'Evaluations',good.Evaluations(1),'Promotable',false,'AnyTrainingFeasible',true, ...
  'Reason','Prespecified rank: feasibility, feasible cost, budget then population; pilot choice only pending independent holdout');
else
 choice=struct('Population',60,'Evaluations',30000,'Promotable',false,'AnyTrainingFeasible',false, ...
  'Reason','All training settings failed. Largest setting used only for diagnostic scale check; do not promote production');
end
save(fullfile(out,'training_results.mat'),'raw','summary','choice','cfg');
fid=fopen(fullfile(out,'resource_choice.json'),'w');fprintf(fid,'%s',jsonencode(choice,PrettyPrint=true));fclose(fid);
disp(summary);disp(choice);
end
