function [BestSol,BestCost] = Warm_PSO(model,state,maxgen,Particle_Number,seed,previousRoute)
%WARM_PSO PSO initialized around the route before the dynamic event.
if nargin < 6
    previousRoute = [];
end
[BestSol,BestCost] = PSO(model,state,maxgen,Particle_Number,seed,previousRoute);
end
