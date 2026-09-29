clc
clear
close all

%% Static 20-order time-window calibration
root = fileparts(mfilename('fullpath'));
Particle_Number = 20;
maxgen = 100;
runs = 10;

% Results: level, seed, cost, distance, late, feasible
results = zeros(3,runs,6);

for level = 1:3
    cfg.nInitialOrders = 20;
    cfg.nFutureOrders = 0;
    cfg.timeWindowLevel = level;
    cfg.serviceTime = 3;
    cfg.seed = 20260929;
    model = CreateModel(cfg);
    state = InitialState(model);

    for j = 1:runs
        [best,curve] = PSO(model,state,maxgen,Particle_Number,j); %#ok<ASGLU>
        results(level,j,:) = [level,j,best.Cost, ...
            best.Detail.distance,best.Detail.totalLate, ...
            best.Detail.feasible];
    end

    feasibleRate = mean(results(level,:,6));
    meanLate = mean(results(level,:,5));
    meanDistance = mean(results(level,:,4));
    fprintf('Level %d: feasible rate=%.2f, mean late=%.3f, mean distance=%.3f\n', ...
        level,feasibleRate,meanLate,meanDistance);
end

flatResults = reshape(results,[],6);
outDir = fullfile(root,'results');
save(fullfile(outDir,'static_timewindow_calibration.mat'), ...
    'results','Particle_Number','maxgen','runs');
writematrix(flatResults,fullfile(outDir,'static_timewindow_calibration.csv'));

figure('Color','w');
bar(1:3,[mean(results(1,:,6));mean(results(2,:,6));mean(results(3,:,6))]);
grid on
xlabel('Time-window level','fontsize',12);
ylabel('Feasible rate','fontsize',12);
title('Static 20-order time-window calibration');
xticks(1:3);
exportgraphics(gcf,fullfile(outDir,'static_timewindow_calibration.png'),'Resolution',150);

function state = InitialState(model)
state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;
state.servedIDs = [];
state.cancelledIDs = [];
state.fixedIDs = [];
end
