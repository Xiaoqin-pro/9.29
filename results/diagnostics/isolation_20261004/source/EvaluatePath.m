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
