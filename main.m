clc
clear
close all

%% false=单图PSO，true=四算法多场景对比
runComparison = false;

%% 对比参数，仅runComparison=true时使用
runs = 5;
comparisonParticles = 12;
maxEvaluations = 240;
mapIDs = 1:3;
caseIDs = 1:6;
warmStart = true;
plotComparison = true;
comparisonSeed = 20261003;

%% 三维带时间窗配送：参数、建模、PSO、结果与绘图
root = fileparts(mfilename('fullpath'));

%% 站点、地形与飞行参数
cfg.stationFile = fullfile(root,'data','delivery_stations.csv');
cfg.threatFile = fullfile(root,'data','threat_zones.csv');
cfg.maxAltitude = 42;
cfg.depotXY = [40 50];
cfg.depotWindow = [0 240];
cfg.speed = 6;
cfg.minClearance = 4;
cfg.serviceHeight = 8;
cfg.mapSize = [100 100];
cfg.terrainType = 2;
% 1=Ridge/valley, 2=Multiple peaks, 3=Qinling
cfg.terrainFiles = {fullfile(root,'data','map_ridge.mat'), ...
    fullfile(root,'data','map_peaks.mat'), ...
    fullfile(root,'data','map_mountain.mat')};
cfg.nOrders = 20;
cfg.nControlPoints = 2;
cfg.minControlRatio = 0.05;
cfg.maxControlRatio = 0.95;
cfg.maxSideOffset = 30;
cfg.maxHeightOffset = 25;
cfg.twScale = 1.0;
cfg.seed = 20260929;
cfg.maxClimbAngle = 25;
cfg.maxTurnAngle = 120;
cfg.smoothWeight = 2;
if ~runComparison
    model = CreateModel(cfg);
    resultDir = fullfile(root,'results',model.terrainName);
    if ~exist(resultDir,'dir')
        mkdir(resultDir);
    end
    fprintf('Terrain: %s (Copernicus GLO-90)\n',model.terrainName);

    %% Initial state
    state.time = 0;
    state.position = model.depot;
    state.activeIDs = model.activeIDs;

    %% Reference route and PSO planning
    [~,referenceRoute] = sort([model.orders.due]);
    rng(cfg.seed);
    setupClock=tic;
    [referenceControl,setupInfo] = InitialControl(referenceRoute,model,state.position);
    setupSeconds=toc(setupClock);
    state.initialRoute = referenceRoute;
    state.initialControl = referenceControl;
    Particle_Number = 20;
    maxgen = 100;
    populationClock=tic;
    state.initialPopulation = MakePopulation(model,state,Particle_Number,1);
    populationSeconds=toc(populationClock);
    [referenceCost,referenceDetail] = Fitness(state.initialPopulation(1,:),model,state);
    [Best,T,info] = PSO(model,state,maxgen,Particle_Number,1);
    info.PopulationSeconds=populationSeconds;
    info.SetupSeconds=setupSeconds;
    info.SetupInfo=setupInfo;
    Best.Algorithm = 'PSO';

    %% Save and plot the static result
    Reference.Route = referenceRoute;
    Reference.Control = referenceControl;
    Reference.Cost = referenceCost;
    Reference.Detail = referenceDetail;
    save(fullfile(resultDir,'main_result.mat'), ...
        'cfg','model','state','Reference','Best','T','info');

    PlotSolution(Best,model,state, ...
        fullfile(resultDir,'delivery_route_3D.png'));

    %% 配送点和实际时间表
    xyz = reshape([model.orders.xyz],3,[])';
    stationData = [[model.orders.stationID]' xyz [model.orders.ready]' ...
        [model.orders.due]' [model.orders.service]'];
    stationTable = array2table(stationData,'VariableNames', ...
        {'ID','X','Y','Z','Ready','Due','Service'});
    writetable(stationTable,fullfile(resultDir,'delivery_stations_3D.csv'));
    schedule = array2table(Best.Detail.records,'VariableNames',Best.Detail.scheduleColumns);
    writetable(schedule,fullfile(resultDir,'delivery_schedule.csv'));
    summary = table(Best.Detail.feasible,Best.Detail.distance,Best.Detail.totalWaiting, ...
        Best.Detail.totalLate,Best.Detail.finishTime,Best.Detail.depotLate, ...
        Best.Detail.minClearance,Best.Detail.maxClimbAngle,Best.Detail.maxTurnAngle, ...
        'VariableNames',{'Feasible','Distance','Waiting','Late','ReturnTime','DepotLate', ...
        'MinClearance','MaxClimbAngle','MaxTurnAngle'});
    writetable(summary,fullfile(resultDir,'delivery_summary.csv'));

    figure('Color','w');
    plot(T,'LineWidth',1.8);
    ax = gca;
    ax.Toolbar.Visible = 'off';
    grid on
    xlabel('Fitness evaluations','fontsize',12);
    ylabel('The Function Value','fontsize',12);
    title('Static 3-D UAV PSO with shared random-key encoding');
    exportgraphics(gcf,fullfile(resultDir,'delivery_convergence.png'),'Resolution',150);

    fprintf('Reference cost:      %.3f\n',Reference.Cost);
    fprintf('Reference feasible:  %d\n',Reference.Detail.feasible);
    fprintf('Cost:                %.3f\n',Best.Cost);
    fprintf('Reference distance:  %.3f\n',Reference.Detail.distance);
    fprintf('Distance:            %.3f\n',Best.Detail.distance);
    fprintf('Late:                %.3f\n',Best.Detail.totalLate);
    fprintf('Waiting:             %.3f\n',Best.Detail.totalWaiting);
    fprintf('Feasible:            %d\n',Best.Detail.feasible);
    fprintf('Return time:         %.3f / %.3f\n',Best.Detail.finishTime,model.depotDue);
    fprintf('Minimum clearance:   %.3f\n',Best.Detail.minClearance);
    disp(schedule);
    fprintf('Max climb angle:     %.3f deg\n',Best.Detail.maxClimbAngle);
    fprintf('Max turn angle:      %.3f deg\n',Best.Detail.maxTurnAngle);
    fprintf('Smoothness:          %.3f\n',Best.Detail.totalSmoothness);
