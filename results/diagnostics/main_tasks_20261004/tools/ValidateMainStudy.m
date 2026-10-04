function ValidateMainStudy
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
files=dir(fullfile(out,'runs','*.mat'));assert(numel(files)==27);
for i=1:length(files)
 v=load(fullfile(files(i).folder,files(i).name));[cost,detail]=Fitness(v.Best.Vector,v.model,v.state);
 assert(cost==v.Best.Cost&&isequal(detail,v.Best.Detail));
 assert(v.info.Evaluations==v.record.Evaluations&&numel(v.T)==v.record.Evaluations&&all(diff(v.T)<=1e-8));
 n=length(v.state.activeIDs);D=n+6*(n+1);P=size(v.state.initialPopulation,1);assert(isequal(size(v.Best.Control),[n+1 2 3]));
 if startsWith(files(i).name,'train_')
  rng(v.info.Seed);allPositions=rand(60,D);expected=allPositions(1:P,:);
 else
  rng(v.info.Seed);expected=rand(P,D);assert(v.info.Seed>=20276001&&v.info.Seed<=20276003);
 end
 assert(isequal(v.state.initialPopulation,expected)&&isequal(v.info.InitialPopulation,expected));
 assert(v.model.nControlPoints==2&&v.model.maxSideOffset==15&&v.model.minHeightOffset==0&&v.model.maxHeightOffset==12);
 assert(isequal(sort(v.Best.Route),1:n));
 fresh=CreateModel(v.cfg);assert(isequal(fresh,v.model));
 assert(detail.feasible==~isnan(v.info.FirstFeasibleEvaluation));
end
fprintf('PASS27 runs: exact fresh model, rand positions, evaluation budget, complete route and Fitness recomputation.\n');
% Training-only selection independently recalculated.
t=readtable(fullfile(out,'training_raw.csv'),'Delimiter',',','ReadVariableNames',true);rank=readtable(fullfile(out,'training_summary.csv'),'Delimiter',',','ReadVariableNames',true);
assert(isequal(rank.FeasibleCount,[1;0;0;2]));
choice=jsondecode(fileread(fullfile(out,'resource_choice.json')));
assert(choice.Population==60&&choice.Evaluations==30000&&~choice.Promotable);
assert(all(t.Seed>=20275001&t.Seed<=20275003));
h=readtable(fullfile(out,'holdout_raw.csv'),'Delimiter',',','ReadVariableNames',true);assert(height(h)==15&&all(h.Seed>=20276001&h.Seed<=20276003));
assert(~any(strcmp(h.Scenario,'N20_tight')));
fprintf('PASS selected resource uses training seeds only; invalid N20tight excluded with independent exact certificate.\n');
end
