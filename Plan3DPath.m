function path = Plan3DPath(from,to,model)
%PLAN3DPATH Plan a short safe path between two 3-D points.
%   Candidates: direct, left-around, right-around and over.

pathList = cell(0,1);
pathList{end+1} = [from;to];

% Find the first cylinder touched by the direct segment.
direct = EvaluatePath(pathList{1},model);
if direct.isFeasible
    path = direct;
    path.points = pathList{1};
    path.usedDetour = false;
    path.directTerrainViolation = direct.terrainViolation;
    path.directObstacleViolation = direct.obstacleViolation;
    return
end

obs = model.obstacles(direct.blockedObstacle);
R = obs.r + model.obstacleSafety + 3;
move = to(1:2)-from(1:2);
if norm(move) < eps
    side = [1 0];
else
    side = [-move(2) move(1)]/norm(move);
end

leftXY = [obs.x obs.y] + R*side;
rightXY = [obs.x obs.y] - R*side;
terrainZ = max(model.terrainZ(:)) + model.minClearance + 1;
overZ = max([from(3),to(3),obs.zMax+model.obstacleSafety+5,terrainZ]);
P1 = [from(1:2) overZ];
P2 = [to(1:2) overZ];

pathList{end+1} = [from;leftXY max(from(3),to(3));to];
pathList{end+1} = [from;rightXY max(from(3),to(3));to];
pathList{end+1} = [from;P1;P2;to];

best = [];
bestKey = [inf inf];
for i = 1:length(pathList)
    result = EvaluatePath(pathList{i},model);
    key = [~result.isFeasible result.distance+10000*result.totalViolation];
    if key(1) < bestKey(1) || ...
            (key(1) == bestKey(1) && key(2) < bestKey(2))
        best = result;
        best.points = pathList{i};
        bestKey = key;
    end
end

path = best;
path.usedDetour = true;
path.directTerrainViolation = direct.terrainViolation;
path.directObstacleViolation = direct.obstacleViolation;
end

function result = EvaluatePath(points,model)
distance = 0;
terrainViolation = 0;
obstacleViolation = 0;
blockedObstacle = 1;
maxObstacleViolation = 0;

for i = 1:size(points,1)-1
    from = points(i,:);
    to = points(i+1,:);
    distance = distance + norm(to-from);
    t = linspace(0,1,model.safetySamples)';
    samples = from + t.*(to-from);

    ground = interp2(model.X,model.Y,model.terrainZ, ...
        samples(:,1),samples(:,2),'linear');
    terrainV = max(0,model.minClearance-(samples(:,3)-ground));
    terrainViolation = terrainViolation + mean(terrainV);

    for j = 1:length(model.obstacles)
        obs = model.obstacles(j);
        dx = samples(:,1)-obs.x;
        dy = samples(:,2)-obs.y;
        insideXY = sqrt(dx.^2+dy.^2) <= obs.r+model.obstacleSafety;
        insideZ = samples(:,3) >= obs.zMin-model.obstacleSafety ...
            & samples(:,3) <= obs.zMax+model.obstacleSafety;
        inside = insideXY & insideZ;
        amount = max(0,obs.zMax+model.obstacleSafety-samples(:,3));
        value = sum(amount(inside));
        obstacleViolation = obstacleViolation + value;
        if value > maxObstacleViolation
            maxObstacleViolation = value;
            blockedObstacle = j;
        end
    end
end

result.distance = distance;
result.terrainViolation = terrainViolation;
result.obstacleViolation = obstacleViolation;
result.totalViolation = terrainViolation + obstacleViolation;
result.isFeasible = result.totalViolation < 1e-8;
result.blockedObstacle = blockedObstacle;
end
