clc
clear
close all

%% Static 3-D UAV time-window routing baseline
root = fileparts(mfilename('fullpath'));
if ~exist(fullfile(root,'results'),'dir')
    mkdir(fullfile(root,'results'));
end

%% Problem parameters
cfg.dataFile = fullfile(root,'data','rc101.txt');
cfg.mapSize = [100 100];
cfg.nOrders = 20;
cfg.nControlPoints = 2;
cfg.minControlRatio = 0.05;
cfg.maxControlRatio = 0.95;
cfg.maxSideOffset = 30;
cfg.maxHeightOffset = 25;
cfg.serviceTime = 3;
cfg.twScale = 1.0;
cfg.seed = 20260929;
cfg.safetySamples = 30;
cfg.maxClimbAngle = 25;
cfg.maxTurnAngle = 120;
cfg.smoothWeight = 2;
model = CreateModel(cfg);

%% Initial state
state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;

%% Reference route and PSO planning
K = model.nControlPoints;
referenceControl = zeros(model.nOrders+1,K,3);
referenceControl(:,:,1) = repmat((1:K)/(K+1),model.nOrders+1,1);
[referenceCost,referenceDetail] = Fitness( ...
    model.referenceRoute,referenceControl,model,state);
Particle_Number = 20;
maxgen = 100;
[Best,T] = PSO(model,state,maxgen,Particle_Number,1);

%% Save and plot the static result
Reference.Route = model.referenceRoute;
Reference.Control = referenceControl;
Reference.Cost = referenceCost;
Reference.Detail = referenceDetail;
save(fullfile(root,'results','main_result.mat'), ...
    'model','state','Reference','Best','T');

PlotSolution(Best,model,state, ...
    fullfile(root,'results','baseline_route_3D.png'),'route');
PlotSolution(Best,model,state, ...
    fullfile(root,'results','all_orders_route_3D.png'),'all');

figure('Color','w');
plot(T,'LineWidth',1.8);
grid on
xlabel('The Number of Iterations','fontsize',12);
ylabel('The Function Value','fontsize',12);
title('Static 3-D UAV local-control hybrid PSO');
exportgraphics(gcf,fullfile(root,'results', ...
    'baseline_convergence.png'),'Resolution',150);

fprintf('Reference cost:      %.3f\n',Reference.Cost);
fprintf('Reference feasible:  %d\n',Reference.Detail.feasible);
fprintf('Cost:                %.3f\n',Best.Cost);
fprintf('Reference distance:  %.3f\n',Reference.Detail.distance);
fprintf('Route changed:       %d\n',~isequal(Best.Route,Reference.Route));
fprintf('Control change:      %.3f\n',norm(Best.Control(:)-Reference.Control(:)));
idx = find(T<Reference.Cost-1e-8,1);
if isempty(idx), idx = 0; end
fprintf('First improvement:   %d\n',idx);
fprintf('Distance:            %.3f\n',Best.Detail.distance);
fprintf('Late:                %.3f\n',Best.Detail.totalLate);
fprintf('Waiting:             %.3f\n',Best.Detail.totalWaiting);
fprintf('Feasible:            %d\n',Best.Detail.feasible);
fprintf('Max climb angle:     %.3f deg\n',Best.Detail.maxClimbAngle);
fprintf('Max turn angle:      %.3f deg\n',Best.Detail.maxTurnAngle);
fprintf('Smoothness:          %.3f\n',Best.Detail.totalSmoothness);
