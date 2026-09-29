function model = CreateModel(cfg)
%CREATEMODEL Create a simple 3-D UAV delivery model.
%   The model contains terrain, cylindrical buildings, orders and events.

if nargin == 0
    cfg = struct();
end
if ~isfield(cfg,'mapSize'), cfg.mapSize = [100 100]; end
if ~isfield(cfg,'nInitialOrders'), cfg.nInitialOrders = 8; end
if ~isfield(cfg,'nFutureOrders'), cfg.nFutureOrders = 4; end
if ~isfield(cfg,'seed'), cfg.seed = 20260929; end
if ~isfield(cfg,'safetySamples'), cfg.safetySamples = 30; end

rng(cfg.seed);
model.mapSize = cfg.mapSize;
model.safetySamples = cfg.safetySamples;
model.speed = 6;
model.minClearance = 5;
model.obstacleSafety = 2;
model.serviceTime = 3;

%% 3-D terrain
x = linspace(0,cfg.mapSize(1),41);
y = linspace(0,cfg.mapSize(2),41);
[model.X,model.Y] = meshgrid(x,y);
model.terrainZ = 5 + 5*sin(model.X/16).*cos(model.Y/19) ...
    + 2*cos(model.X/9 + model.Y/14);

model.cruiseHeight = max(model.terrainZ(:)) + 10;
model.depot = [10 10 model.cruiseHeight];

%% Cylindrical buildings
model.obstacles(1) = struct('x',38,'y',34,'r',8,'zMin',0,'zMax',25);
model.obstacles(2) = struct('x',66,'y',64,'r',9,'zMin',0,'zMax',30);
model.obstacles(3) = struct('x',31,'y',79,'r',7,'zMin',0,'zMax',22);

%% Orders
n = cfg.nInitialOrders + cfg.nFutureOrders;
orders = repmat(struct('id',0,'xyz',zeros(1,3),'release',0, ...
    'ready',0,'due',0,'service',model.serviceTime,'status','future'),1,n);

for i = 1:n
    xy = [15 + 70*rand,15 + 70*rand];
    while InAnyObstacle(xy,model)
        xy = [15 + 70*rand,15 + 70*rand];
    end
    orders(i).id = i;
    orders(i).xyz = [xy model.cruiseHeight];
    orders(i).service = model.serviceTime;
    orders(i).ready = 0;
    orders(i).release = 0;
    orders(i).due = 120 + 10*i + 25*rand;
    orders(i).status = 'future';
end

for i = 1:cfg.nInitialOrders
    orders(i).status = 'active';
end

for i = cfg.nInitialOrders+1:n
    orders(i).release = 35 + 20*mod(i-cfg.nInitialOrders-1,2);
    orders(i).ready = orders(i).release;
    orders(i).due = orders(i).release + 120 + 20*rand;
end

model.orders = orders;
model.nOrders = n;
model.activeIDs = 1:cfg.nInitialOrders;
model.futureIDs = cfg.nInitialOrders+1:n;

%% Dynamic events
model.events(1) = struct('time',35,'type','add','orderIDs',cfg.nInitialOrders+1);
model.events(2) = struct('time',70,'type','cancel','orderIDs',3);
model.events(3) = struct('time',85,'type','add','orderIDs',cfg.nInitialOrders+2);
end

function yes = InAnyObstacle(xy,model)
yes = false;
for i = 1:length(model.obstacles)
    obs = model.obstacles(i);
    distance = norm(xy-[obs.x obs.y]);
    if distance <= obs.r + model.obstacleSafety + 2
        yes = true;
        return
    end
end
end
