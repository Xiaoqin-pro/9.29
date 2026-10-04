function HoldoutScale(numbers)
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
x=load(fullfile(out,'training_results.mat'),'choice');choice=x.choice;P=choice.Population;FE=choice.Evaluations;
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
cfg.nControlPoints=2;cfg.terrainType=2;
names={'N10_wide','N10_tight','N15_wide','N15_tight','N20_wide','N20_tight'};ns=[10 10 15 15 20 20];
records=cell(numel(numbers)*3,1);count=0;
label=sprintf('N%d',ns(numbers(1)));
numbers=numbers(numbers~=6); % excluded by exact time infeasibility certificate, not PSO scores
for number=numbers
 cfg.nOrders=ns(number);cfg.stationFile=fullfile(out,'input',[names{number} '.csv']);model=CreateModel(cfg);
 for repeat=1:3
  seed=20276000+repeat;D=cfg.nOrders+6*(cfg.nOrders+1);
  state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs,'maxEvaluations',FE);
  rng(seed);state.initialPopulation=rand(P,D);
  file=fullfile(out,'runs',sprintf('holdout_%s_r%d.mat',names{number},repeat));
  if isfile(file),d=load(file,'Best','T','info');Best=d.Best;T=d.T;info=d.info;
  else,[Best,T,info]=PSO(model,state,ceil(FE/P),P,seed);end
  [cost,det]=Fitness(Best.Vector,model,state);assert(cost==Best.Cost&&info.Evaluations==FE&&numel(T)==FE);
  geom=det.terrainViolation<1e-8&&det.obstacleViolation<1e-8&&det.totalAngleViolation<1e-8&&det.mapViolation<1e-8&&det.altitudeViolation<1e-8;
  record=struct('Scenario',names{number},'N',ns(number),'K',2,'Dimension',D,'Population',P,'Run',repeat, ...
   'Seed',seed,'Evaluations',FE,'Feasible',det.feasible,'GeometryFeasible',geom, ...
   'Cost',cost,'Distance',det.distance,'Late',det.totalLate,'DepotLate',det.depotLate, ...
   'TerrainViolation',det.terrainViolation,'ObstacleViolation',det.obstacleViolation,'AngleViolation',det.totalAngleViolation, ...
   'FirstFeasibleEvaluation',info.FirstFeasibleEvaluation,'Seconds',info.Seconds,'File',file);
  save(file,'model','state','Best','T','info','record','cfg');count=count+1;records{count}=record;
  raw=struct2table(vertcat(records{1:count}));writetable(raw,fullfile(out,['holdout_' label '_raw.csv']));
  fprintf('HOLDOUT %s P%d FE%d seed%d feasible%d collision%d late%.2f first%.0f\n', ...
   names{number},P,FE,seed,det.feasible,det.obstacleViolation,det.totalLate,info.FirstFeasibleEvaluation);
 end
end
summary=groupsummary(raw,'Scenario','mean',{'Feasible','GeometryFeasible','Distance','Late','ObstacleViolation'});
writetable(summary,fullfile(out,['holdout_' label '_summary.csv']));save(fullfile(out,['holdout_' label '_results.mat']),'raw','summary','choice');
disp(summary);
end
