function [model,state] = DynamicEvent(model,state,event)
%DYNAMICEVENT Apply one add or cancel order event.

ids = event.orderIDs;

if strcmp(event.type,'add')
    for i = 1:length(ids)
        id = ids(i);
        if ~ismember(id,state.activeIDs) && ~ismember(id,state.servedIDs)
            state.activeIDs = [state.activeIDs id];
            model.orders(id).status = 'active';
        end
    end
end

if strcmp(event.type,'cancel')
    for i = 1:length(ids)
        id = ids(i);
        if ismember(id,state.activeIDs)
            state.activeIDs = state.activeIDs(state.activeIDs ~= id);
            state.cancelledIDs = [state.cancelledIDs id];
            model.orders(id).status = 'cancelled';
        end
    end
end

model.activeIDs = state.activeIDs;
end
