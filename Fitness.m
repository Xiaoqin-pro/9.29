function [cost,detail] = Fitness(position,model,state)
    % 粒子位置 -> 排序及lambda/d/h -> XYZ路径 -> 配送时间和安全评价。
    % 两参数只评价XYZ折线，供main中的共同引导初值构造使用。
    if nargin==2
        detail=EvaluatePath(position,model);
        cost=detail.distance+model.smoothWeight*detail.smoothness+1e6*detail.totalViolation;
        return;
    end
    [route,control]=DecodePosition(position,model,state);
    % 三维距离驱动飞行时间；提前等待、逾期不可行；完整配送后返回仓库。

    current = state.position;
    currentTime = max(state.time,model.depotReady);
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
    altitudeViolation = 0;
    allPoints = current;
    paths = DecodeControlPoints(route,control,model,current);
    records = zeros(length(route),10);

    for k = 1:length(route)
        id = route(k);
        path = EvaluatePath(paths{k},model);
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
        altitudeViolation = altitudeViolation + path.altitudeViolation;
        stationID = model.orders(id).stationID;
        records(k,:) = [stationID model.orders(id).ready model.orders(id).due ...
            arrival wait serviceStart model.orders(id).service ...
            serviceStart+model.orders(id).service path.distance late];
        paths{k} = path;

        currentTime = serviceStart + model.orders(id).service;
        allPoints = [allPoints;path.points(2:end,:)];
    end

    path = EvaluatePath(paths{end},model);
    paths{end} = path;
    totalDistance = totalDistance + path.distance;
    terrainViolation = terrainViolation + path.terrainViolation;
    obstacleViolation = obstacleViolation + path.obstacleViolation;
    mapViolation = mapViolation + path.mapViolation;
    altitudeViolation = altitudeViolation + path.altitudeViolation;
    totalAngleViolation = totalAngleViolation + path.angleViolation;
    totalSmoothness = totalSmoothness + path.smoothness;
    maxClimbAngle = max(maxClimbAngle,path.maxClimbAngle);
    maxTurnAngle = max(maxTurnAngle,path.maxTurnAngle);
    allPoints = [allPoints;path.points(2:end,:)];

    finishTime = currentTime+path.distance/model.speed;
    depotLate = max(0,finishTime-model.depotDue);
    cost = totalDistance + 0.05*totalWaiting ...
        + model.smoothWeight*totalSmoothness;

    if totalLate+depotLate > 1e-8
        cost = cost + 100000 + 1000*(totalLate+depotLate);
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

    if altitudeViolation>1e-8
        cost = cost+100000+10000*altitudeViolation;
    end

    detail.route = route;
    detail.control = control;
    detail.records = records;
    detail.paths = paths;
    detail.points = allPoints;
    detail.distance = totalDistance;
    detail.totalLate = totalLate;
    detail.depotLate = depotLate;
    detail.scheduleColumns = {'ID','Ready','Due','Arrival','Wait','ServiceStart','Service','Departure','LegDistance','Late'};
    detail.totalWaiting = totalWaiting;
    detail.totalAngleViolation = totalAngleViolation;
    detail.totalSmoothness = totalSmoothness;
    detail.maxClimbAngle = maxClimbAngle;
    detail.maxTurnAngle = maxTurnAngle;
    detail.terrainViolation = terrainViolation;
    detail.obstacleViolation = obstacleViolation;
    detail.mapViolation = mapViolation;
    detail.altitudeViolation = altitudeViolation;
    detail.feasible = terrainViolation < 1e-8 ...
        && obstacleViolation < 1e-8 ...
        && totalAngleViolation < 1e-8 && totalLate < 1e-8 ...
        && mapViolation < 1e-8 && depotLate < 1e-8 && altitudeViolation < 1e-8;
    detail.finishTime = finishTime;
    detail.minClearance = min(cellfun(@(p) p.minClearance,paths));
end

function paths = DecodeControlPoints(route,control,model,startPoint)
    %DECODECONTROLPOINTS Convert local lambda/d/h controls to XYZ polylines.

    nLegs = length(route)+1;
    K = model.nControlPoints;
    paths = cell(nLegs,1);
    current = startPoint;

    for i = 1:nLegs
        if i <= length(route)
            target = model.orders(route(i)).xyz;
        else
            target = model.depot;
        end

        move = target-current;
        horizontal = norm(move(1:2));
        if horizontal < eps
            side = [1 0];
        else
            side = [-move(2) move(1)]/horizontal;
        end

        points = zeros(K+2,3);
        points(1,:) = current;
        points(end,:) = target;
        for k = 1:K
            lambda = control(i,k,1);
            d = control(i,k,2);
            h = control(i,k,3);
            base = current+lambda*move;
            points(k+1,:) = base;
            points(k+1,1:2) = base(1:2)+d*side;
            points(k+1,3) = base(3)+h;
        end
        paths{i} = points;
        current = target;
    end
end

