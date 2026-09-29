function [BestSol,BestCost] = PSO(model,state,maxgen,Particle_Number,seed)
%PSO Random-key PSO for UAV order sequencing.
%   Each particle is a random-key vector. Sorting the vector gives a route.

if nargin < 5
    seed = 1;
end

rng(seed);
nVar = length(state.activeIDs);
VarMin = zeros(1,nVar);
VarMax = ones(1,nVar);
Vmax = 0.20*(VarMax-VarMin);
Vmin = -Vmax;
w = 0.9;
wdamp = 0.99;
c1 = 2.0;
c2 = 2.0;

empty_particle.Position = [];
empty_particle.Velocity = [];
empty_particle.Cost = [];
empty_particle.Detail = [];
empty_particle.Best.Position = [];
empty_particle.Best.Cost = [];
empty_particle.Best.Detail = [];
particle = repmat(empty_particle,Particle_Number,1);

GlobalBest.Cost = inf;
for i = 1:Particle_Number
    particle(i).Position = rand(1,nVar);
    particle(i).Velocity = Vmin + (Vmax-Vmin).*rand(1,nVar);
    [particle(i).Cost,particle(i).Detail] = Fitness( ...
        particle(i).Position,model,state);

    particle(i).Best.Position = particle(i).Position;
    particle(i).Best.Cost = particle(i).Cost;
    particle(i).Best.Detail = particle(i).Detail;

    if particle(i).Best.Cost < GlobalBest.Cost
        GlobalBest = particle(i).Best;
    end
end

BestCost = zeros(maxgen,1);
for it = 1:maxgen
    for i = 1:Particle_Number
        particle(i).Velocity = w*particle(i).Velocity ...
            + c1*rand(1,nVar).*(particle(i).Best.Position ...
            - particle(i).Position) ...
            + c2*rand(1,nVar).*(GlobalBest.Position ...
            - particle(i).Position);
        particle(i).Velocity = max(Vmin,min(Vmax,particle(i).Velocity));

        particle(i).Position = particle(i).Position ...
            + particle(i).Velocity;
        particle(i).Position = max(VarMin,min(VarMax, ...
            particle(i).Position));

        [particle(i).Cost,particle(i).Detail] = Fitness( ...
            particle(i).Position,model,state);

        if particle(i).Cost < particle(i).Best.Cost
            particle(i).Best.Position = particle(i).Position;
            particle(i).Best.Cost = particle(i).Cost;
            particle(i).Best.Detail = particle(i).Detail;
        end

        if particle(i).Best.Cost < GlobalBest.Cost
            GlobalBest = particle(i).Best;
        end
    end

    BestCost(it) = GlobalBest.Cost;
    w = w*wdamp;
end

BestSol = GlobalBest;
BestSol.Route = BestSol.Detail.route;
end
