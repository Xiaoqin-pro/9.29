clc
clear
close all

%% 单图演示false；多场景/算法比较true
runComparison = false;
root = fileparts(mfilename('fullpath'));
algorithms = {'PSO','CSO','CLPSO','GWO'};
population = 30;
maxEvaluations = 3000;
runs = 5;
seedBase = 20271004;
mapIDs = 2;                       % 主实验；地形鲁棒性改成1:3
caseIDs = 1:6;                    % 鲁棒性固定一个代表场景，如3
plotComparison = true;
scenarioID = 1;                   % 单图默认N6-wide，不挑成功seed
scenarioNames = {'N6_wide','N6_tight','N8_wide','N8_tight','N10_wide','N10_tight'};
orderCounts = [6 6 8 8 10 10];

%% 固定应用参数：地形、威胁区和硬约束不变
cfg.threatFile = fullfile(root,'data','threat_zones.csv');
cfg.terrainFiles = {fullfile(root,'data','map_ridge.mat'), ...
    fullfile(root,'data','map_peaks.mat'),fullfile(root,'data','map_mountain.mat')};
cfg.mapSize = [100 100];
cfg.terrainType = 2;
cfg.depotXY = [40 50];
cfg.depotWindow = [0 240];
cfg.speed = 6;
cfg.serviceHeight = 8;
cfg.minClearance = 4;
cfg.maxAltitude = 42;
cfg.maxClimbAngle = 25;
cfg.maxTurnAngle = 120;
cfg.nControlPoints = 1;
cfg.minControlRatio = 0.2;
cfg.maxControlRatio = 0.8;
cfg.maxSideOffset = 15;
cfg.minHeightOffset = 0;
cfg.maxHeightOffset = 12;
cfg.smoothWeight = 2;

if ~runComparison
    cfg.stationFile = fullfile(root,'data','experiment_cases',[scenarioNames{scenarioID} '.csv']);
    cfg.nOrders = orderCounts(scenarioID);
    model = CreateModel(cfg);
    resultDir = fullfile(root,'results',model.terrainName,scenarioNames{scenarioID});
    if ~exist(resultDir,'dir')
        mkdir(resultDir);
    end
    fprintf('Terrain: %s (Copernicus GLO-90)\n',model.terrainName);

    %% Initial state
    state.time = 0;
    state.position = model.depot;
    state.activeIDs = model.activeIDs;

    %% Random initialization and PSO planning
    Particle_Number = population;
    state.maxEvaluations = maxEvaluations;
    maxgen = ceil(state.maxEvaluations/Particle_Number);
    D = model.nOrders+3*(model.nOrders+1)*model.nControlPoints;
    rng(seedBase);
    state.initialPopulation = rand(Particle_Number,D);
    [Best,T,info] = PSO(model,state,maxgen,Particle_Number,seedBase);
    Best.Algorithm = 'PSO';

    %% Save and plot the static result
    save(fullfile(resultDir,'main_result.mat'), ...
        'cfg','model','state','Best','T','info');

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
    title('Static 3-D UAV PSO with random initialization');
    exportgraphics(gcf,fullfile(resultDir,'delivery_convergence.png'),'Resolution',150);

    fprintf('Cost:                %.3f\n',Best.Cost);
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
    fprintf('Evaluations:         %d\n',info.Evaluations);
    fprintf('First feasible FE:   %.0f\n',info.FirstFeasibleEvaluation);
