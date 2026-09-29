clc
clear
close all

%% Static 20-order baseline diagnosis
root = fileparts(mfilename('fullpath'));
Particle_Number = 20;
maxgen = 100;
seed = 1;

% A: Level 1, random initialization
cfg.nInitialOrders = 20;
cfg.nFutureOrders = 0;
cfg.timeWindowLevel = 1;
cfg.serviceTime = 10;
cfg.seed = 20260929;
modelA = CreateModel(cfg);
stateA = InitialState(modelA);
[bestA,curveA] = PSO(modelA,stateA,maxgen,Particle_Number,seed);

% B: Level 2, reference-route initialization
cfg.timeWindowLevel = 2;
modelB = CreateModel(cfg);
stateB = InitialState(modelB);
[bestB,curveB] = PSO(modelB,stateB,maxgen,Particle_Number,seed, ...
    modelB.referenceRoute);

% C: Level 2, UAV service time = 3
cfg.serviceTime = 3;
modelC = CreateModel(cfg);
stateC = InitialState(modelC);
[bestC,curveC] = PSO(modelC,stateC,maxgen,Particle_Number,seed);

results = [ ...
    1 bestA.Cost bestA.Detail.distance bestA.Detail.totalLate ...
        bestA.Detail.terrainViolation bestA.Detail.obstacleViolation bestA.Detail.feasible; ...
    2 bestB.Cost bestB.Detail.distance bestB.Detail.totalLate ...
        bestB.Detail.terrainViolation bestB.Detail.obstacleViolation bestB.Detail.feasible; ...
    3 bestC.Cost bestC.Detail.distance bestC.Detail.totalLate ...
        bestC.Detail.terrainViolation bestC.Detail.obstacleViolation bestC.Detail.feasible];

fprintf('Case A: Level 1, random, service=10\n');
PrintResult(bestA);
fprintf('Case B: Level 2, reference initialization, service=10\n');
PrintResult(bestB);
fprintf('Case C: Level 2, random, service=3\n');
PrintResult(bestC);

outDir = fullfile(root,'results');
save(fullfile(outDir,'static_baseline_diagnostic.mat'), ...
    'results','modelA','modelB','modelC','bestA','bestB','bestC', ...
    'curveA','curveB','curveC');
writematrix(results,fullfile(outDir,'static_baseline_diagnostic.csv'));

figure('Color','w');
plot(curveA,'LineWidth',1.4); hold on
plot(curveB,'LineWidth',1.4);
plot(curveC,'LineWidth',1.4);
grid on
xlabel('The Number of Iterations','fontsize',12);
ylabel('The Function Value','fontsize',12);
legend('Level 1 random','Level 2 reference','Level 2 service=3', ...
    'Location','best');
title('Static 20-order baseline diagnosis');
exportgraphics(gcf,fullfile(outDir,'static_baseline_diagnostic.png'),'Resolution',150);

function state = InitialState(model)
state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;
state.servedIDs = [];
state.cancelledIDs = [];
state.fixedIDs = [];
end

function PrintResult(best)
fprintf('  cost=%.3f distance=%.3f late=%.3f terrain=%.3f obstacle=%.3f feasible=%d\n', ...
    best.Cost,best.Detail.distance,best.Detail.totalLate, ...
    best.Detail.terrainViolation,best.Detail.obstacleViolation, ...
    best.Detail.feasible);
end
