clc
clear
close all

%% Dynamic baseline difficulty calibration
root = fileparts(mfilename('fullpath'));
Particle_Number = 20;
maxgen = 100;
runs = 10;
eventTimes = [15 25 35];

% Columns: event time, run, served before event, active after event,
% cost, distance, late, feasible.
results = zeros(length(eventTimes),runs,8);

for e = 1:length(eventTimes)
    cfg.mapSize = [100 100];
    cfg.nInitialOrders = 14;
    cfg.nFutureOrders = 6;
    cfg.timeWindowLevel = 2;
    cfg.serviceTime = 3;
    cfg.includeCancel = false;
    cfg.eventTime = eventTimes(e);
    cfg.seed = 20260929;
    model = CreateModel(cfg);

    state.time = 0;
    state.position = model.depot;
    state.activeIDs = model.activeIDs;
    state.servedIDs = [];
    state.cancelledIDs = [];
    state.fixedIDs = [];

    [Best0,T0] = PSO(model,state,maxgen,Particle_Number,1); %#ok<ASGLU>
    [eventState,remainingRoute] = ExecuteUntilEvent( ...
        model,state,Best0.Route,eventTimes(e)); %#ok<ASGLU>
    [model,eventState,applied] = DynamicEvent( ...
        model,eventState,model.events(1)); %#ok<ASGLU>

    for j = 1:runs
        [best,T] = PSO(model,eventState,maxgen,Particle_Number,j); %#ok<ASGLU>
        results(e,j,:) = [eventTimes(e),j, ...
            length(eventState.servedIDs),length(eventState.activeIDs), ...
            best.Cost,best.Detail.distance,best.Detail.totalLate, ...
            best.Detail.feasible];
    end

    feasibleRate = mean(results(e,:,8));
    meanCost = mean(results(e,:,5));
    meanLate = mean(results(e,:,7));
    meanDistance = mean(results(e,:,6));
    fprintf('Event %d: served=%d, active=%d, feasible rate=%.2f, mean cost=%.3f, mean late=%.3f, mean distance=%.3f\n', ...
        eventTimes(e),length(eventState.servedIDs),length(eventState.activeIDs), ...
        feasibleRate,meanCost,meanLate,meanDistance);
end

flatResults = reshape(results,[],8);
outDir = fullfile(root,'results');
save(fullfile(outDir,'dynamic_baseline_calibration.mat'), ...
    'results','eventTimes','Particle_Number','maxgen','runs');
writematrix(flatResults,fullfile(outDir,'dynamic_baseline_calibration.csv'));

figure('Color','w');
bar(eventTimes,[mean(results(1,:,8));mean(results(2,:,8));mean(results(3,:,8))]);
grid on
xlabel('Event time','fontsize',12);
ylabel('Post-event feasible rate','fontsize',12);
title('Dynamic baseline difficulty calibration');
xticks(eventTimes);
exportgraphics(gcf,fullfile(outDir,'dynamic_baseline_calibration.png'),'Resolution',150);
