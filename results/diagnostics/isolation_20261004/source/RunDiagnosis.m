function RunDiagnosis
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);
out=fileparts(fileparts(mfilename('fullpath')));
d=load(fullfile(out,'input','experiment_cases.mat'),'Cases');
P=30;FE=3000;repeats=5;
records=cell(30,1);count=0;
% FULL: reuse only completed MAT files, rerun nothing from partial results.
for number=1:6
    item=d.Cases{2,number};model=item.Model;
    for repeat=1:repeats
        file=fullfile(out,'runs',sprintf('full_%s_r%d.mat',item.Name,repeat));
        seed=20261003+20000+100*ceil(number/2)+repeat;
        if isfile(file)
            saved=load(file);
            Best=saved.Best;T=saved.T;info=saved.info;state=saved.state;
            assert(info.Evaluations==FE && info.Seed==seed && numel(T)==FE);
            assert(isequal(saved.model,model));
        else
            state=item.State;state.maxEvaluations=FE;
            rng(seed);state.initialPopulation=rand(P,item.N+3*(item.N+1)*model.nControlPoints);
            [Best,T,info]=PSO(model,state,ceil(FE/P),P,seed);
            save(file,'model','state','Best','T','info');
        end
        [cost,detail]=Fitness(Best.Vector,model,state);
        assert(abs(cost-Best.Cost)<1e-8 && isequal(detail,Best.Detail));
        record=ResultRow('Full',item.Name,item.N,item.WindowWidth,repeat,seed,Best,info);
        count=count+1;records{count}=record;
        raw=struct2table(vertcat(records{1:count}));writetable(raw,fullfile(out,'full_raw.csv'));
        fprintf('FULL %s r%d feasible=%d geometry=%d time=%d late=%.3f obstacle=%d\n', ...
            item.Name,repeat,record.Feasible,record.GeometryFeasible,record.TimeFeasible,record.Late,record.ObstacleViolation);
    end
end
fullResults=raw;
% ROUTE-ONLY: all six cases, only N keys, direct 3-D travel and same time penalties.
records=cell(30,1);count=0;
for number=1:6
    item=d.Cases{2,number};model=item.Model;
    for repeat=1:repeats
        seed=20261003+20000+100*ceil(number/2)+repeat;
        state=item.State;state.maxEvaluations=FE;
        rng(seed);state.initialPopulation=rand(P,item.N);
        [Best,T,info]=DiagnosticPSO(model,state,ceil(FE/P),P,seed,'RouteOnly',[]);
        [cost,detail]=EvaluateDiagnostic(Best.Vector,model,state,'RouteOnly',[]);
        assert(abs(cost-Best.Cost)<1e-8 && isequal(detail,Best.Detail));
        record=ResultRow('RouteOnly',item.Name,item.N,item.WindowWidth,repeat,seed,Best,info);
        file=fullfile(out,'runs',sprintf('route_%s_r%d.mat',item.Name,repeat));
        save(file,'record','model','state','Best','T','info');
        count=count+1;records{count}=record;
        raw=struct2table(vertcat(records{1:count}));writetable(raw,fullfile(out,'route_only.csv'));
        fprintf('ROUTE %s r%d feasible=%d late=%.3f return=%.3f changed=%d/%d\n', ...
            item.Name,repeat,record.Feasible,record.Late,record.ReturnTime,info.RouteChanges,info.RouteTransitions);
    end
