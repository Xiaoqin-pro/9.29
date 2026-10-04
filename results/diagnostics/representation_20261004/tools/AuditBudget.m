function AuditBudget
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
cfg.stationFile=fullfile(root,'data','experiment_cases','N10_wide.csv');cfg.nOrders=10;cfg.terrainType=2;algorithms={'PSO','CSO','CLPSO','GWO'};
rows=cell(8,1);count=0;
for K=[1 2]
 cfg.nControlPoints=K;model=CreateModel(cfg);D=10+3*11*K;
 seed=20274501;state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs,'maxEvaluations',127);
 rng(seed);state.initialPopulation=rand(30,D);
 for k=1:4
  profile clear;profile on;[Best,T,info]=feval(algorithms{k},model,state,5,30,seed);profile off;p=profile('info');
  calls=p.FunctionTable(strcmp({p.FunctionTable.FunctionName},'Fitness'));
  assert(numel(calls)==1&&calls.NumCalls==127&&info.Evaluations==127&&numel(T)==127);
  assert(isequal(info.InitialPopulation,state.initialPopulation));
  assert(all(Best.Vector>=0&Best.Vector<=1));
  [cost,detail]=Fitness(Best.Vector,model,state);assert(cost==Best.Cost&&isequal(detail,Best.Detail));
  if k==2,assert(info.SeekingEvaluations+info.TracingEvaluations+30==127);end
  count=count+1;rows{count}=struct('K',K,'Algorithm',algorithms{k},'FitnessCalls',calls.NumCalls,'RecordedFE',info.Evaluations,'SharedInitialPopulation',true,'ResultRecomputed',true);
 end
end
checks=struct2table(vertcat(rows{:}));writetable(checks,fullfile(out,'budget_audit.csv'));
fprintf('PASS four algorithms/K1/K2: actual FE127, shared rand positions, closed domain and recomputed result.\n');
end
