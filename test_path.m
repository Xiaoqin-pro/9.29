clc
clear
close all

%% Independent Plan3DPath tests
model.mapSize = [100 100];
model.safetySamples = 40;
model.speed = 6;
model.minClearance = 5;
model.obstacleSafety = 2;
model.X = repmat(linspace(0,100,41),41,1);
model.Y = repmat(linspace(0,100,41)',1,41);
model.terrainZ = zeros(41,41);

z = 20;

%% Case 1: no obstacle
a = [5 5 z];
b = [15 15 z];
model.obstacles = struct('x',80,'y',80,'r',5,'zMin',0,'zMax',10);
PrintPath('Case 1 direct',Plan3DPath(a,b,model));

%% Case 2: one cylinder blocks the direct route
a = [20 34 z];
b = [55 34 z];
model.obstacles = struct('x',38,'y',34,'r',8,'zMin',0,'zMax',25);
PrintPath('Case 2 left/right',Plan3DPath(a,b,model));

%% Case 3: side routes are blocked, so the over route is selected
a = [15 50 z];
b = [85 50 z];
model.obstacles(1) = struct('x',50,'y',50,'r',12,'zMin',0,'zMax',45);
model.obstacles(2) = struct('x',50,'y',68,'r',12,'zMin',0,'zMax',25);
model.obstacles(3) = struct('x',50,'y',32,'r',12,'zMin',0,'zMax',25);
PrintPath('Case 3 over',Plan3DPath(a,b,model));

%% Case 4: two cylinders near one route
model.obstacles(1) = struct('x',35,'y',50,'r',8,'zMin',0,'zMax',25);
model.obstacles(2) = struct('x',65,'y',50,'r',8,'zMin',0,'zMax',25);
PrintPath('Case 4 two cylinders',Plan3DPath(a,b,model));

%% Case 5: high terrain
[x,y] = meshgrid(linspace(0,100,41),linspace(0,100,41));
model.X = x;
model.Y = y;
model.terrainZ = 18*exp(-((x-50).^2+(y-50).^2)/300);
model.obstacles = struct('x',80,'y',80,'r',5,'zMin',0,'zMax',10);
a = [10 50 8];
b = [90 50 8];
PrintPath('Case 5 high terrain',Plan3DPath(a,b,model));

function PrintPath(name,path)
fprintf('%s: points=%d distance=%.3f feasible=%d terrain=%.3f obstacle=%.3f\n', ...
    name,size(path.points,1),path.distance,path.isFeasible, ...
    path.terrainViolation,path.obstacleViolation);
disp(path.points);
end