end
routeResults=raw;
% CONTROL-ONLY: archive supplies route ONLY. All controls start from fresh rand.
item=d.Cases{2,6};originalModel=item.Model;
witness=load(fullfile(out,'input','archived_witness.mat'),'Best');
fixedRoute=witness.Best.Route;
n=item.N;keys=zeros(1,n);[~,index]=ismember(fixedRoute,item.State.activeIDs);
keys(index)=linspace(0.05,0.95,n);
[witnessCost,witnessDetail]=Fitness([keys witness.Best.Vector(n+1:end)],originalModel,item.State);
assert(witnessDetail.feasible);
witnessCheck=struct('Cost',witnessCost,'Feasible',witnessDetail.feasible,'Distance',witnessDetail.distance,'Route',fixedRoute);
model=originalModel;
for id=1:n,model.orders(id).ready=0;model.orders(id).due=1e9;end
model.depotReady=0;model.depotDue=1e9;
records=cell(repeats,1);
for repeat=1:repeats
    seed=20261003+20000+300+repeat;
    state=item.State;state.maxEvaluations=FE;
    rng(seed);state.initialPopulation=rand(P,3*(n+1)*model.nControlPoints);
    [Best,T,info]=DiagnosticPSO(model,state,ceil(FE/P),P,seed,'ControlOnly',fixedRoute);
    [cost,detail]=EvaluateDiagnostic(Best.Vector,model,state,'ControlOnly',fixedRoute);
    assert(abs(cost-Best.Cost)<1e-8 && isequal(detail,Best.Detail));
    assert(isequal(Best.Route,fixedRoute) && detail.totalLate==0 && detail.depotLate==0 && detail.totalWaiting==0);
    record=ResultRow('ControlOnly','N20_geometry',n,NaN,repeat,seed,Best,info);
    file=fullfile(out,'runs',sprintf('control_r%d.mat',repeat));
    save(file,'record','model','originalModel','fixedRoute','state','Best','T','info');
    records{repeat}=record;raw=struct2table(vertcat(records{1:repeat}));
    writetable(raw,fullfile(out,'control_only.csv'));
    fprintf('CONTROL r%d geometry=%d terrain=%.3f obstacle=%d angle=%.3f distance=%.3f\n', ...
        repeat,record.GeometryFeasible,record.TerrainViolation,record.ObstacleViolation,record.AngleViolation,record.Distance);
end
controlResults=raw;
allRuns=[fullResults;routeResults;controlResults];
scenarios=unique(string(allRuns.Scenario),'stable');modes={'Full','RouteOnly','ControlOnly'};
rows=cell(13,1);count=0;
for k=1:numel(modes)
    for scenario=scenarios'
        group=allRuns(strcmp(allRuns.Mode,modes{k})&string(allRuns.Scenario)==scenario,:);
        if isempty(group),continue;end
        count=count+1;
        rows{count}=struct('Mode',modes{k},'Scenario',char(scenario),'N',group.N(1),'Runs',height(group), ...
            'FeasibleCount',sum(group.Feasible),'FeasibleRate',mean(group.Feasible), ...
            'GeometryRate',mean(group.GeometryFeasible),'TimeRate',mean(group.TimeFeasible), ...
            'MeanLate',mean(group.Late),'MeanDepotLate',mean(group.DepotLate), ...
            'MeanTerrainViolation',mean(group.TerrainViolation),'MeanObstacleViolation',mean(group.ObstacleViolation), ...
            'MeanAngleViolation',mean(group.AngleViolation),'MeanDistance',mean(group.Distance), ...
            'MeanRouteChangeRate',mean(group.RouteChangeRate,'omitnan'),'MeanSearchSeconds',mean(group.Seconds));
    end
end
summary=struct2table(vertcat(rows{1:count}));writetable(summary,fullfile(out,'summary.csv'));
save(fullfile(out,'diagnosis_results.mat'),'allRuns','summary','fixedRoute','witnessCheck','P','FE','repeats');
disp(summary);
fprintf('COMPLETE full30 + route30 + control5 diagnostics.\n');
end

function row=ResultRow(mode,scenario,n,width,repeat,seed,Best,info)
d=Best.Detail;
geom=d.terrainViolation<1e-8&&d.obstacleViolation<1e-8&&d.totalAngleViolation<1e-8 ...
    &&d.mapViolation<1e-8&&d.altitudeViolation<1e-8;