function [route,control] = DecodePosition(position,model,state)
    n=length(state.activeIDs);
    K=model.nControlPoints;
    position=max(0,min(1,position));
    [~,index]=sort(position(1:n));
    route=state.activeIDs(index);
    control=reshape(position(n+1:end),n+1,K,3);
    control(:,:,1)=model.minControlRatio+control(:,:,1)*(model.maxControlRatio-model.minControlRatio);
    control(:,:,2)=-model.maxSideOffset+2*model.maxSideOffset*control(:,:,2);
    control(:,:,3)=-model.maxHeightOffset+2*model.maxHeightOffset*control(:,:,3);
    for leg=1:n+1
        [~,index]=sort(control(leg,:,1));
        control(leg,:,:)=control(leg,index,:);
    end
end

function result = EvaluatePath(points,model)
    % 三维航段评价：长度、爬升、转向、地形净空、圆柱碰撞。
    segments = diff(points,1,1);
    horizontal = vecnorm(segments(:,1:2),2,2);
    pitch = atan2d(segments(:,3),horizontal);
    turn = zeros(max(0,size(segments,1)-1),1);
    for i = 1:length(turn)
        a = segments(i,1:2);
        b = segments(i+1,1:2);
        turn(i) = atan2d(abs(a(1)*b(2)-a(2)*b(1)),dot(a,b));
    end
    angleViolation = sum(max(0,abs(pitch)-model.maxClimbAngle)) ...
        + sum(max(0,turn-model.maxTurnAngle));
    smoothness = sum((turn/model.maxTurnAngle).^2) ...
        + sum((diff(pitch)/model.maxClimbAngle).^2);
    terrainViolation = 0;
    obstacleViolation = 0;
    minClearance = inf;
    altitudeViolation = sum(max(0,points(:,3)-model.maxAltitude));
    mapViolation = sum(sum(max(0,-points(:,1:2)) ...
        + max(0,points(:,1:2)-model.mapSize)));
    for i = 1:size(segments,1)
        % 网格交界处分段。每格双线性地形沿直线是二次函数，求其净空极值。
        cuts = [0 1];
        if abs(segments(i,1))>eps
            cuts = [cuts (model.X(1,:)-points(i,1))/segments(i,1)];
        end
        if abs(segments(i,2))>eps
            cuts = [cuts (model.Y(:,1)'-points(i,2))/segments(i,2)];
        end
        cuts = unique(cuts(cuts>=0 & cuts<=1));
        left = cuts(1:end-1)';
        right = cuts(2:end)';
        middle = (left+right)/2;
        t = [left;middle;right];
        samples = points(i,:)+t.*segments(i,:);
        xy = max(0,min(model.mapSize,samples(:,1:2)));
        ground = interp2(model.X,model.Y,model.terrainZ,xy(:,1),xy(:,2),'linear');
        h = samples(:,3)-ground;
        count = length(left);
        h0 = h(1:count);
        hm = h(count+1:2*count);
        h1 = h(2*count+1:end);
        a = 2*(h1+h0-2*hm);
        b = h1-h0-a;
        clearance = min(h0,h1);
        index = find(a>1e-12);
        u = max(0,min(1,-b(index)./(2*a(index))));
        clearance(index) = min(clearance(index),h0(index)+b(index).*u+a(index).*u.^2);
        minClearance = min(minClearance,min(clearance));
        terrainViolation = terrainViolation+max(0,model.minClearance-min(clearance));
        % 解析求线段与扩张圆柱的交集，不依赖碰撞采样间隔。
        for j = 1:length(model.obstacles)
            obs = model.obstacles(j);
            q = points(i,1:2)-[obs.x obs.y];
            v = segments(i,1:2);
            A = dot(v,v);
            B = 2*dot(q,v);
            C = dot(q,q)-(obs.r+model.obstacleSafety)^2;
            interval = [0 1];
            if A<eps
                if C>0
                    continue;
                end
            else
                disc = B^2-4*A*C;
                % 浮点运算可能把相切判别式算成微小负数，边界接触也算碰撞。
                discTolerance = 1e-12*(B^2+abs(4*A*C)+1);
                if disc < -discTolerance
                    continue;
                end
                roots = sort((-B+[-1 1]*sqrt(max(0,disc)))/(2*A));
                interval = [max(0,roots(1)) min(1,roots(2))];
            end
            dz = segments(i,3);
            z0 = points(i,3);
            lower = obs.zMin-model.obstacleSafety;
            upper = obs.zMax+model.obstacleSafety;
            if abs(dz)<eps
                if z0<lower || z0>upper
                    continue;
                end
            else
                tz = sort(([lower upper]-z0)/dz);
                interval = [max(interval(1),tz(1)) min(interval(2),tz(2))];
            end
            if interval(1)<=interval(2)+1e-12
                obstacleViolation = obstacleViolation+1;
            end
        end
    end
    result.points = points;
    result.distance = sum(vecnorm(segments,2,2));
    result.terrainViolation = terrainViolation;
    result.obstacleViolation = obstacleViolation;
    result.angleViolation = angleViolation;
    result.mapViolation = mapViolation;
    result.altitudeViolation = altitudeViolation;
    result.totalViolation = terrainViolation+obstacleViolation+angleViolation+mapViolation+altitudeViolation;
    result.maxClimbAngle = max([0;abs(pitch)]);
    result.maxTurnAngle = max([0;turn]);
    result.smoothness = smoothness;
    result.minClearance = minClearance;
    result.isFeasible = result.totalViolation<1e-8;
end
