function control = InitialControlPoints(route,model,startPoint)
%INITIALCONTROLPOINTS Create local side/height initial control offsets.

nLegs = length(route)+1;
K = model.nControlPoints;
control = zeros(nLegs,K,2);
current = startPoint;

for i = 1:nLegs
    if i <= length(route)
        target = model.orders(route(i)).xyz;
    else
        target = model.depot;
    end

    blocked = BlockedObstacles(current,target,model);
    if ~isempty(blocked)
        move = target(1:2)-current(1:2);
        horizontal = norm(move);
        if horizontal < eps
            side = [1 0];
        else
            side = [-move(2) move(1)]/horizontal;
        end
        centers = [[model.obstacles(blocked).x]' ...
            [model.obstacles(blocked).y]'];
        radius = [model.obstacles(blocked).r]' ...
            + model.obstacleSafety + 3;
        across = (centers-current(1:2))*side';
        offset = min(model.maxSideOffset,max(abs(across)+radius)+10);
        control(i,:,1) = offset;
        pointsA = OffsetPoints(current,target,squeeze(control(i,:,:)),model);
        control(i,:,1) = -offset;
        pointsB = OffsetPoints(current,target,squeeze(control(i,:,:)),model);
        if ObstacleViolation(pointsA,model) <= ...
                ObstacleViolation(pointsB,model)
            control(i,:,1) = offset;
        end
        control(i,:,2) = 0;
    elseif TerrainBlocked(current,target,model)
        control(i,:,2) = min(model.maxHeightOffset, ...
            max(model.terrainZ(:))+model.minClearance+1 ...
            - mean([current(3),target(3)]));
    end
    current = target;
end
end

function ids = BlockedObstacles(from,to,model)
t = linspace(0,1,30)';
samples = from+t.*(to-from);
ids = [];
for j = 1:length(model.obstacles)
    obs = model.obstacles(j);
    insideXY = hypot(samples(:,1)-obs.x,samples(:,2)-obs.y) ...
        <= obs.r+model.obstacleSafety;
    insideZ = samples(:,3)>=obs.zMin-model.obstacleSafety ...
        & samples(:,3)<=obs.zMax+model.obstacleSafety;
    if any(insideXY & insideZ)
        ids(end+1) = j;
    end
end
end



function points = OffsetPoints(from,to,row,model)
move = to-from;
horizontal = norm(move(1:2));
if horizontal < eps
    side = [1 0];
else
    side = [-move(2) move(1)]/horizontal;
end
points = zeros(size(row,1)+2,3);
points(1,:) = from;
points(end,:) = to;
for k = 1:size(row,1)
    base = from+k/(size(row,1)+1)*move;
    points(k+1,:) = base;
    points(k+1,1:2) = base(1:2)+row(k,1)*side;
    points(k+1,3) = base(3)+row(k,2);
end
end

function value = ObstacleViolation(points,model)
value = 0;
for i = 1:size(points,1)-1
    t = linspace(0,1,30)';
    samples = points(i,:)+t.*(points(i+1,:)-points(i,:));
    for j = 1:length(model.obstacles)
        obs = model.obstacles(j);
        insideXY = hypot(samples(:,1)-obs.x,samples(:,2)-obs.y) ...
            <= obs.r+model.obstacleSafety;
        insideZ = samples(:,3)>=obs.zMin-model.obstacleSafety ...
            & samples(:,3)<=obs.zMax+model.obstacleSafety;
        amount = max(0,obs.zMax+model.obstacleSafety-samples(:,3));
        value = value+sum(amount(insideXY & insideZ));
    end
end
end

function yes = TerrainBlocked(from,to,model)
t = linspace(0,1,30)';
samples = from+t.*(to-from);
ground = interp2(model.X,model.Y,model.terrainZ, ...
    samples(:,1),samples(:,2),'linear');
yes = any(samples(:,3)-ground < model.minClearance);
end

