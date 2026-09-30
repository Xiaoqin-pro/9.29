clc
clear
close all

%% Final fixed baseline repeatability check
root = fileparts(mfilename('fullpath'));
Particle_Number = 20;
maxgen = 100;
runs = 30;

cfg.mapSize = [100 100];
cfg.timeWindowLevel = 2;
cfg.serviceTime = 3;
cfg.includeCancel = false;
cfg.eventTime = 35;
cfg.windowBefore = [50 30 15];
cfg.windowAfter = [70 45 25];
cfg.futureWindow = [70 45 25];
cfg.seed = 20260929;

% Columns: seed, static feasible, initial feasible, post feasible,
% static late, initial late, post late, static waiting,
% initial waiting, post waiting, static distance, initial distance,
% post distance, active orders.
results = zeros(runs,14);

cfg.nInitialOrders = 20;
cfg.nFutureOrders = 0;
staticModel = CreateModel(cfg);
staticState = InitialState(staticModel);

cfg.nInitialOrders = 14;
cfg.nFutureOrders = 6;
dynamicModel0 = CreateModel(cfg);
dynamicState0 = InitialState(dynamicModel0);

for j = 1:runs
    [staticBest,staticCurve] = PSO( ...
        staticModel,staticState,maxgen,Particle_Number,j); %#ok<ASGLU>

    [initialBest,initialCurve] = PSO( ...
        dynamicModel0,dynamicState0,maxgen,Particle_Number,j); %#ok<ASGLU>
    [eventState,remainingRoute] = ExecuteUntilEvent( ...
        dynamicModel0,dynamicState0,initialBest.Route,cfg.eventTime); %#ok<ASGLU>
    dynamicModel = dynamicModel0;
    [dynamicModel,eventState,applied] = DynamicEvent( ...
        dynamicModel,eventState,dynamicModel.events(1)); %#ok<ASGLU>
    [postBest,postCurve] = PSO( ...
        dynamicModel,eventState,maxgen,Particle_Number,j+100); %#ok<ASGLU>

    results(j,:) = [j,staticBest.Detail.feasible, ...
        initialBest.Detail.feasible,postBest.Detail.feasible, ...
        staticBest.Detail.totalLate,initialBest.Detail.totalLate, ...
        postBest.Detail.totalLate,staticBest.Detail.totalWaiting, ...
        initialBest.Detail.totalWaiting,postBest.Detail.totalWaiting, ...
        staticBest.Detail.distance,initialBest.Detail.distance, ...
        postBest.Detail.distance,length(eventState.activeIDs)];
end

fprintf('Final baseline 30-run result\n');
fprintf('Static feasible rate: %.2f\n',mean(results(:,2)));
fprintf('Initial feasible rate: %.2f\n',mean(results(:,3)));
fprintf('Post-event feasible rate: %.2f\n',mean(results(:,4)));
fprintf('Initial late: %.3f, waiting: %.3f\n', ...
    mean(results(:,6)),mean(results(:,9)));
fprintf('Post-event late: %.3f, waiting: %.3f\n', ...
    mean(results(:,7)),mean(results(:,10)));
fprintf('Post-event distance: %.3f\n',mean(results(:,13)));
fprintf('Active orders after event: %.3f\n',mean(results(:,14)));

outDir = fullfile(root,'results');
save(fullfile(outDir,'final_baseline_repeatability.mat'), ...
    'results','Particle_Number','maxgen','runs');
writematrix(results,fullfile(outDir,'final_baseline_repeatability.csv'));

function state = InitialState(model)
state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;
state.servedIDs = [];
state.cancelledIDs = [];
state.fixedIDs = [];
end
