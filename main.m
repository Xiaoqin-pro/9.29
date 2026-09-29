clc
clear
close all

%% 3-D UAV dynamic order routing demo
% The program keeps the simple style of the teacher's PSO example:
% create model -> run PSO -> calculate fitness -> plot results.

root = fileparts(mfilename('fullpath'));
if ~exist(fullfile(root,'results'),'dir')
    mkdir(fullfile(root,'results'));
end

%% Problem parameters
cfg.mapSize = [100 100];
cfg.nInitialOrders = 8;
cfg.nFutureOrders = 4;
cfg.seed = 20260929;
cfg.safetySamples = 30;
model = CreateModel(cfg);

state.time = 0;
state.position = model.depot;
state.activeIDs = model.activeIDs;
state.servedIDs = [];
state.cancelledIDs = [];
state.fixedIDs = [];

%% Initial planning
Particle_Number = 20;
maxgen = 100;
[Best0,T0] = PSO(model,state,maxgen,Particle_Number,1);

%% Execute the old route until the first dynamic event
[eventState,remainingRoute] = ExecuteUntilEvent( ...
    model,state,Best0.Route,model.events(1).time);
[model,eventState,applied] = DynamicEvent(model,eventState,model.events(1));
if ~applied
    error('The first dynamic event was not applied.');
end

%% Replanning after the event
% Restart-PSO does not use the old route.
[RestartBest,TRestart] = PSO(model,eventState,maxgen,Particle_Number,2);

% Warm-start PSO uses the old route as one source of initial particles.
[WarmBest,TWarm] = Warm_PSO(model,eventState,maxgen,Particle_Number,3,remainingRoute);

% EAT-PSO reconstructs the population from historical, insertion and random routes.
[EATBest,TEAT] = EAT_PSO(model,eventState,maxgen,Particle_Number,4,remainingRoute);

%% Save and display results
save(fullfile(root,'results','main_result.mat'), ...
    'model','state','Best0','T0','eventState','remainingRoute', ...
    'RestartBest','TRestart','WarmBest','TWarm','EATBest','TEAT');

PlotSolution(EATBest,model,eventState, ...
    fullfile(root,'results','EAT_PSO_route_3D.png'));

figure('Color','w');
plot(TRestart,'LineWidth',1.5); hold on
plot(TWarm,'LineWidth',1.5);
plot(TEAT,'LineWidth',1.8);
grid on
xlabel('The Number of Iterations','fontsize',12);
ylabel('The Function Value','fontsize',12);
legend('Restart-PSO','Warm-start PSO','EAT-PSO','Location','best');
title('Dynamic UAV replanning convergence');
exportgraphics(gcf,fullfile(root,'results','replanning_convergence.png'),'Resolution',150);

fprintf('Initial cost:       %.3f\n',Best0.Cost);
fprintf('Restart-PSO cost:   %.3f\n',RestartBest.Cost);
fprintf('Warm-start cost:    %.3f\n',WarmBest.Cost);
fprintf('EAT-PSO cost:       %.3f\n',EATBest.Cost);
fprintf('EAT-PSO late time:  %.3f\n',EATBest.Detail.totalLate);
fprintf('EAT-PSO feasible:   %d\n',EATBest.Detail.feasible);