else
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    out=fullfile(root,'results','experiments',['platform_' stamp]);
    mkdir(out);
    mkdir(fullfile(out,'source'));copyfile(fullfile(root,'*.m'),fullfile(out,'source'));
    copyfile(fullfile(root,'data'),fullfile(out,'input'));
    manifest=struct('Status','running','Version','platform-20261004','Algorithms',{algorithms}, ...
        'Population',population,'Evaluations',maxEvaluations,'Runs',runs,'Seed',seedBase, ...
        'MapIDs',mapIDs,'CaseIDs',caseIDs,'Initialization','UniformRandom','MATLAB',version);
    WriteManifest(out,manifest);
    records=cell(numel(mapIDs)*numel(caseIDs)*runs*numel(algorithms),1);
    count=0;
    for map=mapIDs
        cfg.terrainType=map;
        for number=caseIDs
            scenario=scenarioNames{number};
            cfg.stationFile=fullfile(root,'data','experiment_cases',[scenario '.csv']);
            cfg.nOrders=orderCounts(number);
            model=CreateModel(cfg);
            for repeat=1:runs
                seed=seedBase+10000*map+100*ceil(number/2)+repeat;
                state=struct('time',0,'position',model.depot,'activeIDs',model.activeIDs, ...
                    'maxEvaluations',maxEvaluations);
                D=model.nOrders+3*(model.nOrders+1)*model.nControlPoints;
                rng(seed);state.initialPopulation=rand(population,D);
                % 循环轮换执行次序，避免总让同一算法首先承担JIT/冷启动开销。
                order=circshift(1:numel(algorithms),[0 mod(repeat-1,numel(algorithms))]);
                for k=order
                    [Best,T,info]=feval(algorithms{k},model,state,ceil(maxEvaluations/population),population,seed);
                    [cost,detail]=Fitness(Best.Vector,model,state);
                    assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
                    assert(abs(cost-Best.Cost)<1e-7 && isequal(info.InitialPopulation,state.initialPopulation));
                    relative=fullfile('runs',model.terrainName,scenario,sprintf('%s_r%02d.mat',algorithms{k},repeat));
                    file=fullfile(out,relative);folder=fileparts(file);
                    if ~exist(folder,'dir'),mkdir(folder);end
                    record=struct('Terrain',model.terrainName,'Scenario',scenario,'Stations',model.nOrders, ...
                        'Algorithm',algorithms{k},'Run',repeat,'Seed',seed,'Evaluations',info.Evaluations, ...
                        'Cost',Best.Cost,'InitialCost',info.InitialCost,'InitialFeasible',info.InitialFeasible, ...
                        'Improved',info.Improved,'Feasible',detail.feasible, ...
                        'FirstFeasibleEvaluation',info.FirstFeasibleEvaluation, ...
                        'CandidateFeasibleRate',info.FeasibleEvaluations/info.Evaluations, ...
                        'Distance',detail.distance,'Waiting',detail.totalWaiting,'Late',detail.totalLate, ...
                        'ReturnTime',detail.finishTime,'DepotLate',detail.depotLate, ...
                        'MinClearance',detail.minClearance,'MaxClimbAngle',detail.maxClimbAngle, ...
                        'MaxTurnAngle',detail.maxTurnAngle,'TerrainViolation',detail.terrainViolation, ...
                        'ObstacleViolation',detail.obstacleViolation,'AngleViolation',detail.totalAngleViolation, ...
                        'SearchSeconds',info.Seconds,'VerificationEvaluations',1,'File',relative);
                    count=count+1;records{count}=record;
                    save(file,'Best','T','info','model','state','record','cfg');
                    fprintf('%s %s %s r%d: feasible=%d distance=%.3f cost=%.3f\n', ...
                        model.terrainName,scenario,algorithms{k},repeat,detail.feasible,detail.distance,Best.Cost);
                end
            end
        end
        rawRuns=struct2table(vertcat(records{1:count}));
        writetable(rawRuns,fullfile(out,'raw_runs.csv'));
    end
    save(fullfile(out,'experiment_results.mat'),'rawRuns','cfg','population','maxEvaluations','runs','mapIDs','caseIDs','seedBase');
    summary=SummarizeResults(rawRuns,out);
    if plotComparison,PlotSolution(rawRuns,out);end
    manifest.Status='complete';manifest.CompletedRuns=count;
    WriteManifest(out,manifest);
    disp(summary);
    fprintf('COMPLETE %d runs: %s\n',count,out);
end

function summary = SummarizeResults(runs,out)
    % 汇总可行解质量；原始重复数据、均值曲线和箱线图均自动生成。
    algorithms=cellstr(unique(string(runs.Algorithm),'stable'))';
    maps=unique(string(runs.Terrain),'stable');
    cases=unique(string(runs.Scenario),'stable');
    records=struct([]);
    row=0;
    for map=maps'
        for scenario=cases'
            for k=1:numel(algorithms)
                selected=string(runs.Terrain)==map & string(runs.Scenario)==scenario & string(runs.Algorithm)==algorithms{k};
                group=runs(selected,:);
                if isempty(group)
                    continue;
                end
                good=group(group.Feasible,:);
                row=row+1;
                record=struct('Terrain',char(map),'Scenario',char(scenario),'Algorithm',algorithms{k}, ...
                    'Runs',height(group),'Evaluations',group.Evaluations(1),'FeasibleRate',mean(group.Feasible), ...
                    'CandidateFeasibleRate',mean(group.CandidateFeasibleRate),'ImproveRate',mean(group.Improved), ...
                    'BestCost',Minimum(good.Cost),'MeanCost',mean(good.Cost),'StdCost',std(good.Cost), ...
                    'MeanDistance',mean(good.Distance),'StdDistance',std(good.Distance), ...
                    'MeanWaiting',mean(good.Waiting),'MeanReturn',mean(good.ReturnTime), ...
                    'MeanSearchSeconds',mean(group.SearchSeconds),'StdSearchSeconds',std(group.SearchSeconds), ...
                    'MeanLate',mean(group.Late), ...
                    'MeanFirstFeasibleEvaluation',mean(group.FirstFeasibleEvaluation,'omitnan'));
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
