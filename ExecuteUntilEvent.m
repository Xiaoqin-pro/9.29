function [state,remainingRoute] = ExecuteUntilEvent(model,state,route,eventTime)
%EXECUTEUNTILEVENT Execute the committed 3-D route until an event.

current = state.position;
currentTime = state.time;

for k = 1:length(route)
    id = route(k);
    target = model.orders(id).xyz;
    path = Plan3DPath(current,target,model);

    % Fly along the same path that Fitness uses.
    for j = 1:size(path.points,1)-1
        point1 = path.points(j,:);
        point2 = path.points(j+1,:);
        distance = norm(point2-point1);
        travelTime = distance/model.speed;

        if currentTime + travelTime >= eventTime
            ratio = (eventTime-currentTime)/max(travelTime,eps);
            ratio = max(0,min(1,ratio));
            state.position = point1 + ratio*(point2-point1);
            state.time = eventTime;
            remainingRoute = route(k:end);
            return
        end

        currentTime = currentTime + travelTime;
        current = point2;
    end

    % The UAV may wait for the order or stay during service.
    wait = max(0,model.orders(id).ready-currentTime);
    if currentTime + wait >= eventTime
        state.position = current;
        state.time = eventTime;
        remainingRoute = route(k:end);
        return
    end
    currentTime = currentTime + wait;

    serviceEnd = currentTime + model.orders(id).service;
    if serviceEnd >= eventTime
        state.position = current;
        state.time = eventTime;
        remainingRoute = route(k:end);
        return
    end

    currentTime = serviceEnd;
    state.servedIDs = [state.servedIDs id];
    state.activeIDs = state.activeIDs(state.activeIDs ~= id);
end

state.position = current;
state.time = currentTime;
remainingRoute = [];
end