routeRate=NaN;
if isfield(info,'RouteChanges'),routeRate=info.RouteChanges/info.RouteTransitions;end
row=struct('Mode',mode,'Scenario',scenario,'N',n,'Width',width,'Run',repeat,'Seed',seed, ...
    'Evaluations',info.Evaluations,'Feasible',d.feasible,'GeometryFeasible',geom, ...
    'TimeFeasible',d.totalLate<1e-8&&d.depotLate<1e-8,'Cost',Best.Cost,'Distance',d.distance, ...
    'Late',d.totalLate,'DepotLate',d.depotLate,'TerrainViolation',d.terrainViolation, ...
    'ObstacleViolation',d.obstacleViolation,'AngleViolation',d.totalAngleViolation, ...
    'MapViolation',d.mapViolation,'AltitudeViolation',d.altitudeViolation,'ReturnTime',d.finishTime, ...
    'FirstFeasibleEvaluation',info.FirstFeasibleEvaluation,'RouteChangeRate',routeRate,'Seconds',info.Seconds);
end

function [cost,detail]=EvaluateDiagnostic(position,model,state,mode,fixedRoute)
if strcmp(mode,'Full')
    [cost,detail]=Fitness(position,model,state);
elseif strcmp(mode,'ControlOnly')
    n=length(state.activeIDs);keys=zeros(1,n);
    [~,index]=ismember(fixedRoute,state.activeIDs);keys(index)=linspace(0.05,0.95,n);
    [cost,detail]=Fitness([keys position],model,state);
else
    [~,index]=sort(max(0,min(1,position)));route=state.activeIDs(index);
    now=max(state.time,model.depotReady);current=state.position;
    distance=0;late=0;waiting=0;records=zeros(length(route),10);
    for k=1:length(route)
        id=route(k);o=model.orders(id);leg=norm(o.xyz-current);
        arrival=now+leg/model.speed;wait=max(0,o.ready-arrival);begin=arrival+wait;
        amount=max(0,begin-o.due);now=begin+o.service;
        records(k,:)=[o.stationID o.ready o.due arrival wait begin o.service now leg amount];
        distance=distance+leg;late=late+amount;waiting=waiting+wait;current=o.xyz;
    end
    home=norm(model.depot-current);distance=distance+home;finish=now+home/model.speed;
    depotLate=max(0,finish-model.depotDue);cost=distance+0.05*waiting;
    if late+depotLate>1e-8,cost=cost+100000+1000*(late+depotLate);end
    detail=struct('route',route,'distance',distance,'totalLate',late,'depotLate',depotLate, ...
        'totalWaiting',waiting,'finishTime',finish,'records',records,'terrainViolation',0, ...
        'obstacleViolation',0,'totalAngleViolation',0,'mapViolation',0,'altitudeViolation',0, ...
        'feasible',late<1e-8&&depotLate<1e-8);
end
end

