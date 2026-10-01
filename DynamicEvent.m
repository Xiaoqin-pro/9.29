function [model,state] = DynamicEvent(model,state,event)
%DYNAMICEVENT Apply one add or cancel order event.

ids = event.orderIDs;

if strcmp(event.type,'add')
    for i = 1:length(ids)
        id = ids(i);
        if strcmp(model.orders(id).status,'future')
            state.activeIDs = [state.activeIDs id];
            model.orders(id).status = 'active';
        end
    end
end

if strcmp(event.type,'cancel')
    for i = 1:length(ids)
        id = ids(i);
        if strcmp(model.orders(id).status,'active')
            state.activeIDs = state.activeIDs(state.activeIDs ~= id);
            state.cancelledIDs = [state.cancelledIDs id];
            model.orders(id).status = 'cancelled';
        elseif strcmp(model.orders(id).status,'future')
            state.cancelledIDs = [state.cancelledIDs id];
            model.orders(id).status = 'cancelled';
        end
    end
end

model.activeIDs = state.activeIDs;
end
