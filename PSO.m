function [BestSol,BestCost] = PSO(model,state,maxgen,Particle_Number,seed)
%PSO Insertion-based discrete PSO for UAV order sequencing.
%   Each particle is an order permutation.

rng(seed);
nVar = length(state.activeIDs);
pRandom = 0.5;
pPersonal = 0.5;
pGlobal = 0.8;

empty_particle.Position = [];
empty_particle.Cost = [];
empty_particle.Detail = [];
empty_particle.Best.Position = [];
empty_particle.Best.Cost = [];
empty_particle.Best.Detail = [];
particle = repmat(empty_particle,Particle_Number,1);

GlobalBest.Cost = inf;
for i = 1:Particle_Number
    particle(i).Position = state.activeIDs(randperm(nVar));
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
        position = particle(i).Position;

        if rand < pRandom
            position = RandomInsert(position);
        end
        if rand < pPersonal
            position = LearnInsert(position,particle(i).Best.Position);
        end
        if rand < pGlobal
            position = LearnInsert(position,GlobalBest.Position);
        end

        [particle(i).Cost,particle(i).Detail] = Fitness( ...
            position,model,state);
        particle(i).Position = position;

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
end

BestSol = GlobalBest;
BestSol.Route = BestSol.Detail.route;
end

function route = RandomInsert(route)
if length(route) < 2
    return
end

from = randi(length(route));
customer = route(from);
route(from) = [];
to = randi(length(route)+1);
route = [route(1:to-1),customer,route(to:end)];
end

function route = LearnInsert(route,guide)
if isempty(route)
    return
end

index = randi(length(guide));
customer = guide(index);
route(route == customer) = [];
to = min(index,length(route)+1);
route = [route(1:to-1),customer,route(to:end)];
end