function [Best,T,info] = DiagnosticPSO(model,state,maxgen,Particle_Number,seed,mode,fixedRoute)
    % teacher风格：pop/V/pbest/gbest数组、直接循环、独立评价函数。
    clockStart=tic;
    sizepop=Particle_Number;
    c1=1.5;
    c2=1.5;
    Vmax=0.15;
    %% 初始化：直接使用main传入的共同种群
    pop=state.initialPopulation;
    n=length(state.activeIDs);
    if strcmp(mode,'ControlOnly'),n=0;end
    D=size(pop,2);
    rng(seed);
    V=0.01*(2*rand(sizepop,D)-1);
    V(:,1:n)=3*V(:,1:n);
    budget=sizepop*(maxgen+1);
    if isfield(state,'maxEvaluations')
        budget=state.maxEvaluations;
    end
    assert(sizepop>=4 && budget>=sizepop,'Use at least 4 particles and a budget covering initialization.');
    fitness=zeros(sizepop,1);
    feasible=false(sizepop,1);
    T=nan(budget,1);
    Best.Cost=inf;
    Best.Detail.feasible=false;
    info.FirstFeasibleEvaluation=NaN;
    previousRoute=zeros(sizepop,length(state.activeIDs));
    for i=1:sizepop
        [fitness(i),detail]=EvaluateDiagnostic(pop(i,:),model,state,mode,fixedRoute);
        feasible(i)=detail.feasible;
        previousRoute(i,:)=detail.route;
        if feasible(i) && isnan(info.FirstFeasibleEvaluation)
            info.FirstFeasibleEvaluation=i;
        end
        if (feasible(i)&&~Best.Detail.feasible) || (feasible(i)==Best.Detail.feasible&&fitness(i)<Best.Cost)
            Best.Vector=pop(i,:);
            Best.Route=detail.route;
            if isfield(detail,'control'),Best.Control=detail.control;end
            Best.Cost=fitness(i);
            Best.Detail=detail;
        end
        T(i)=Best.Cost;
    end
    info.Evaluations=sizepop;
    info.Budget=budget;
    info.FeasibleEvaluations=sum(feasible);
    info.InitialCost=Best.Cost;
    info.InitialFeasible=Best.Detail.feasible;
    info.InitialPopulation=pop;
    info.Seed=seed;
    info.Iterations=0;
    info.RouteChanges=0;info.RouteTransitions=0;


    %% 更新
    pbest=pop;
    fitnesspbest=fitness;
    feasiblepbest=feasible;
    gbest=Best.Vector;
    while info.Evaluations<info.Budget
        info.Iterations=info.Iterations+1;
        w=0.9-0.5*(info.Evaluations-sizepop)/(info.Budget-sizepop);
        for i=1:sizepop
            if info.Evaluations>=info.Budget
                break;
            end
            V(i,:)=w*V(i,:)+c1*rand(1,size(pop,2)).*(pbest(i,:)-pop(i,:)) ...
                +c2*rand(1,size(pop,2)).*(gbest-pop(i,:));
            V(i,:)=max(-Vmax,min(Vmax,V(i,:)));
            pop(i,:)=max(0,min(1,pop(i,:)+V(i,:)));
            [fitness(i),detail]=EvaluateDiagnostic(pop(i,:),model,state,mode,fixedRoute);
            feasible(i)=detail.feasible;
            info.RouteTransitions=info.RouteTransitions+1;
            info.RouteChanges=info.RouteChanges+~isequal(previousRoute(i,:),detail.route);
            previousRoute(i,:)=detail.route;
            info.Evaluations=info.Evaluations+1;
            if feasible(i) && isnan(info.FirstFeasibleEvaluation)
                info.FirstFeasibleEvaluation=info.Evaluations;
            end
            info.FeasibleEvaluations=info.FeasibleEvaluations+feasible(i);
            if (feasible(i)&&~feasiblepbest(i)) || (feasible(i)==feasiblepbest(i)&&fitness(i)<fitnesspbest(i))
                pbest(i,:)=pop(i,:);
                fitnesspbest(i)=fitness(i);
                feasiblepbest(i)=feasible(i);
            end
            if (feasible(i)&&~Best.Detail.feasible) || (feasible(i)==Best.Detail.feasible&&fitness(i)<Best.Cost)
                Best.Vector=pop(i,:);
                Best.Route=detail.route;
                if isfield(detail,'control'),Best.Control=detail.control;end
                Best.Cost=fitness(i);
                Best.Detail=detail;
                gbest=pop(i,:);
            end
            T(info.Evaluations)=Best.Cost;
        end
    end
    info.Algorithm=['PSO / ' mode];
    info.Seconds=toc(clockStart);
    info.Improved=Best.Detail.feasible && Best.Cost<info.InitialCost-1e-8;
    T=T(1:info.Evaluations);
end
