clc
clear
close all

%% false=单图PSO，true=四算法多场景对比
runComparison = false;

%% 对比参数，仅runComparison=true时使用
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
