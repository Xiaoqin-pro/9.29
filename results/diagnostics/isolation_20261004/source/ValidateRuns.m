function ValidateRuns
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));addpath(root);out=fileparts(fileparts(mfilename('fullpath')));addpath(out);
d=load(fullfile(out,'input','experiment_cases.mat'),'Cases');
files=dir(fullfile(out,'runs','*.mat'));assert(numel(files)==65);
for i=1:numel(files)
 v=load(fullfile(files(i).folder,files(i).name));
 if startsWith(files(i).name,'full_')
  [cost,detail]=Fitness(v.Best.Vector,v.model,v.state);
  n=length(v.state.activeIDs);D=n+3*(n+1)*v.model.nControlPoints;
  rng(v.info.Seed);expected=rand(30,D);
  item=d.Cases{2,find(cellfun(@(x)isequal(x.Model,v.model),d.Cases(2,:)),1)};
  assert(isequal(v.model,item.Model));
 elseif startsWith(files(i).name,'route_')
  [cost,detail]=EvaluateDiagnostic(v.Best.Vector,v.model,v.state,'RouteOnly',[]);
  rng(v.info.Seed);expected=rand(30,length(v.state.activeIDs));
 else
  [cost,detail]=EvaluateDiagnostic(v.Best.Vector,v.model,v.state,'ControlOnly',v.fixedRoute);
  n=length(v.fixedRoute);rng(v.info.Seed);expected=rand(30,3*(n+1)*v.model.nControlPoints);
  assert(isequal(v.Best.Route,v.fixedRoute));
  assert(v.model.depotDue==1e9&&all([v.model.orders.ready]==0)&&all([v.model.orders.due]==1e9));
  m=v.model;m.depotReady=v.originalModel.depotReady;m.depotDue=v.originalModel.depotDue;
  for id=1:n,m.orders(id).ready=v.originalModel.orders(id).ready;m.orders(id).due=v.originalModel.orders(id).due;end
  assert(isequal(m,v.originalModel));
  assert(detail.totalLate==0&&detail.depotLate==0&&detail.totalWaiting==0);
 end
 assert(abs(cost-v.Best.Cost)<1e-8&&isequal(detail,v.Best.Detail));
 assert(isequal(expected,v.state.initialPopulation)&&isequal(expected,v.info.InitialPopulation));
 assert(v.info.Evaluations==3000&&numel(v.T)==3000&&all(isfinite(v.T))&&all(diff(v.T)<=1e-7));
 assert(isequal(sort(v.Best.Route),sort(v.state.activeIDs)));
end
witness=load(fullfile(out,'input','archived_witness.mat'),'Best');item=d.Cases{2,6};
[c,det]=Fitness(witness.Best.Vector,item.Model,item.State);assert(det.feasible);
fprintf('PASS all 65 runs independently reevaluated; pure rand inputs, exact budgets, invariant models and fixed ControlOnly route.\n');
% Replay one full-size RouteOnly and ControlOnly run; no diagnostic result mutation.
v=load(fullfile(out,'runs','route_N20_wide_r2.mat'));
[B,T,info]=DiagnosticPSO(v.model,v.state,100,30,v.info.Seed,'RouteOnly',[]);
assert(isequal(B,v.Best)&&isequal(T,v.T));
v=load(fullfile(out,'runs','control_r1.mat'));
[B,T,info]=DiagnosticPSO(v.model,v.state,100,30,v.info.Seed,'ControlOnly',v.fixedRoute);
assert(isequal(B,v.Best)&&isequal(T,v.T));
fprintf('PASS full FE3000 diagnostic replay for both isolated searches.\n');
end
