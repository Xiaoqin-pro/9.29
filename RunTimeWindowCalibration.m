clc
clear
close all

%% Final Level-2 time-window calibration
root = fileparts(mfilename('fullpath'));
Particle_Number = 20;
maxgen = 100;
runs = 30;

% Candidate: initial before / initial after / future window.
windowBeforeList = [25 30 35 35];
windowAfterList = [40 45 45 50];
futureWindowList = [40 45 45 50];

% Columns:
% before, after, future, seed,
% static feasible, initial feasible, post feasible,
% static late, initial late, post late,
% static waiting, initial waiting, post waiting,
% static distance, initial distance, post distance, active orders.
results = zeros(length(windowBeforeList),runs,17);

for w = 1:length(windowBeforeList)
    cfg.mapSize = [100 100];
    cfg.timeWindowLevel = 2;
    cfg.serviceTime = 3;
    cfg.includeCancel = false;
    cfg.eventTime = 35;
    cfg.windowBefore = [50 windowBeforeList(w) 15];
    cfg.windowAfter = [70 windowAfterList(w) 25];
    cfg.futureWindow = [70 futureWindowList(w) 25];
    cfg.seed = 20260929;

    cfg.nInitialOrders = 20;
    cfg.nFutureOrders = 0;
    staticModel = CreateModel(cfg);
    staticState = InitialState(staticModel);

    cfg.nInitialOrders = 14;
    cfg.nFutureOrders = 6;
    dynamicModel = CreateModel(cfg);
    dynamicState = InitialState(dynamicModel);

    for j = 1:runs
        [staticBest,staticCurve] = PSO( ...
            staticModel,staticState,maxgen,Particle_Number,j); %#ok<ASGLU>

        [initialBest,initialCurve] = PSO( ...
            dynamicModel,dynamicState,maxgen,Particle_Number,j); %#ok<ASGLU>
        [eventState,remainingRoute] = ExecuteUntilEvent( ...
            dynamicModel,dynamicState,initialBest.Route,cfg.eventTime); %#ok<ASGLU>
        [dynamicModel,eventState,applied] = DynamicEvent( ...
            dynamicModel,eventState,dynamicModel.events(1)); %#ok<ASGLU>
        [postBest,postCurve] = PSO( ...
            dynamicModel,eventState,maxgen,Particle_Number,j+100); %#ok<ASGLU>

        results(w,j,:) = [windowBeforeList(w),windowAfterList(w), ...
            futureWindowList(w),j,staticBest.Detail.feasible, ...
            initialBest.Detail.feasible,postBest.Detail.feasible, ...
            staticBest.Detail.totalLate,initialBest.Detail.totalLate, ...
            postBest.Detail.totalLate,staticBest.Detail.totalWaiting, ...
            initialBest.Detail.totalWaiting,postBest.Detail.totalWaiting, ...
            staticBest.Detail.distance,initialBest.Detail.distance, ...
            postBest.Detail.distance,length(eventState.activeIDs)];
    end

    fprintf('Window %d/%d (future %d): static=%.2f, initial=%.2f, post=%.2f, ', ...
        windowBeforeList(w),windowAfterList(w),futureWindowList(w), ...
        mean(results(w,:,5)),mean(results(w,:,6)),mean(results(w,:,7)));
    fprintf('initial late=%.3f, initial waiting=%.3f, post late=%.3f, post waiting=%.3f\n', ...
        mean(results(w,:,9)),mean(results(w,:,12)), ...
        mean(results(w,:,10)),mean(results(w,:,13)));
end

flatResults = reshape(results,[],17);
outDir = fullfile(root,'results');
save(fullfile(outDir,'timewindow_calibration.mat'), ...
    'results','windowBeforeList','windowAfterList','futureWindowList', ...
    'Particle_Number','maxgen','runs');
writematrix(flatResults,fullfile(outDir,'timewindow_calibration.csv'));

figure('Color','w');
bar(1:length(windowBeforeList), ...
    [mean(results(:,:,5),2),mean(results(:,:,6),2),mean(results(:,:,7),2)]);
grid on
xlabel('Level-2 window candidate','fontsize',12);
ylabel('Feasible rate','fontsize',12);
legend('Static 20-order','Initial 14-order', ...
    'Post-event Restart','Location','best');
title('Final Level-2 time-window calibration');
xticks(1:length(windowBeforeList));
xticklabels({'25/40','30/45','35/45','35/50'});
exportgraphics(gcf,fullfile(outDir,'timewindow_calibration.png'),'Resolution',150);

function state = InitialState(model)
state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;
state.servedIDs = [];
state.cancelledIDs = [];
state.fixedIDs = [];
end
