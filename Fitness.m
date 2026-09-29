function [cost,detail] = Fitness(position,model,state)
%FITNESS Evaluate a route in the 3-D terrain with time windows.

[~,order] = sort(position);
route = state.activeIDs(order);
if isempty(position)
    route = [];
end

current = state.position;
currentTime = state.time;
totalDistance = 0;
totalLate = 0;
totalWaiting = 0;
terrainViolation = 0;
obstacleViolation = 0;
allPoints = current;
records = zeros(length(route),5);

for k = 1:length(route)
    id = route(k);
    target = model.orders(id).xyz;
    [distance,terrainV,obstacleV,points] = LegCost(current,target,model);
    travelTime = distance/model.speed;
    arrival = currentTime + travelTime;
    wait = max(0,model.orders(id).ready-arrival);
    serviceStart = arrival + wait;
    late = max(0,serviceStart-model.orders(id).due);

    totalDistance = totalDistance + distance;
    totalWaiting = totalWaiting + wait;
    totalLate = totalLate + late;
    terrainViolation = terrainViolation + terrainV;
    obstacleViolation = obstacleViolation + obstacleV;
    records(k,:) = [id arrival serviceStart late wait];

    currentTime = serviceStart + model.orders(id).service;
    current = target;
    allPoints = [allPoints; points(2:end,:)]; %#ok<AGROW>
end

[distance,terrainV,obstacleV,points] = LegCost(current,model.depot,model);
totalDistance = totalDistance + distance;
terrainViolation = terrainViolation + terrainV;
obstacleViolation = obstacleViolation + obstacleV;
allPoints = [allPoints; points(2:end,:)]; %#ok<AGROW>

cost = totalDistance + 0.05*totalWaiting + 50*totalLate ...
    + 10000*terrainViolation + 10000*obstacleViolation;

routeViolation = terrainViolation + obstacleViolation;
detail.route = route;
detail.records = records;
detail.distance = totalDistance;
detail.totalLate = totalLate;
detail.totalWaiting = totalWaiting;
detail.terrainViolation = terrainViolation;
detail.obstacleViolation = obstacleViolation;
detail.feasible = routeViolation < 1e-8 && totalLate < 1e-8;
detail.points = allPoints;
detail.finishTime = currentTime + distance/model.speed;
end

function [distance,terrainViolation,obstacleViolation,points] = LegCost(from,to,model)
points = [from; to];
distance = norm(to-from);

% Sample the straight 3-D flight segment.
t = linspace(0,1,model.safetySamples)';
samples = from + t.*(to-from);
ground = interp2(model.X,model.Y,model.terrainZ, ...
    samples(:,1),samples(:,2),'linear');
clearance = samples(:,3)-ground;
terrainViolation = mean(max(0,model.minClearance-clearance));

obstacleViolation = 0;
for j = 1:length(model.obstacles)
    obs = model.obstacles(j);
    inside = samples(:,1)>=obs.xMin-model.obstacleSafety ...
        & samples(:,1)<=obs.xMax+model.obstacleSafety ...
        & samples(:,2)>=obs.yMin-model.obstacleSafety ...
        & samples(:,2)<=obs.yMax+model.obstacleSafety;
    heightV = max(0,obs.zMax+model.obstacleSafety-samples(:,3));
    if any(inside)
        obstacleViolation = obstacleViolation + mean(heightV(inside));
    end
end
end


