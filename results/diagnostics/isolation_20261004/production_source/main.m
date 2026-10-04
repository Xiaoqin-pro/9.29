clc
clear
close all

%% 运行入口：优先时间窗校准，否则单图或四算法对比
runCalibration = true;
runComparison = false;
windowWidths = [24 30 36 45 60];

%% 校准/对比参数：同种群、同预算、同配对seed
runs = 5;
comparisonParticles = 30;
maxEvaluations = 3000;
mapIDs = 1:3;
caseIDs = 1:6;
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
cfg.maxClimbAngle = 25;
cfg.maxTurnAngle = 120;
cfg.smoothWeight = 2;
if runCalibration
    %% peaks + N20：只改due，其他输入与算法完全不变
    d=load(fullfile(root,'data','experiment_cases.mat'),'Cases');
    base=d.Cases{2,6};
    Particle_Number=comparisonParticles;
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    out=fullfile(root,'results','calibration',['windows_' stamp]);
    mkdir(out);
    mkdir(fullfile(out,'source'));
    copyfile(fullfile(root,'*.m'),fullfile(out,'source'));
    mkdir(fullfile(out,'input'));
    copyfile(fullfile(root,'data','experiment_cases.mat'),fullfile(out,'input'));
    copyfile(fullfile(root,'data','experiment_cases','N20_tight.csv'),fullfile(out,'input'));
    copyfile(fullfile(root,'data','map_peaks.mat'),fullfile(out,'input'));
    copyfile(fullfile(root,'data','threat_zones.csv'),fullfile(out,'input'));
    seeds=comparisonSeed+20000+300+(1:runs);
    manifest=struct('Status','running','Terrain','peaks','Stations',20, ...
        'Algorithm','PSO','Widths',windowWidths,'Seeds',seeds, ...
        'Population',Particle_Number,'Evaluations',maxEvaluations,'MATLAB',version, ...
        'Initialization','UniformRandom','ExpectedRuns',numel(windowWidths)*runs);
    WriteManifest(out,manifest);
    records=cell(numel(windowWidths)*runs,1);
    count=0;
    for width=windowWidths
        model=base.Model;
        for id=1:model.nOrders
            model.orders(id).due=model.orders(id).ready+width;
        end
        folder=fullfile(out,sprintf('W%d',width));
        mkdir(folder);
        for repeat=1:runs
            seed=seeds(repeat);
            state=base.State;
            state.maxEvaluations=maxEvaluations;
            D=model.nOrders+3*(model.nOrders+1)*model.nControlPoints;
            rng(seed);
            state.initialPopulation=rand(Particle_Number,D);
            maxgen=ceil(maxEvaluations/Particle_Number);
            [Best,T,info]=PSO(model,state,maxgen,Particle_Number,seed);
            [cost,detail]=Fitness(Best.Vector,model,state);
            assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations);
            assert(abs(cost-Best.Cost)<1e-7 && detail.feasible==Best.Detail.feasible);
            timeFeasible=detail.totalLate<1e-8 && detail.depotLate<1e-8;
            geometryFeasible=detail.terrainViolation<1e-8 && detail.obstacleViolation<1e-8 ...
                && detail.totalAngleViolation<1e-8 && detail.mapViolation<1e-8 ...
                && detail.altitudeViolation<1e-8;
            relative=fullfile(sprintf('W%d',width),sprintf('seed_%d.mat',seed));
            record=struct('Width',width,'Run',repeat,'Seed',seed, ...
                'Evaluations',info.Evaluations,'Feasible',detail.feasible, ...
                'TimeFeasible',timeFeasible,'GeometryFeasible',geometryFeasible, ...
                'Cost',Best.Cost,'Distance',detail.distance,'Late',detail.totalLate, ...
                'DepotLate',detail.depotLate,'ReturnTime',detail.finishTime, ...
                'TerrainViolation',detail.terrainViolation,'ObstacleViolation',detail.obstacleViolation, ...
                'AngleViolation',detail.totalAngleViolation,'MapViolation',detail.mapViolation, ...
                'AltitudeViolation',detail.altitudeViolation,'MinClearance',detail.minClearance, ...
                'FirstFeasibleEvaluation',info.FirstFeasibleEvaluation,'Seconds',info.Seconds,'File',relative);
            count=count+1;
            records{count}=record;
            save(fullfile(out,relative),'model','state','Best','T','info','record');
            fprintf('W%d seed%d: feasible=%d time=%d geometry=%d late=%.3f terrain=%.3f angle=%.3f\n', ...
                width,seed,detail.feasible,timeFeasible,geometryFeasible, ...
                detail.totalLate,detail.terrainViolation,detail.totalAngleViolation);
        end
        rawRuns=struct2table(vertcat(records{1:count}));
        writetable(rawRuns,fullfile(out,'raw_runs.csv'));
    end
    rows=cell(numel(windowWidths),1);
    for i=1:numel(windowWidths)
        group=rawRuns(rawRuns.Width==windowWidths(i),:);
        good=group(group.Feasible,:);
        rows{i}=struct('Width',windowWidths(i),'Runs',height(group), ...
            'FeasibleCount',sum(group.Feasible),'FeasibleRate',mean(group.Feasible), ...
            'TimeFeasibleRate',mean(group.TimeFeasible),'GeometryFeasibleRate',mean(group.GeometryFeasible), ...
            'MeanLate',mean(group.Late),'MeanDepotLate',mean(group.DepotLate), ...
            'MeanTerrainViolation',mean(group.TerrainViolation),'MeanObstacleViolation',mean(group.ObstacleViolation), ...
            'MeanAngleViolation',mean(group.AngleViolation),'MeanMapViolation',mean(group.MapViolation), ...
            'MeanAltitudeViolation',mean(group.AltitudeViolation),'MeanReturnTime',mean(group.ReturnTime), ...
            'MeanFeasibleDistance',mean(good.Distance),'MeanCost',mean(good.Cost), ...
            'MeanFirstFeasibleEvaluation',mean(group.FirstFeasibleEvaluation,'omitnan'));
    end
    summary=struct2table(vertcat(rows{:}));
    writetable(summary,fullfile(out,'summary.csv'));
    save(fullfile(out,'calibration_results.mat'),'base','rawRuns','summary','windowWidths','seeds');
    disp(summary);
    manifest.Status='complete';
    manifest.CompletedRuns=count;
    WriteManifest(out,manifest);
    PlotSolution(rawRuns,out);
    fprintf('CALIBRATION complete; frozen CSV/MAT not overwritten: %s\n',out);
