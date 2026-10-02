function [BestSol,BestCost] = PSO(model,state,maxgen,Particle_Number,seed)
%PSO Hybrid discrete-continuous PSO for order sequence and control points.

rng(seed);
nVar = length(state.activeIDs);
K = model.nControlPoints;
pRandom = 0.5;
pPbest = 0.5;
pGbest = 0.8;
w = 0.7;
wdamp = 0.995;
c1 = 1.5;
c2 = 1.5;

empty_particle.Route = [];
empty_particle.Control = [];
empty_particle.Velocity = [];
empty_particle.Cost = [];
empty_particle.Detail = [];
empty_particle.Best.Route = [];
empty_particle.Best.Control = [];
empty_particle.Best.Cost = [];
empty_particle.Best.Detail = [];
particle = repmat(empty_particle,Particle_Number,1);

GlobalBest.Cost = inf;
for i = 1:Particle_Number
    if i == 1
        particle(i).Route = model.referenceRoute;
        particle(i).Control = model.referenceControl;
    else
        particle(i).Route = state.activeIDs(randperm(nVar));
        particle(i).Control = InitialControlPoints( ...
            particle(i).Route,model,state.position);
    end
    particle(i).Velocity = randn(size(particle(i).Control));
    particle(i).Velocity(:,:,1) = 2*particle(i).Velocity(:,:,1);
    particle(i).Velocity(:,:,2) = particle(i).Velocity(:,:,2);
    [particle(i).Cost,particle(i).Detail] = Fitness( ...
        particle(i).Route,particle(i).Control,model,state);

    particle(i).Best.Route = particle(i).Route;
    particle(i).Best.Control = particle(i).Control;
    particle(i).Best.Cost = particle(i).Cost;
    particle(i).Best.Detail = particle(i).Detail;

    if particle(i).Best.Cost < GlobalBest.Cost
        GlobalBest = particle(i).Best;
    end
end

BestCost = zeros(maxgen,1);
for it = 1:maxgen
    for i = 1:Particle_Number
        route = particle(i).Route;
        if rand < pRandom
            route = RandomInsert(route);
        end
        if rand < pPbest
            route = LearnInsert(route,particle(i).Best.Route);
        end
        if rand < pGbest
            route = LearnInsert(route,GlobalBest.Route);
        end

        particle(i).Velocity = w*particle(i).Velocity ...
            + c1*rand(size(particle(i).Control)) ...
            .*(particle(i).Best.Control-particle(i).Control) ...
            + c2*rand(size(particle(i).Control)) ...
            .*(GlobalBest.Control-particle(i).Control);
        particle(i).Control = particle(i).Control+particle(i).Velocity;
        particle(i).Control(:,:,1) = max(0,min(model.mapSize(1), ...
            particle(i).Control(:,:,1)));
        particle(i).Control(:,:,1) = max(-model.maxSideOffset, ...
            min(model.maxSideOffset,particle(i).Control(:,:,1)));
        particle(i).Control(:,:,2) = max(-model.maxHeightOffset, ...
            min(model.maxHeightOffset,particle(i).Control(:,:,2)));

        [particle(i).Cost,particle(i).Detail] = Fitness( ...
            route,particle(i).Control,model,state);
        particle(i).Route = route;

        if particle(i).Cost < particle(i).Best.Cost
            particle(i).Best.Route = particle(i).Route;
            particle(i).Best.Control = particle(i).Control;
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
BestSol.Route = BestSol.Route;
end

function route = RandomInsert(route)
if length(route)<2, return; end
from = randi(length(route));
customer = route(from);
route(from) = [];
to = randi(length(route)+1);
route = [route(1:to-1),customer,route(to:end)];
end

function route = LearnInsert(route,guide)
index = randi(length(guide));
customer = guide(index);
route(route==customer) = [];
to = min(index,length(route)+1);
route = [route(1:to-1),customer,route(to:end)];
end
