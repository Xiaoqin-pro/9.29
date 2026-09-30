clc
clear
close all

%% Dynamic 3-D UAV routing baseline
root = fileparts(mfilename('fullpath'));
if ~exist(fullfile(root,'results'),'dir')
    mkdir(fullfile(root,'results'));
end

%% Problem parameters
cfg.dataFile = fullfile(root,'data','rc101.txt');
cfg.mapSize = [100 100];
cfg.nInitialOrders = 14;
cfg.nFutureOrders = 6;
cfg.timeWindowLevel = 2;
cfg.serviceTime = 3;
cfg.includeCancel = false;
cfg.eventTime = 35;
cfg.windowBefore = [50 30 15];
cfg.windowAfter = [70 45 25];
cfg.futureWindow = [70 45 25];
cfg.seed = 20260929;
cfg.safetySamples = 30;
model = CreateModel(cfg);

%% Initial state
state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;
state.servedIDs = [];
state.cancelledIDs = [];

%% Initial PSO planning
Particle_Number = 20;
maxgen = 100;
[Best0,T0] = PSO(model,state,maxgen,Particle_Number,1);

%% Execute to the first new-order event
[eventState,remainingRoute] = ExecuteUntilEvent( ...
    model,state,Best0.Route,model.events(1).time);
[model,eventState] = DynamicEvent( ...
    model,eventState,model.events(1));

%% Standard PSO after the event
[Best1,T1] = PSO(model,eventState,maxgen,Particle_Number,2);

%% Save baseline results
save(fullfile(root,'results','main_result.mat'), ...
    'model','state','Best0','T0','eventState','remainingRoute', ...
    'Best1','T1');

PlotSolution(Best1,model,eventState, ...
    fullfile(root,'results','baseline_route_3D.png'));

figure('Color','w');
plot(T0,'LineWidth',1.5); hold on
plot(T1,'LineWidth',1.8);
grid on
xlabel('The Number of Iterations','fontsize',12);
ylabel('The Function Value','fontsize',12);
legend('Initial standard PSO','Post-event standard PSO','Location','best');
title('Dynamic 3-D UAV routing baseline');
exportgraphics(gcf,fullfile(root,'results', ...
    'baseline_replanning_convergence.png'),'Resolution',150);

fprintf('Initial cost:       %.3f\n',Best0.Cost);
fprintf('Initial distance:   %.3f\n',Best0.Detail.distance);
fprintf('Initial late:       %.3f\n',Best0.Detail.totalLate);
fprintf('Event time:         %.3f\n',eventState.time);
fprintf('Event position:     [%.3f %.3f %.3f]\n', ...
    eventState.position(1),eventState.position(2),eventState.position(3));
fprintf('Added order:        %d\n',model.events(1).orderIDs);
fprintf('Post-event orders:  %d\n',length(eventState.activeIDs));
fprintf('Post-event cost:    %.3f\n',Best1.Cost);
fprintf('Post-event distance:%.3f\n',Best1.Detail.distance);
fprintf('Post-event late:    %.3f\n',Best1.Detail.totalLate);
nDetour0 = 0;
nTerrain0 = 0;
nObstacle0 = 0;
for i = 1:length(Best0.Detail.paths)
    if size(Best0.Detail.paths{i}.points,1) > 2
        nDetour0 = nDetour0 + 1;
    end
    if Best0.Detail.paths{i}.directTerrainViolation > 0
        nTerrain0 = nTerrain0 + 1;
    end
    if Best0.Detail.paths{i}.directObstacleViolation > 0
        nObstacle0 = nObstacle0 + 1;
    end
end
nDetour1 = 0;
nTerrain1 = 0;
nObstacle1 = 0;
for i = 1:length(Best1.Detail.paths)
    if size(Best1.Detail.paths{i}.points,1) > 2
        nDetour1 = nDetour1 + 1;
    end
    if Best1.Detail.paths{i}.directTerrainViolation > 0
        nTerrain1 = nTerrain1 + 1;
    end
    if Best1.Detail.paths{i}.directObstacleViolation > 0
        nObstacle1 = nObstacle1 + 1;
    end
end
fprintf('Post-event feasible: %d\n',Best1.Detail.feasible);
fprintf('Initial detour legs: %d\n',nDetour0);
fprintf('Initial terrain-blocked direct legs: %d\n',nTerrain0);
fprintf('Initial obstacle-blocked direct legs: %d\n',nObstacle0);
fprintf('Post-event detour legs: %d\n',nDetour1);
fprintf('Post-event terrain-blocked direct legs: %d\n',nTerrain1);
fprintf('Post-event obstacle-blocked direct legs: %d\n',nObstacle1);
