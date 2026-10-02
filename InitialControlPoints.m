function control = InitialControlPoints(route,model,startPoint)
%INITIALCONTROLPOINTS Initialize local d/h offsets using the same Fitness.

K = model.nControlPoints;
control = zeros(length(route)+1,K,2);
current = startPoint;
for leg = 1:length(route)+1
    if leg<=length(route)
        target = model.orders(route(leg)).xyz;
    else
        target = model.depot;
    end

    % An empty route evaluates just this leg, with its endpoint as the depot.
    legModel = model;
    legModel.depot = target;
    legState.time = 0;
    legState.position = current;
    legState.direction = [];
    best = zeros(1,K,2);
    [bestCost,detail] = Fitness([],best,legModel,legState);
    bestKey = [~detail.feasible,bestCost];

    % Keep a safe direct leg. Otherwise compare a small d/h candidate set.
    if ~detail.feasible
        move = target-current;
        horizontal = norm(move(1:2));
        offsets = model.maxSideOffset*[0 1/3 -1/3 2/3 -2/3 1 -1];
        for first = offsets
            for last = offsets
                d = linspace(first,last,K);
                % A common height respects both endpoint ramp lengths.
                ramp = hypot(horizontal/(K+1),[d(1) d(end)]);
                height = min(model.maxHeightOffset,max(0, ...
                    min(tand(model.maxClimbAngle)*ramp)-abs(move(3))/(K+1)));
                for h = height*[0 0.25 0.5 0.75 1]
                    candidate = zeros(1,K,2);
                    candidate(:,:,1) = d;
                    candidate(:,:,2) = h;
                    [cost,detail] = Fitness([],candidate,legModel,legState);
                    key = [~detail.feasible,cost];
                    if key(1)<bestKey(1) || (key(1)==bestKey(1) && key(2)<bestKey(2))
                        best = candidate;
                        bestKey = key;
                    end
                end
            end
        end
    end
    control(leg,:,:) = best;
    current = target;
end
end
