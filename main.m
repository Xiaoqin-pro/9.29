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
cfg.includeCancel = true;
cfg.cancelTimes = [70 120];
cfg.cancelIDs = [16 18];
cfg.eventTime = 35;
cfg.windowBefore = [50 30 15];
cfg.windowAfter = [70 45 25];
cfg.futureWindow = [70 45 25];
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
state.servedIDs = [];
state.cancelledIDs = [];
state.direction = [];
initialState = state;

%% Initial insertion-PSO planning
Particle_Number = 20;
maxgen = 100;
[best,bestCost] = PSO(model,state,maxgen,Particle_Number,1);
initialBest = best;
initialCost = bestCost;

%% Execute all dynamic events
for e = 1:length(model.events)
    event = model.events(e);
    [model,eventState,remainingRoute] = ExecuteUntilEvent( ...
        model,state,best.Route,event.time);
    [model,eventState] = DynamicEvent(model,eventState,event);
    [best,eventCost] = PSO(model,eventState,maxgen, ...
        Particle_Number,e+1);

    eventResults(e).time = event.time;
    eventResults(e).type = event.type;
    eventResults(e).orderIDs = event.orderIDs;
    eventResults(e).state = eventState;
    eventResults(e).remainingRoute = remainingRoute;
    eventResults(e).Best = best;
    eventResults(e).BestCost = eventCost;

    state = eventState;
    bestCost = eventCost;
end

Best0 = initialBest;
T0 = initialCost;
Best1 = best;
T1 = bestCost;
%% Save baseline results
save(fullfile(root,'results','main_result.mat'), ...
    'model','initialState','state','eventResults', ...
    'Best0','T0','Best1','T1');

PlotSolution(Best0,model,initialState, ...
    fullfile(root,'results','baseline_route_3D.png'));
PlotSolution(eventResults(1).Best,model,eventResults(1).state, ...
    fullfile(root,'results','event01_route_3D.png'));
PlotSolution(Best1,model,state, ...
    fullfile(root,'results','final_route_3D.png'));

figure('Color','w');
plot(T0,'LineWidth',1.5); hold on
for e = 1:length(eventResults)
    plot(eventResults(e).BestCost,'LineWidth',1.2);
end
grid on
xlabel('The Number of Iterations','fontsize',12);
ylabel('The Function Value','fontsize',12);
title('Dynamic 3-D UAV insertion-PSO baseline');
exportgraphics(gcf,fullfile(root,'results', ...
    'baseline_replanning_convergence.png'),'Resolution',150);

fprintf('Final cost:         %.3f\n',Best1.Cost);
fprintf('Final distance:     %.3f\n',Best1.Detail.distance);
fprintf('Final late:         %.3f\n',Best1.Detail.totalLate);
fprintf('Final feasible:     %d\n',Best1.Detail.feasible);
fprintf('Events executed:    %d\n',length(eventResults));
for e = 1:length(eventResults)
    fprintf('Event %2d: t=%.1f %s order=%d active=%d\n', ...
        e,eventResults(e).time,eventResults(e).type, ...
        eventResults(e).orderIDs,length(eventResults(e).state.activeIDs));
end