else
    Particle_Number=comparisonParticles;
    d=load(fullfile(root,'data','experiment_cases.mat'),'Cases');
    Cases=d.Cases;
    algorithms={'PSO','CSO','CLPSO','GWO'};
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    out=fullfile(root,'results','experiments',['comparison_' stamp]);
    mkdir(out);
    % 直接保存代码与输入快照，不再哈希缓存或自动复用旧结果。
    mkdir(fullfile(out,'source'));
    copyfile(fullfile(root,'*.m'),fullfile(out,'source'));
    mkdir(fullfile(out,'input'));
    copyfile(fullfile(root,'data','experiment_cases.mat'),fullfile(out,'input'));
    copyfile(fullfile(root,'data','delivery_stations.csv'),fullfile(out,'input'));
    copyfile(fullfile(root,'data','threat_zones.csv'),fullfile(out,'input'));
    copyfile(fullfile(root,'data','map_*.mat'),fullfile(out,'input'));
    manifest=struct('Status','running','Parameters',struct('Runs',runs,'Population',Particle_Number, ...
        'Evaluations',maxEvaluations,'Seed',comparisonSeed,'WarmStart',warmStart, ...
        'MapIDs',mapIDs,'CaseIDs',caseIDs),'Algorithms',{algorithms}, ...
        'MATLAB',version,'ExpectedRuns',numel(mapIDs)*numel(caseIDs)*4*runs);
    WriteManifest(out,manifest);
    records=cell(manifest.ExpectedRuns,1);
    count=0;
    for map=mapIDs
        for number=caseIDs
            Case=Cases{map,number};
            model=Case.Model;
            for repeat=1:runs
                state=Case.State;
                state.maxEvaluations=maxEvaluations;
                seed=comparisonSeed+10000*map+100*ceil(number/2)+repeat;
                populationClock=tic;
                if warmStart
                    state.initialPopulation=MakePopulation(model,state,Particle_Number,seed);
                else
                    rng(seed);
                    D=Case.N+3*(Case.N+1)*model.nControlPoints;
                    state.initialPopulation=rand(Particle_Number,D);
                end
                populationSeconds=toc(populationClock);
                for k=1:4
                    maxgen=ceil(maxEvaluations/Particle_Number);
                    [Best,T,info]=feval(algorithms{k},model,state,maxgen,Particle_Number,seed);
                    [cost,detail]=Fitness(Best.Vector,model,state);
                    assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
                    assert(abs(cost-Best.Cost)<1e-7 && detail.feasible==Best.Detail.feasible);
                    relative=fullfile('runs',model.terrainName,Case.Name,sprintf('%s_r%02d.mat',algorithms{k},repeat));
                    file=fullfile(out,relative);
                    folder=fileparts(file);
                    if ~exist(folder,'dir')
                        mkdir(folder);
                    end
                    record=struct('Terrain',model.terrainName,'Scenario',Case.Name,'Stations',Case.N, ...
                        'WindowWidth',Case.WindowWidth,'Algorithm',algorithms{k},'Run',repeat,'Seed',seed, ...
                        'Evaluations',info.Evaluations,'Cost',Best.Cost,'InitialCost',info.InitialCost, ...
                        'InitialFeasible',info.InitialFeasible,'Improved',info.Improved,'Feasible',detail.feasible, ...
                        'RouteChanged',~isequal(Best.Route,state.initialRoute), ...
                        'ControlChange',norm(Best.Control(:)-state.initialControl(:)), ...
                        'CandidateFeasibleRate',info.FeasibleEvaluations/info.Evaluations, ...
                        'Distance',detail.distance,'Waiting',detail.totalWaiting,'Late',detail.totalLate, ...
                        'ReturnTime',detail.finishTime,'DepotLate',detail.depotLate,'MinClearance',detail.minClearance, ...
                        'MaxClimbAngle',detail.maxClimbAngle,'MaxTurnAngle',detail.maxTurnAngle, ...
                        'SearchSeconds',info.Seconds,'SharedSetupSeconds',Case.SetupSeconds, ...
                        'SetupPathEvaluations',Case.SetupInfo.PathEvaluations, ...
                        'SetupRepairPSOEvaluations',Case.SetupInfo.RepairPSOEvaluations, ...
                        'PopulationSeconds',populationSeconds,'VerificationEvaluations',1,'File',relative);

                    count=count+1;
                    records{count}=record;
                    save(file,'Best','T','info','model','state','record');
                    fprintf('%s %s %s r%d: feasible=%d cost=%.3f\n', ...
                    model.terrainName,Case.Name,algorithms{k},repeat,Best.Detail.feasible,Best.Cost);
                end
            end
        end
    end
    rawRuns=struct2table(vertcat(records{:}));
    writetable(rawRuns,fullfile(out,'raw_runs.csv'));
    save(fullfile(out,'experiment_results.mat'),'rawRuns','runs','Particle_Number','maxEvaluations','mapIDs','caseIDs','warmStart','comparisonSeed');
    summary=SummarizeResults(rawRuns,out);
    if plotComparison
        PlotSolution(rawRuns,out);
    end
    manifest.Status='complete';
    manifest.CompletedRuns=count;
    WriteManifest(out,manifest);
    fprintf('COMPLETE %d runs. Results: %s\n',count,out);
