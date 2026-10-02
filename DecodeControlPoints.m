function paths = DecodeControlPoints(route,control,model,startPoint)
%DECODECONTROLPOINTS Convert local side/height offsets to XYZ polylines.

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
        base = current+k/(K+1)*move;
        points(k+1,:) = base;
        points(k+1,1:2) = base(1:2) ...
            + control(i,k,1)*side;
        points(k+1,3) = base(3)+control(i,k,2);
    end
    paths{i} = points;
    current = target;
end
end
