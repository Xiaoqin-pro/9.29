function [cost,detail] = Fitness(route,control,model,state)
%FITNESS Evaluate order sequence and optimized control points.

current = state.position;
currentTime = state.time;
totalDistance = 0;
totalLate = 0;
totalWaiting = 0;
totalAngleViolation = 0;
totalSmoothness = 0;
maxClimbAngle = 0;
maxTurnAngle = 0;
terrainViolation = 0;
obstacleViolation = 0;
mapViolation = 0;
allPoints = current;
paths = DecodeControlPoints(route,control,model,current);
records = zeros(length(route),5);

for k = 1:length(route)
    id = route(k);
    path = EvaluatePolyline(paths{k},model);
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
    mapViolation = mapViolation + path.mapViolation;
    records(k,:) = [id arrival serviceStart late wait];
    paths{k} = path;

    currentTime = serviceStart + model.orders(id).service;
    allPoints = [allPoints;path.points(2:end,:)];
end

path = EvaluatePolyline(paths{end},model);
paths{end} = path;
totalDistance = totalDistance + path.distance;
terrainViolation = terrainViolation + path.terrainViolation;
obstacleViolation = obstacleViolation + path.obstacleViolation;
mapViolation = mapViolation + path.mapViolation;
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

if mapViolation > 1e-8
    cost = cost + 100000 + 10000*mapViolation;
end

detail.route = route;
detail.control = control;
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
detail.mapViolation = mapViolation;
detail.feasible = terrainViolation < 1e-8 ...
    && obstacleViolation < 1e-8 ...
    && totalAngleViolation < 1e-8 && totalLate < 1e-8 ...
    && mapViolation < 1e-8;
detail.finishTime = currentTime + path.distance/model.speed;
end

function result = EvaluatePolyline(points,model)
segments = diff(points,1,1);
horizontal = vecnorm(segments(:,1:2),2,2);
pitch = atan2d(segments(:,3),horizontal);
turn = zeros(max(0,size(segments,1)-1),1);
for i = 1:length(turn)
    turn(i) = TurnAngle(segments(i,:),segments(i+1,:));
end
angleViolation = sum(max(0,abs(pitch)-model.maxClimbAngle)) ...
    + sum(max(0,turn-model.maxTurnAngle));
smoothness = sum((turn/model.maxTurnAngle).^2) ...
    + sum((diff(pitch)/model.maxClimbAngle).^2);

terrainViolation = 0;
obstacleViolation = 0;
mapViolation = sum(sum(max(0,-points(:,1:2)) ...
    + max(0,points(:,1:2)-model.mapSize)));
for i = 1:size(segments,1)
    t = linspace(0,1,model.safetySamples)';
    samples = points(i,:)+t.*segments(i,:);
    xy = max(0,min(model.mapSize,samples(:,1:2)));
    ground = interp2(model.X,model.Y,model.terrainZ, ...
        xy(:,1),xy(:,2),'linear');
    terrainViolation = terrainViolation ...
        + mean(max(0,model.minClearance-(samples(:,3)-ground)));
    for j = 1:length(model.obstacles)
        obs = model.obstacles(j);
        insideXY = hypot(samples(:,1)-obs.x,samples(:,2)-obs.y) ...
            <= obs.r+model.obstacleSafety;
        insideZ = samples(:,3)>=obs.zMin-model.obstacleSafety ...
            & samples(:,3)<=obs.zMax+model.obstacleSafety;
        amount = max(0,obs.zMax+model.obstacleSafety-samples(:,3));
        inside = insideXY & insideZ;
        obstacleViolation = obstacleViolation+sum(amount(inside));
    end
end

result.points = points;
result.distance = sum(vecnorm(segments,2,2));
result.terrainViolation = terrainViolation;
result.obstacleViolation = obstacleViolation;
result.angleViolation = angleViolation;
result.mapViolation = mapViolation;
result.totalViolation = terrainViolation+obstacleViolation+angleViolation+mapViolation;
result.maxClimbAngle = max([0;abs(pitch)]);
result.maxTurnAngle = max([0;turn]);
result.smoothness = smoothness;
result.isFeasible = result.totalViolation<1e-8;
end

function angle = TurnAngle(first,second)
first = first(1:2);
second = second(1:2);
angle = atan2d(abs(first(1)*second(2)-first(2)*second(1)),dot(first,second));
end
