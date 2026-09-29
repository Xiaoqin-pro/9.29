function PlotSolution(BestSol,model,state,filePath)
%PLOTSOLUTION Plot a 3-D UAV route, terrain and buildings.

[~,detail] = Fitness(BestSol.Position,model,state);
figure('Color','w');
surf(model.X,model.Y,model.terrainZ,'EdgeColor','none','FaceAlpha',0.65);
hold on
colormap parula
axis equal
grid on
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3-D UAV delivery route');

for i = 1:length(model.obstacles)
    o = model.obstacles(i);
    x = [o.xMin o.xMax o.xMax o.xMin];
    y = [o.yMin o.yMin o.yMax o.yMax];
    fill3(x,y,o.zMax*ones(1,4),[0.75 0.25 0.25],'FaceAlpha',0.55);
end

plot3(detail.points(:,1),detail.points(:,2),detail.points(:,3), ...
    'b-o','LineWidth',2,'MarkerSize',3,'MarkerFaceColor','w');
plot3(model.depot(1),model.depot(2),model.depot(3), ...
    'ks','MarkerSize',10,'MarkerFaceColor','k');

for i = 1:length(state.activeIDs)
    id = state.activeIDs(i);
    p = model.orders(id).xyz;
    plot3(p(1),p(2),p(3),'ko','MarkerFaceColor','y','MarkerSize',6);
    text(p(1)+1,p(2)+1,p(3)+1,sprintf('C%d',id));
end

legend('Terrain','Building','Route','Depot','Active order','Location','best');
exportgraphics(gcf,filePath,'Resolution',150);
end
