function [state,remainingRoute] = ExecuteUntilEvent(model,state,route,eventTime)
%EXECUTEUNTILEVENT Execute the committed route until a dynamic event.

remainingRoute = route;
current = state.position;
currentTime = state.time;
state.fixedIDs = [];

for k = 1:length(route)
    id = route(k);
    target = model.orders(id).xyz;
    distance = norm(target-current);
    travelTime = distance/model.speed;

    if currentTime + travelTime >= eventTime
        ratio = (eventTime-currentTime)/max(travelTime,eps);
        ratio = max(0,min(1,ratio));
        state.position = current + ratio*(target-current);
        state.time = eventTime;
        state.fixedIDs = id;
        remainingRoute = route(k:end);
        return
    end

    currentTime = currentTime + travelTime;
    currentTime = max(currentTime,model.orders(id).ready);
    currentTime = currentTime + model.orders(id).service;
    state.servedIDs = [state.servedIDs id]; %#ok<AGROW>
    state.activeIDs = state.activeIDs(state.activeIDs ~= id);
    current = target;
end

state.position = current;
state.time = currentTime;
remainingRoute = [];
end