end

function pop = MakePopulation(model,state,sizepop,seed)
    % 四算法共享完全相同的初始位置；搜索中不调用航段修复。
    rng(seed);
    n=length(state.activeIDs);
    K=model.nControlPoints;
    initial.Route=state.initialRoute;
    initial.Control=state.initialControl;
    keys=zeros(1,n);
    [~,index]=ismember(initial.Route,state.activeIDs);
    keys(index)=linspace(0.05,0.95,n);
    control=initial.Control;
    control(:,:,1)=(control(:,:,1)-model.minControlRatio)/(model.maxControlRatio-model.minControlRatio);
    control(:,:,2)=(control(:,:,2)+model.maxSideOffset)/(2*model.maxSideOffset);
    control(:,:,3)=(control(:,:,3)+model.maxHeightOffset)/(2*model.maxHeightOffset);
    x=max(0,min(1,[keys control(:)']));
    pop=repmat(x,sizepop,1);
    noise=zeros(n+1,K,3);
    noise(:,:,1)=0.008/(model.maxControlRatio-model.minControlRatio);
    noise(:,:,2)=0.15/(2*model.maxSideOffset);
    noise(:,:,3)=0.15/(2*model.maxHeightOffset);
    for i=2:sizepop
        pop(i,1:n)=x(1:n)+0.01*randn(1,n);
        pop(i,n+1:end)=x(n+1:end)+noise(:)'.*randn(1,numel(noise));
        if i>ceil(0.75*sizepop)
            pop(i,1:n)=rand(1,n);
            pop(i,n+1:end)=x(n+1:end)+0.03*randn(1,numel(noise));
        end
    end
    pop=max(0,min(1,pop));
end

function [control,info] = InitialControl(route,model,startPoint)
    % 用少量固定候选构造三维初始航迹，不改站点或时间窗。
    K = model.nControlPoints;
    info.PathEvaluations = 0;
    info.RepairPSOEvaluations = 0;
    control = zeros(length(route)+1,K,3);
    current = startPoint;
    offsets = [0 4 -4 8 -8 12 -12 18 -18 24 -24];
    for leg = 1:length(route)+1
        if leg<=length(route)
            target = model.orders(route(leg)).xyz;
        else
            target = model.depot;
        end
        move = target-current;
        if norm(move(1:2))<eps
            side = [1 0];
        else
            side = [-move(2) move(1)]/norm(move(1:2));
        end
        bestCost = inf;
        for shape = 1:5
            lambda = linspace(0,1,K+2);
            lambda = lambda(2:end-1);
            if shape==2
                lambda = linspace(0.15,0.85,K);
            end
            if shape==3
                lambda = linspace(0.4,0.6,K);
            end
            if shape==4
                lambda = linspace(0.2,0.7,K);
            end
            if shape==5
                lambda = linspace(0.3,0.8,K);
            end
            for d = offsets
                for bend = 1:3
                    lateral = repmat(d,1,K);
                    if bend==2
                        lateral = d*linspace(0.5,1,K);
                    end
                    if bend==3
                        lateral = d*linspace(1,0.5,K);
                    end
                    points = [current;current+lambda'.*move;target];
                    points(2:end-1,1:2) = points(2:end-1,1:2)+lateral'.*side;
                    groundMax = -inf;
                    obstacleTop = -inf;
                    for k = 1:K+1
                        t = linspace(0,1,40)';
                        samples = points(k,:)+t.*(points(k+1,:)-points(k,:));
                        xy = max(0,min(model.mapSize,samples(:,1:2)));
                        groundMax = max(groundMax,max(interp2(model.X,model.Y, ...
                            model.terrainZ,xy(:,1),xy(:,2))));
                        for j = 1:numel(model.obstacles)
                            obs = model.obstacles(j);
                            if any(hypot(samples(:,1)-obs.x,samples(:,2)-obs.y)<=obs.r+model.obstacleSafety)
                                obstacleTop = max(obstacleTop,obs.zMax+model.obstacleSafety+0.5);
                            end
                        end
                    end
                    for margin = [0 0.5 2 5]
                        cruise = max([groundMax+model.minClearance+margin,current(3),target(3),obstacleTop]);
                        h = max(0,min(model.maxHeightOffset,cruise-(current(3)+lambda*move(3))));
                        points(2:end-1,3) = current(3)+lambda'*move(3)+h';
                        [~,result] = Fitness(points,model);
                        info.PathEvaluations = info.PathEvaluations+1;
                        value = result.distance+model.smoothWeight*result.smoothness ...
                            +1e6*result.totalViolation;
                        if value<bestCost
                            bestCost = value;
                            control(leg,:,1) = lambda;
                            control(leg,:,2) = lateral;
                            control(leg,:,3) = h;
                            bestPoints = points;
                        end
                    end
                end
            end
        end
        [~,result] = Fitness(bestPoints,model);
        info.PathEvaluations = info.PathEvaluations+1;
        if ~result.isFeasible
            % 仅对尚不可行的航段做小规模连续PSO修正。
            start = reshape(control(leg,:,:),K,3);
            pop = zeros(16,K*3);
            V = zeros(size(pop));
            pbest = pop;
            scorebest = inf(16,1);
            gbest = start(:)';
            globalCost = bestCost;
            step = [0.08*ones(K,1) 3*ones(K,1) 3*ones(K,1)];
            for i = 1:16
                pop(i,:) = start(:)'+step(:)'.*randn(1,K*3);
            end
            pop(1,:) = start(:)';
            for G = 1:80
                for i = 1:16
                    x = reshape(pop(i,:),K,3);
                    x(:,1) = max(model.minControlRatio,min(model.maxControlRatio,x(:,1)));
                    x(:,2) = max(-model.maxSideOffset,min(model.maxSideOffset,x(:,2)));
                    x(:,3) = max(-model.maxHeightOffset,min(model.maxHeightOffset,x(:,3)));
                    [~,index] = sort(x(:,1));
                    x = x(index,:);
                    pop(i,:) = x(:)';
                    points = [current;current+x(:,1).*move;target];
                    points(2:end-1,1:2) = points(2:end-1,1:2)+x(:,2).*side;
                    points(2:end-1,3) = points(2:end-1,3)+x(:,3);
                    [~,result] = Fitness(points,model);
                    info.PathEvaluations = info.PathEvaluations+1;
                    info.RepairPSOEvaluations = info.RepairPSOEvaluations+1;
                    value = result.distance+model.smoothWeight*result.smoothness ...
                        +1e6*result.totalViolation;
                    if value<scorebest(i)
                        scorebest(i) = value;
                        pbest(i,:) = pop(i,:);
                    end
                    if value<globalCost
                        globalCost = value;
                        gbest = pop(i,:);
                    end
                    V(i,:) = 0.65*V(i,:)+1.5*rand(1,K*3).*(pbest(i,:)-pop(i,:)) ...
                        +1.5*rand(1,K*3).*(gbest-pop(i,:));
                    V(i,:) = max(-step(:)',min(step(:)',V(i,:)));
                    pop(i,:) = pop(i,:)+V(i,:);
                end
            end
            control(leg,:,:) = reshape(reshape(gbest,K,3),1,K,3);
        end
        current = target;
    end
end

function summary = SummarizeResults(runs,out)
    % 汇总可行解质量；原始重复数据、均值曲线和箱线图均自动生成。
    algorithms={'PSO','CSO','CLPSO','GWO'};
    maps=unique(string(runs.Terrain),'stable');
    cases=unique(string(runs.Scenario),'stable');
    records=struct([]);
    row=0;
    for map=maps'
        for scenario=cases'
            for k=1:4
                selected=string(runs.Terrain)==map & string(runs.Scenario)==scenario & string(runs.Algorithm)==algorithms{k};
                group=runs(selected,:);
                if isempty(group)
                    continue;
                end
                good=group(group.Feasible,:);
                row=row+1;
                comparable=good(good.InitialFeasible,:);
                record=struct('Terrain',char(map),'Scenario',char(scenario),'Algorithm',algorithms{k}, ...
                    'Runs',height(group),'Evaluations',group.Evaluations(1),'FeasibleRate',mean(group.Feasible), ...
                    'CandidateFeasibleRate',mean(group.CandidateFeasibleRate),'ImproveRate',mean(group.Improved), ...
                    'RouteChangeRate',mean(group.RouteChanged), ...
                    'BestCost',Minimum(good.Cost),'MeanCost',mean(good.Cost),'StdCost',std(good.Cost), ...
                    'MeanDistance',mean(good.Distance),'StdDistance',std(good.Distance), ...
                    'MeanWaiting',mean(good.Waiting),'MeanReturn',mean(good.ReturnTime), ...
                    'MeanSearchSeconds',mean(group.SearchSeconds),'StdSearchSeconds',std(group.SearchSeconds), ...
                    'SharedSetupSeconds',group.SharedSetupSeconds(1), ...
                    'MeanImprovementPercent',mean(100*(comparable.InitialCost-comparable.Cost)./comparable.InitialCost));
                if row==1
                    records=record;
                else
                    records(row)=record;
                end
            end
        end
    end
    summary=struct2table(records);
    writetable(summary,fullfile(out,'summary.csv'));
end

function value=Minimum(x)
    if isempty(x)
        value=NaN;
    else
        value=min(x);
    end
end
function WriteManifest(out,manifest)
    fid=fopen(fullfile(out,'run_manifest.json'),'w');
    fprintf(fid,'%s',jsonencode(manifest,PrettyPrint=true));
    fclose(fid);
end
