function [model,state,applied] = DynamicEvent(model,state,event)
%DYNAMICEVENT Apply one add or cancel order event.

applied = false;
ids = event.orderIDs;

if strcmp(event.type,'add')
    for i = 1:length(ids)
        id = ids(i);
        if ~ismember(id,state.activeIDs) && ~ismember(id,state.servedIDs)
            state.activeIDs = [state.activeIDs id];
            model.orders(id).status = 'active';
        end
    end
    applied = true;
end

if strcmp(event.type,'cancel')
    for i = 1:length(ids)
        id = ids(i);
        if ismember(id,state.activeIDs) && ~ismember(id,state.fixedIDs)
            state.activeIDs = state.activeIDs(state.activeIDs ~= id);
            state.cancelledIDs = [state.cancelledIDs id];
            model.orders(id).status = 'cancelled';
            applied = true;
        end
    end
end

model.activeIDs = state.activeIDs;
end
