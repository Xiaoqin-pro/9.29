function overview = PlotAllOrders(model,initialIDs,filePath)
%PLOTALLORDERS All-order spatial overview, not a dynamic execution trace.

xy = reshape([model.orders.xy],2,[])';
remaining = 1:model.nOrders;
route = zeros(1,model.nOrders);
current = model.depot(1:2);
for k = 1:model.nOrders
    [~,index] = min(sum((xy(remaining,:)-current).^2,2));
    route(k) = remaining(index);
    current = xy(route(k),:);
    remaining(index) = [];
end

% A separate display state includes future and cancelled orders as well.
state.time = 0;
state.position = model.depot;
state.activeIDs = 1:model.nOrders;
state.servedIDs = [];
state.cancelledIDs = [];
state.direction = [];
best.Position = route;
[~,detail] = Fitness(route,model,state);
PlotSolution(best,model,state,filePath);

initialXYZ = reshape([model.orders(initialIDs).xyz],3,[])';
futureIDs = setdiff(1:model.nOrders,initialIDs);
futureXYZ = reshape([model.orders(futureIDs).xyz],3,[])';
scatter3(initialXYZ(:,1),initialXYZ(:,2),initialXYZ(:,3),45, ...
    [0.95 0.75 0.1],'filled','DisplayName','Initial orders');
scatter3(futureXYZ(:,1),futureXYZ(:,2),futureXYZ(:,3),55, ...
    [0.1 0.7 0.3],'filled','DisplayName','Future orders (including cancelled)');

% Any infeasible candidate is shown in red rather than claimed to be safe.
geometryFeasible = cellfun(@(p) p.isFeasible,detail.paths);
for k = find(~geometryFeasible)'
    points = detail.paths{k}.points;
    plot3(points(:,1),points(:,2),points(:,3),'r--', ...
        'LineWidth',2,'HandleVisibility','off');
end
set(findobj(gca,'DisplayName','UAV route'), ...
    'DisplayName','Nearest-neighbor reference');
title(sprintf('All %d orders: reference overview (not executed)',model.nOrders));
legend('Location','best');
exportgraphics(gcf,filePath,'Resolution',150);

overview.route = route;
overview.points = detail.points;
overview.paths = detail.paths;
overview.distance = detail.distance;
overview.geometryFeasible = geometryFeasible;
fprintf('All-order overview: %d orders, distance=%.3f, infeasible legs=%d\n', ...
    model.nOrders,detail.distance,sum(~geometryFeasible));
end
