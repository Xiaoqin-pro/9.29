function [cost,detail] = Fitness(position,model,state)
%FITNESS Evaluate a complete UAV route.

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
paths = cell(length(route)+1,1);

for k = 1:length(route)
    id = route(k);
    target = model.orders(id).xyz;
    path = Plan3DPath(current,target,model);
    travelTime = path.distance/model.speed;
    arrival = currentTime + travelTime;
    wait = max(0,model.orders(id).ready-arrival);
    serviceStart = arrival + wait;
    late = max(0,serviceStart-model.orders(id).due);

    totalDistance = totalDistance + path.distance;
    totalWaiting = totalWaiting + wait;
    totalLate = totalLate + late;
    terrainViolation = terrainViolation + path.terrainViolation;
    obstacleViolation = obstacleViolation + path.obstacleViolation;
    records(k,:) = [id arrival serviceStart late wait];
    paths{k} = path;

    currentTime = serviceStart + model.orders(id).service;
    current = target;
    allPoints = [allPoints;path.points(2:end,:)]; %#ok<AGROW>
end

path = Plan3DPath(current,model.depot,model);
paths{end} = path;
totalDistance = totalDistance + path.distance;
terrainViolation = terrainViolation + path.terrainViolation;
obstacleViolation = obstacleViolation + path.obstacleViolation;
allPoints = [allPoints;path.points(2:end,:)]; %#ok<AGROW>

cost = totalDistance + 0.05*totalWaiting + 50*totalLate ...
    + 10000*terrainViolation + 10000*obstacleViolation;

detail.route = route;
detail.records = records;
detail.paths = paths;
detail.points = allPoints;
detail.distance = totalDistance;
detail.totalLate = totalLate;
detail.totalWaiting = totalWaiting;
detail.terrainViolation = terrainViolation;
detail.obstacleViolation = obstacleViolation;
detail.feasible = terrainViolation < 1e-8 ...
    && obstacleViolation < 1e-8 && totalLate < 1e-8;
detail.finishTime = currentTime + path.distance/model.speed;
end
