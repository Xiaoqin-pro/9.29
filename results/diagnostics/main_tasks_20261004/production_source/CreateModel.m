function model = CreateModel(cfg)
    %CREATEMODEL Create the static 3-D UAV time-window model.
    %   Fixed delivery stations + hard time windows + public DSM terrain and no-fly threat zones.

    model.mapSize = cfg.mapSize;
    model.speed = cfg.speed;
    model.minClearance = cfg.minClearance;
    model.serviceHeight = cfg.serviceHeight;
    model.obstacleSafety = 2;
    model.maxAltitude = cfg.maxAltitude;
    model.maxClimbAngle = cfg.maxClimbAngle;
    model.maxTurnAngle = cfg.maxTurnAngle;
    model.smoothWeight = cfg.smoothWeight;
    model.nControlPoints = cfg.nControlPoints;
    model.minControlRatio = cfg.minControlRatio;
    model.maxControlRatio = cfg.maxControlRatio;
    model.maxSideOffset = cfg.maxSideOffset;
    model.minHeightOffset = cfg.minHeightOffset;
    model.maxHeightOffset = cfg.maxHeightOffset;
    model.benchmarkVersion = 'platform-20261004';

    %% Public Copernicus GLO-90 terrain (no synthetic fallback)
    names = {'ridge','peaks','mountain'};
    terrainFile = cfg.terrainFiles{cfg.terrainType};
    terrain = load(terrainFile,'terrainZ','terrainMeta');
    x = linspace(0,cfg.mapSize(1),51);
    y = linspace(0,cfg.mapSize(2),51);
    [model.X,model.Y] = meshgrid(x,y);
    model.terrainZ = terrain.terrainZ;
    model.terrainType = cfg.terrainType;
    model.terrainName = names{cfg.terrainType};
    model.terrainMeta = terrain.terrainMeta;

    %% 固定配送站点及时间窗
    stations = readmatrix(cfg.stationFile);
    stations = stations(1:cfg.nOrders,:);
    assert(numel(unique(stations(:,1)))==size(stations,1),'Station IDs must be unique.');
    assert(all(stations(:,4)>=0 & stations(:,5)>=stations(:,4) & stations(:,6)>=0));
    model.depotXY = cfg.depotXY;
    model.depot = [model.depotXY interp2(model.X,model.Y,model.terrainZ, ...
        model.depotXY(1),model.depotXY(2))+model.serviceHeight];
    model.depotReady = cfg.depotWindow(1);
    model.depotDue = cfg.depotWindow(2);
    model.stationSource = cfg.stationFile;

    %% 三维圆柱威胁区：底面贴地，半径/高度来自CSV
    threatData = readmatrix(cfg.threatFile);
    model.obstacles = repmat(struct('id',0,'x',0,'y',0,'r',0, ...
        'zMin',0,'zMax',0),size(threatData,1),1);
    for i = 1:size(threatData,1)
        model.obstacles(i).id = threatData(i,1);
        model.obstacles(i).x = threatData(i,2);
        model.obstacles(i).y = threatData(i,3);
        model.obstacles(i).r = threatData(i,4);
        % 底部取安全圆域内的最低地形，防止底面悬空后出现穿底路线。
        inside = hypot(model.X-threatData(i,2),model.Y-threatData(i,3)) ...
            <= threatData(i,4)+model.obstacleSafety;
        base = min(model.terrainZ(inside));
        model.obstacles(i).zMin = base;
        model.obstacles(i).zMax = base+threatData(i,5);
    end
    model.threatSource = cfg.threatFile;
    for i=1:numel(model.obstacles)
        obs=model.obstacles(i);
        assert(hypot(model.depot(1)-obs.x,model.depot(2)-obs.y)>obs.r+model.obstacleSafety, ...
            'Depot lies inside a threat safety footprint.');
    end

    %% 三维配送点：高程=地形高程+服务高度
    orders = repmat(struct('id',0,'stationID',0,'xy',zeros(1,2), ...
        'xyz',zeros(1,3),'ready',0,'due',0,'service',0),1,cfg.nOrders);
    for i = 1:cfg.nOrders
        xy = stations(i,2:3);
        ground = interp2(model.X,model.Y,model.terrainZ,xy(1),xy(2));
        orders(i).id = i;
        orders(i).stationID = stations(i,1);
        orders(i).xy = xy;
        orders(i).xyz = [xy ground+model.serviceHeight];
        assert(orders(i).xyz(3)<=model.maxAltitude,'Service point is above maximum flight altitude.');
        orders(i).ready = stations(i,4);
        orders(i).due = stations(i,5);
        orders(i).service = stations(i,6);
        for j = 1:numel(model.obstacles)
            obs = model.obstacles(j);
            assert(hypot(xy(1)-obs.x,xy(2)-obs.y)>obs.r+model.obstacleSafety, ...
                'Delivery station lies inside a threat safety footprint.');
        end
    end

    model.orders = orders;
    model.nOrders = cfg.nOrders;
    model.activeIDs = 1:cfg.nOrders;
    model.selectedCustomerIDs = stations(:,1)';
end
