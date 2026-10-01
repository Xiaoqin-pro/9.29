function overview = PlotSolution(BestSol,model,state,filePath,mode)
%PLOTSOLUTION Plot a route snapshot or the all-order reference overview.

overview = [];
if strcmp(mode,'all')
    initialIDs = state.activeIDs;
    BestSol.Position = AllOrdersRoute(model);
    state.time = 0;
    state.position = model.depot;
    state.activeIDs = 1:model.nOrders;
    state.servedIDs = [];
    state.cancelledIDs = [];
    state.direction = [];
end

[~,detail] = Fitness(BestSol.Position,model,state);
figure('Color','w');
surf(model.X,model.Y,model.terrainZ, ...
    'EdgeColor','none','FaceAlpha',0.65,'DisplayName','Terrain');
hold on
colormap parula
axis equal
grid on
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3-D UAV delivery route');

for i = 1:length(model.obstacles)
    obs = model.obstacles(i);
    [X,Y,Z] = cylinder(obs.r,30);
    X = X + obs.x;
    Y = Y + obs.y;
    Z = obs.zMin + Z*(obs.zMax-obs.zMin);
    if i == 1
        surf(X,Y,Z,'FaceColor',[0.75 0.25 0.25], ...
            'FaceAlpha',0.55,'EdgeColor','none', ...
            'DisplayName','Cylindrical obstacle');
    else
        surf(X,Y,Z,'FaceColor',[0.75 0.25 0.25], ...
            'FaceAlpha',0.55,'EdgeColor','none', ...
            'HandleVisibility','off');
    end
end

plot3(detail.points(:,1),detail.points(:,2),detail.points(:,3), ...
    'b-o','LineWidth',2,'MarkerSize',3,'MarkerFaceColor','w', ...
    'DisplayName','UAV route');
plot3(model.depot(1),model.depot(2),model.depot(3), ...
    'ks','MarkerSize',10,'MarkerFaceColor','k','DisplayName','Depot');

for i = 1:length(state.activeIDs)
    id = state.activeIDs(i);
    p = model.orders(id).xyz;
    plot3(p(1),p(2),p(3),'ko','MarkerFaceColor','y','MarkerSize',6, ...
        'HandleVisibility','off');
    text(p(1)+1,p(2)+1,p(3)+1,sprintf('C%d',id));
end

if strcmp(mode,'all')
    initialXYZ = reshape([model.orders(initialIDs).xyz],3,[])';
    futureIDs = setdiff(1:model.nOrders,initialIDs);
    futureXYZ = reshape([model.orders(futureIDs).xyz],3,[])';
    scatter3(initialXYZ(:,1),initialXYZ(:,2),initialXYZ(:,3),45, ...
        [0.95 0.75 0.1],'filled','DisplayName','Initial orders');
    scatter3(futureXYZ(:,1),futureXYZ(:,2),futureXYZ(:,3),55, ...
        [0.1 0.7 0.3],'filled','DisplayName','Future orders (including cancelled)');
    geometryFeasible = cellfun(@(p) p.isFeasible,detail.paths);
    for k = find(~geometryFeasible)'
        points = detail.paths{k}.points;
        plot3(points(:,1),points(:,2),points(:,3),'r--', ...
            'LineWidth',2,'HandleVisibility','off');
    end
    set(findobj(gca,'DisplayName','UAV route'), ...
        'DisplayName','Nearest-neighbor reference');
    title(sprintf('All %d orders: reference overview (not executed)',model.nOrders));
    overview.route = BestSol.Position;
    overview.points = detail.points;
    overview.paths = detail.paths;
    overview.distance = detail.distance;
    overview.geometryFeasible = geometryFeasible;
    fprintf('All-order overview: %d orders, distance=%.3f, infeasible legs=%d\n', ...
        model.nOrders,detail.distance,sum(~geometryFeasible));
end

legend('Location','best');
exportgraphics(gcf,filePath,'Resolution',150);
end

function route = AllOrdersRoute(model)
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
end
