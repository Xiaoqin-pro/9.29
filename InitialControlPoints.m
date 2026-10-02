function control = InitialControlPoints(route,model,startPoint)
%INITIALCONTROLPOINTS Create route-aware sloped initial control points.

nLegs = length(route)+1;
K = model.nControlPoints;
control = zeros(nLegs,K,3);
current = startPoint;

for i = 1:nLegs
    if i <= length(route)
        target = model.orders(route(i)).xyz;
    else
        target = model.depot;
    end

    points = [current;target];
    blocked = BlockedObstacles(points,model);
    obstacle = 0;
    if ~isempty(blocked)
        obstacle = blocked(1);
    end
    terrainBlocked = TerrainBlocked(points,model);

    if obstacle > 0
        obs = model.obstacles(obstacle);
        move = target(1:2)-current(1:2);
        lengthXY = norm(move);
        if lengthXY < eps
            forward = [1 0];
        else
            forward = move/lengthXY;
        end
        side = [-forward(2) forward(1)];
        obstacles = model.obstacles(blocked);
        centers = [[obstacles.x]' [obstacles.y]'];
        radii = [obstacles.r]'+model.obstacleSafety+3;
        along = (centers-current(1:2))*forward';
        across = (centers-current(1:2))*side';
        entry = min(along-radii);
        exit = max(along+radii);
        overZ = max([current(3),target(3), ...
            max([obstacles.zMax])+model.obstacleSafety+1, ...
            max(model.terrainZ(:))+model.minClearance+1]);
        points = [];
        bestObstacle = inf;
        for sign = [1 -1]
            offset = sign*max(abs(across)+radii);
            p1 = current(1:2)+entry*forward+offset*side;
            p2 = current(1:2)+exit*forward+offset*side;
            candidate = [current;p1 overZ;p2 overZ;target];
            candidate = LimitControlAngles(candidate,model.maxClimbAngle);
            obstacle = ObstacleViolation(candidate,model);
            if obstacle < bestObstacle
                points = candidate;
                bestObstacle = obstacle;
            end
        end
    elseif terrainBlocked
        overZ = max([current(3),target(3), ...
            max(model.terrainZ(:))+model.minClearance+1]);
        points = SlopedPath(points,current(3),target(3), ...
            overZ,model.maxClimbAngle);
    end

    controlPoints = SampleControlPoints(points,K);
    controlPoints = LimitControlAngles( ...
        [current;controlPoints;target],model.maxClimbAngle);
    control(i,:,:) = controlPoints(2:end-1,:);
    current = target;
end
end

function ids = BlockedObstacles(points,model)
t = linspace(0,1,25)';
samples = points(1,:)+t.*(points(2,:)-points(1,:));
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

function yes = TerrainBlocked(points,model)
t = linspace(0,1,25)';
samples = points(1,:)+t.*(points(2,:)-points(1,:));
ground = interp2(model.X,model.Y,model.terrainZ, ...
    samples(:,1),samples(:,2),'linear');
yes = any(samples(:,3)-ground < model.minClearance);
end


function value = ObstacleViolation(points,model)
value = 0;
for i = 1:size(points,1)-1
    t = linspace(0,1,25)';
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

function points = SlopedPath(points,startZ,endZ,overZ,maxAngle)
span = [0;cumsum(vecnorm(diff(points,1,1),2,2))];
slope = tand(maxAngle);
peakZ = min(overZ,(startZ+endZ+slope*span(end))/2);
s = unique([span; ...
    (peakZ-startZ)/slope; ...
    span(end)-(peakZ-endZ)/slope]);
s = s(s>=0 & s<=span(end));
keep = [true;diff(span)>1e-10];
xy = interp1(span(keep),points(keep,1:2),s);
z = min([startZ+slope*s, ...
    endZ+slope*(span(end)-s), ...
    overZ*ones(size(s))],[],2);
z(1) = startZ;
z(end) = endZ;
points = [xy z];
end


function points = LimitControlAngles(points,maxAngle)
slope = tand(maxAngle);
K = size(points,1)-2;
for pass = 1:2
    for i = 1:K
        horizontal = norm(points(i+1,1:2)-points(i,1:2));
        dz = points(i+1,3)-points(i,3);
        limit = slope*horizontal;
        points(i+1,3) = points(i,3)+max(-limit,min(limit,dz));
    end
    for i = K+2:-1:3
        horizontal = norm(points(i,1:2)-points(i-1,1:2));
        dz = points(i-1,3)-points(i,3);
        limit = slope*horizontal;
        points(i-1,3) = points(i,3)+max(-limit,min(limit,dz));
    end
end
end

function control = SampleControlPoints(points,K)
if K == 2 && size(points,1) == 4
    control = points(2:3,:);
    return
end
span = [0;cumsum(vecnorm(diff(points,1,1),2,2))];
s = (1:K)'/(K+1)*span(end);
control = interp1(span,points,s);
end

