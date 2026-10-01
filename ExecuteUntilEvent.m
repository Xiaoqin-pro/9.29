function [model,state,remainingRoute] = ExecuteUntilEvent(model,state,route,eventTime)
%EXECUTEUNTILEVENT Execute the committed 3-D route until an event.

current = state.position;
currentTime = state.time;
direction = state.direction;

for k = 1:length(route)
    id = route(k);
    target = model.orders(id).xyz;
    path = Plan3DPath(current,target,model,direction);

    % Fly along the same path that Fitness uses.
    for j = 1:size(path.points,1)-1
        point1 = path.points(j,:);
        point2 = path.points(j+1,:);
        distance = norm(point2-point1);
        travelTime = distance/model.speed;

        if eventTime <= currentTime + travelTime
            ratio = (eventTime-currentTime)/travelTime;
            state.position = point1 + ratio*(point2-point1);
            direction = point2-point1;
            state.direction = direction/norm(direction);
            state.time = eventTime;
            remainingRoute = route(k:end);
            return
        end

        currentTime = currentTime + travelTime;
        current = point2;
    end

    % The UAV may wait for the order or stay during service.
    wait = max(0,model.orders(id).ready-currentTime);
    if eventTime < currentTime + wait
        state.position = current;
        state.direction = [];
        state.time = eventTime;
        remainingRoute = route(k:end);
        return
    end
    currentTime = currentTime + wait;

    serviceEnd = currentTime + model.orders(id).service;
    if eventTime < serviceEnd
        state.position = current;
        state.direction = [];
        state.time = eventTime;
        remainingRoute = route(k:end);
        return
    end

    currentTime = serviceEnd;
    direction = [];
    state.servedIDs = [state.servedIDs id];
    model.orders(id).status = 'served';
    state.activeIDs = state.activeIDs(state.activeIDs ~= id);
end

% Return to the depot if all committed orders finish before the event.
path = Plan3DPath(current,model.depot,model,direction);
for j = 1:size(path.points,1)-1
    point1 = path.points(j,:);
    point2 = path.points(j+1,:);
    distance = norm(point2-point1);
    travelTime = distance/model.speed;
    if eventTime <= currentTime + travelTime
        ratio = (eventTime-currentTime)/travelTime;
        state.position = point1+ratio*(point2-point1);
        state.direction = (point2-point1)/norm(point2-point1);
        state.time = eventTime;
        remainingRoute = [];
        return
    end
    currentTime = currentTime+travelTime;
    current = point2;
end

state.position = model.depot;
state.direction = [];
state.time = eventTime;
remainingRoute = [];
end