elseif ~runComparison
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

    %% Random initialization and PSO planning
    Particle_Number = 30;
    state.maxEvaluations = 3000;
    maxgen = ceil(state.maxEvaluations/Particle_Number);
    D = model.nOrders+3*(model.nOrders+1)*model.nControlPoints;
    rng(1);
    state.initialPopulation = rand(Particle_Number,D);
    [Best,T,info] = PSO(model,state,maxgen,Particle_Number,1);
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
        'Evaluations',maxEvaluations,'Seed',comparisonSeed,'Initialization','UniformRandom', ...
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
                D=Case.N+3*(Case.N+1)*model.nControlPoints;
                rng(seed);
                state.initialPopulation=rand(Particle_Number,D);
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
                        'FirstFeasibleEvaluation',info.FirstFeasibleEvaluation, ...
                        'CandidateFeasibleRate',info.FeasibleEvaluations/info.Evaluations, ...
                        'Distance',detail.distance,'Waiting',detail.totalWaiting,'Late',detail.totalLate, ...
                        'ReturnTime',detail.finishTime,'DepotLate',detail.depotLate,'MinClearance',detail.minClearance, ...
                        'MaxClimbAngle',detail.maxClimbAngle,'MaxTurnAngle',detail.maxTurnAngle, ...
                        'SearchSeconds',info.Seconds,'VerificationEvaluations',1,'File',relative);

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
    save(fullfile(out,'experiment_results.mat'),'rawRuns','Particle_Number','maxEvaluations','mapIDs','caseIDs','comparisonSeed');
    summary=SummarizeResults(rawRuns,out);
    if plotComparison
        PlotSolution(rawRuns,out);
    end
    manifest.Status='complete';
    manifest.CompletedRuns=count;
    WriteManifest(out,manifest);
    fprintf('COMPLETE %d runs. Results: %s\n',count,out);
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
