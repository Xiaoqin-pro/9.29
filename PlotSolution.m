function PlotSolution(BestSol,model,state,filePath)
%PLOTSOLUTION Plot the terrain, cylindrical buildings and UAV route.

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
        displayName = 'Cylindrical obstacle';
    else
        displayName = '';
    end
    surf(X,Y,Z,'FaceColor',[0.75 0.25 0.25], ...
        'FaceAlpha',0.55,'EdgeColor','none', ...
        'DisplayName',displayName);
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

legend('Location','best');
exportgraphics(gcf,filePath,'Resolution',150);
end
