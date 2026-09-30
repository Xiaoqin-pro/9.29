function path = Plan3DPath(from,to,model,initialDirection)
%PLAN3DPATH Direct, two-waypoint side detours and sloped overflight.

direct = EvaluatePath([from;to],model,initialDirection);
if direct.isFeasible
    path = direct;
else
    move = to(1:2)-from(1:2);
    lengthXY = norm(move);
    if lengthXY < eps
        forward = [1 0];
    else
        forward = move/lengthXY;
    end
    side = [-forward(2) forward(1)];
    candidates = {};
    overZ = max([from(3),to(3), ...
        max(model.terrainZ(:))+model.minClearance+1]);

    % Two side waypoints around the cylinders blocking the direct leg.
    corridors = {[from(1:2);to(1:2)]};
    if direct.obstacleViolation > 1e-8
        obstacles = model.obstacles(direct.blockedObstacles);
        center = [[obstacles.x]' [obstacles.y]'];
        radius = [obstacles.r]'+model.obstacleSafety+3;
        along = (center-from(1:2))*forward';
        across = (center-from(1:2))*side';
        entry = min(along-radius);
        exit = max(along+radius);
        for offset = [max(across+radius),min(across-radius)]
            p1 = from(1:2)+entry*forward+offset*side;
            p2 = from(1:2)+exit*forward+offset*side;
            xy = [from(1:2);p1;p2;to(1:2)];
            corridors{end+1} = xy;
            span = [0;cumsum(vecnorm(diff(xy,1,1),2,2))];
            z = from(3)+(to(3)-from(3))*span/span(end);
            candidates{end+1} = [xy z];
        end
        overZ = max(overZ,max([obstacles.zMax])+model.obstacleSafety+1);
    end

    % Sloped overflight; side corridors provide extra horizontal ramp length.
    for i = 1:length(corridors)
        points = SlopedOver(corridors{i},from(3),to(3),overZ,model.maxClimbAngle);
        candidates{end+1} = points;
    end

    path = direct;
    bestKey = [~path.isFeasible, path.distance ...
        + model.smoothWeight*path.smoothness+10000*path.totalViolation];
    for i = 1:length(candidates)
        points = candidates{i};
        % A detour outside the map is not a valid candidate.
        if any(points(:,1)<0 | points(:,1)>model.mapSize(1) ...
                | points(:,2)<0 | points(:,2)>model.mapSize(2))
            continue
        end
        result = EvaluatePath(points,model,initialDirection);
        key = [~result.isFeasible, result.distance ...
            + model.smoothWeight*result.smoothness+10000*result.totalViolation];
        if key(1)<bestKey(1) || (key(1)==bestKey(1) && key(2)<bestKey(2))
            path = result;
            bestKey = key;
        end
    end
end
path.usedDetour = size(path.points,1)>2;
path.directTerrainViolation = direct.terrainViolation;
path.directObstacleViolation = direct.obstacleViolation;
path.directAngleViolation = direct.angleViolation;
end

function points = SlopedOver(xy,startZ,endZ,overZ,maxAngle)
span = [0;cumsum(vecnorm(diff(xy,1,1),2,2))];
slope = tand(maxAngle);
% If the corridor is short, use only the height reachable at the slope limit.
peakZ = min(overZ,(startZ+endZ+slope*span(end))/2);
riseRun = (peakZ-startZ)/slope;
fallStart = span(end)-(peakZ-endZ)/slope;
s = unique([span;riseRun;fallStart]);
s = s(s>=0 & s<=span(end));
% Remove zero-length XY intervals before interpolation.
keep = [true;diff(span)>1e-10];
if span(end)<eps
    points = [xy(1,:) startZ;xy(end,:) endZ];
else
    xy = interp1(span(keep),xy(keep,:),s);
    z = min([startZ+slope*s,endZ+slope*(span(end)-s),overZ*ones(size(s))],[],2);
    z(1) = startZ;
    z(end) = endZ;
    points = [xy z];
end
end

function result = EvaluatePath(points,model,initialDirection)
% Remove repeated consecutive points before calculating flight angles.
points = points([true;vecnorm(diff(points,1,1),2,2)>1e-10],:);
if size(points,1)==1
    points = [points;points]; % A stationary leg still needs a safety check.
end
segments = diff(points,1,1);
horizontal = vecnorm(segments(:,1:2),2,2);
pitch = atan2d(segments(:,3),horizontal);
turn = zeros(max(0,size(segments,1)-1),1);
for i = 1:length(turn)
    turn(i) = TurnAngle(segments(i,:),segments(i+1,:));
end
if ~isempty(initialDirection) && ~isempty(segments)
    turn = [TurnAngle(initialDirection,segments(1,:));turn];
    pitchHistory = [atan2d(initialDirection(3),norm(initialDirection(1:2)));pitch];
else
    pitchHistory = pitch;
end
angleViolation = sum(max(0,abs(pitch)-model.maxClimbAngle)) ...
    + sum(max(0,turn-model.maxTurnAngle));
smoothness = sum((turn/model.maxTurnAngle).^2) ...
    + sum((diff(pitchHistory)/model.maxClimbAngle).^2);

terrainViolation = 0;
obstacleViolation = 0;
blockedObstacles = false(1,length(model.obstacles));
for i = 1:size(segments,1)
    t = linspace(0,1,model.safetySamples)';
    samples = points(i,:)+t.*segments(i,:);
    ground = interp2(model.X,model.Y,model.terrainZ, ...
        samples(:,1),samples(:,2),'linear');
    terrainViolation = terrainViolation ...
        + mean(max(0,model.minClearance-(samples(:,3)-ground)));
    for j = 1:length(model.obstacles)
        obs = model.obstacles(j);
        insideXY = hypot(samples(:,1)-obs.x,samples(:,2)-obs.y) ...
            <= obs.r+model.obstacleSafety;
        insideZ = samples(:,3)>=obs.zMin-model.obstacleSafety ...
            & samples(:,3)<=obs.zMax+model.obstacleSafety;
        amount = max(0,obs.zMax+model.obstacleSafety-samples(:,3));
        value = sum(amount(insideXY & insideZ));
        obstacleViolation = obstacleViolation+value;
        blockedObstacles(j) = blockedObstacles(j) || value>1e-8;
    end
end
result.points = points([true;vecnorm(segments,2,2)>1e-10],:);
result.distance = sum(vecnorm(segments,2,2));
result.terrainViolation = terrainViolation;
result.obstacleViolation = obstacleViolation;
result.angleViolation = angleViolation;
result.totalViolation = terrainViolation+obstacleViolation+angleViolation;
result.maxClimbAngle = max([0;abs(pitch)]);
result.maxTurnAngle = max([0;turn]);
result.smoothness = smoothness;
result.isFeasible = result.totalViolation<1e-8;
result.blockedObstacles = find(blockedObstacles);
end

function angle = TurnAngle(first,second)
first = first(1:2);
second = second(1:2);
angle = atan2d(abs(first(1)*second(2)-first(2)*second(1)),dot(first,second));
end
