function model = CreateModel(cfg)
%CREATEMODEL Create the static 3-D UAV time-window model.
%   Solomon RC101 coordinates/time windows + Gaussian terrain + cylinders.

rng(cfg.seed);
model.mapSize = cfg.mapSize;
model.safetySamples = cfg.safetySamples;
model.speed = 6;
model.minClearance = 4;
model.serviceHeight = 6;
model.serviceTime = cfg.serviceTime;
model.obstacleSafety = 2;
model.maxClimbAngle = cfg.maxClimbAngle;
model.maxTurnAngle = cfg.maxTurnAngle;
model.smoothWeight = cfg.smoothWeight;
model.nControlPoints = cfg.nControlPoints;
model.maxSideOffset = cfg.maxSideOffset;
model.maxHeightOffset = cfg.maxHeightOffset;
model.twScale = cfg.twScale;

%% Gaussian terrain
x = linspace(0,cfg.mapSize(1),51);
y = linspace(0,cfg.mapSize(2),51);
[model.X,model.Y] = meshgrid(x,y);
model.terrainZ = 1 ...
    + 7*exp(-((model.X-25).^2+(model.Y-25).^2)/350) ...
    + 9*exp(-((model.X-70).^2+(model.Y-35).^2)/450) ...
    + 6*exp(-((model.X-55).^2+(model.Y-78).^2)/320) ...
    + 0.6*sin(model.X/18).*cos(model.Y/22);
model.terrainZ = max(model.terrainZ,0);

%% Read RC101 coordinates and time windows
raw = ReadRC101(cfg.dataFile);
depot = raw(raw(:,1)==0,:);
customers = sortrows(raw(raw(:,1)>0,:),1);
index = round(linspace(1,size(customers,1),cfg.nOrders));
customers = customers(index,:);

model.depotXY = depot(1,2:3);
model.depot = [model.depotXY ...
    interp2(model.X,model.Y,model.terrainZ, ...
    model.depotXY(1),model.depotXY(2))+model.serviceHeight];

%% Cylindrical buildings
obstacleData = [50 20 5 14; ...
                72 20 5 16; ...
                82 40 6 20; ...
                66 55 5 18; ...
                75 88 6 16; ...
                82 72 6 20; ...
                25 60 4 14; ...
                34 25 4 12];
for i = 1:size(obstacleData,1)
    model.obstacles(i) = MakeObstacle(obstacleData(i,:),model);
end

%% Orders
orders = repmat(struct('id',0,'xy',zeros(1,2),'xyz',zeros(1,3), ...
    'ready',0,'due',0,'service',model.serviceTime),1,cfg.nOrders);
for i = 1:cfg.nOrders
    xy = customers(i,2:3);
    ground = interp2(model.X,model.Y,model.terrainZ,xy(1),xy(2));
    center = (customers(i,5)+customers(i,6))/2;
    halfWidth = (customers(i,6)-customers(i,5))/2;
    orders(i).id = i;
    orders(i).xy = xy;
    orders(i).xyz = [xy ground+model.serviceHeight];
    orders(i).ready = max(0,center-model.twScale*halfWidth);
    orders(i).due = center+model.twScale*halfWidth;
end

model.orders = orders;
model.nOrders = cfg.nOrders;
model.activeIDs = 1:cfg.nOrders;
model.selectedCustomerIDs = customers(:,1)';
model.referenceRoute = NearestNeighborRoute(model.depotXY, ...
    reshape([orders.xy],2,[])');
end

function data = ReadRC101(filePath)
fid = fopen(filePath,'r');
lines = textscan(fid,'%s','Delimiter','\n','Whitespace','');
fclose(fid);
data = zeros(0,7);
for i = 1:length(lines{1})
    values = sscanf(lines{1}{i},'%f');
    if length(values) >= 7
        data(end+1,:) = values(1:7)';
    end
end
end

function obstacle = MakeObstacle(data,model)
ground = interp2(model.X,model.Y,model.terrainZ,data(1),data(2));
obstacle = struct('x',data(1),'y',data(2),'r',data(3), ...
    'zMin',ground,'zMax',ground+data(4));
end

function route = NearestNeighborRoute(startXY,xy)
remaining = 1:size(xy,1);
route = zeros(1,size(xy,1));
current = startXY;
for i = 1:size(xy,1)
    distance = sum((xy(remaining,:)-current).^2,2);
    [~,index] = min(distance);
    route(i) = remaining(index);
    current = xy(route(i),:);
    remaining(index) = [];
end
end
