function [cost,detail] = Fitness(position,model,state)
%FITNESS Evaluate a complete UAV route.

route = position;

current = state.position;
currentTime = state.time;
direction = state.direction;
totalDistance = 0;
totalLate = 0;
totalWaiting = 0;
totalAngleViolation = 0;
totalSmoothness = 0;
maxClimbAngle = 0;
maxTurnAngle = 0;
terrainViolation = 0;
obstacleViolation = 0;
allPoints = current;
records = zeros(length(route),5);
paths = cell(length(route)+1,1);

for k = 1:length(route)
    id = route(k);
    target = model.orders(id).xyz;
    path = Plan3DPath(current,target,model,direction);
    travelTime = path.distance/model.speed;
    arrival = currentTime + travelTime;
    wait = max(0,model.orders(id).ready-arrival);
    serviceStart = arrival + wait;
    late = max(0,serviceStart-model.orders(id).due);

    totalDistance = totalDistance + path.distance;
    totalWaiting = totalWaiting + wait;
    totalAngleViolation = totalAngleViolation + path.angleViolation;
    totalSmoothness = totalSmoothness + path.smoothness;
    maxClimbAngle = max(maxClimbAngle,path.maxClimbAngle);
    maxTurnAngle = max(maxTurnAngle,path.maxTurnAngle);
    totalLate = totalLate + late;
    terrainViolation = terrainViolation + path.terrainViolation;
    obstacleViolation = obstacleViolation + path.obstacleViolation;
    records(k,:) = [id arrival serviceStart late wait];
    paths{k} = path;

    currentTime = serviceStart + model.orders(id).service;
    current = target;
    direction = [];
    allPoints = [allPoints;path.points(2:end,:)];
end

path = Plan3DPath(current,model.depot,model,direction);
paths{end} = path;
totalDistance = totalDistance + path.distance;
terrainViolation = terrainViolation + path.terrainViolation;
obstacleViolation = obstacleViolation + path.obstacleViolation;
totalAngleViolation = totalAngleViolation + path.angleViolation;
totalSmoothness = totalSmoothness + path.smoothness;
maxClimbAngle = max(maxClimbAngle,path.maxClimbAngle);
maxTurnAngle = max(maxTurnAngle,path.maxTurnAngle);
allPoints = [allPoints;path.points(2:end,:)];

cost = totalDistance + 0.05*totalWaiting ...
    + model.smoothWeight*totalSmoothness;

if totalLate > 1e-8
    cost = cost + 100000 + 1000*totalLate;
end
if totalAngleViolation > 1e-8
    cost = cost + 100000 + 10000*totalAngleViolation;
end
if terrainViolation > 1e-8
    cost = cost + 100000 + 10000*terrainViolation;
end
if obstacleViolation > 1e-8
    cost = cost + 100000 + 10000*obstacleViolation;
end

detail.route = route;
detail.records = records;
detail.paths = paths;
detail.points = allPoints;
detail.distance = totalDistance;
detail.totalLate = totalLate;
detail.totalWaiting = totalWaiting;
detail.totalAngleViolation = totalAngleViolation;
detail.totalSmoothness = totalSmoothness;
detail.maxClimbAngle = maxClimbAngle;
detail.maxTurnAngle = maxTurnAngle;
detail.terrainViolation = terrainViolation;
detail.obstacleViolation = obstacleViolation;
detail.feasible = terrainViolation < 1e-8 ...
    && obstacleViolation < 1e-8 ...
    && totalAngleViolation < 1e-8 && totalLate < 1e-8;
detail.finishTime = currentTime + path.distance/model.speed;
end
