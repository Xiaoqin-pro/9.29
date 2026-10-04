function VerifyIsolation
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));addpath(root);out=fileparts(fileparts(mfilename('fullpath')));addpath(out);
d=load(fullfile(out,'input','experiment_cases.mat'));item=d.Cases{2,1};model=item.Model;state=item.State;
P=8;FE=113;seed=456;state.maxEvaluations=FE;
rng(seed);state.initialPopulation=rand(P,item.N+3*(item.N+1)*model.nControlPoints);
[Best,T,info]=PSO(model,state,20,P,seed);
profile clear;profile on;
[Test,S,other]=DiagnosticPSO(model,state,20,P,seed,'Full',[]);
profile off;p=profile('info');calls=p.FunctionTable(strcmp({p.FunctionTable.FunctionName},'Fitness'));
assert(numel(calls)==1&&calls.NumCalls==FE);
assert(isequal(Best,Test)&&isequal(T,S)&&info.Evaluations==other.Evaluations);
fprintf('PASS external PSO exactly reproduces production Full best/history; objective calls FE113.\n');
% Hand-verifiable RouteOnly: 3+4+5, wait7, service3, return22.
[model.X,model.Y]=meshgrid(linspace(0,20,51));model.terrainZ=zeros(51);model.mapSize=[20 20];
model.speed=1;model.minClearance=1;model.obstacleSafety=0;model.maxAltitude=15;
model.maxClimbAngle=25;model.maxTurnAngle=120;model.smoothWeight=2;
model.nControlPoints=2;model.minControlRatio=0.05;model.maxControlRatio=0.95;
model.maxSideOffset=4;model.maxHeightOffset=4;model.depot=[0 0 4];model.depotReady=0;model.depotDue=30;
model.obstacles=struct('x',{},'y',{},'r',{},'zMin',{},'zMax',{});
model.orders=struct('stationID',{1,2},'xyz',{[3 0 4],[3 4 4]},'ready',{10,0},'due',{12,20},'service',{2,1});
state=struct('time',0,'position',model.depot,'activeIDs',[1 2]);
[c,v]=EvaluateDiagnostic([.2 .8],model,state,'RouteOnly',[]);
assert(v.feasible&&abs(c-12.35)<1e-10&&abs(v.distance-12)<1e-10&&v.totalWaiting==7&&v.finishTime==22);
[cc,vv]=EvaluateDiagnostic([.21 .79],model,state,'RouteOnly',[]);
assert(c==cc&&isequal(v,vv));
m=model;m.orders(1).due=9;[c,v]=EvaluateDiagnostic([.8 .2],m,state,'RouteOnly',[]);assert(~v.feasible&&v.totalLate==1);
rng(seed);state.initialPopulation=rand(P,2);state.maxEvaluations=FE;
profile clear;profile on;
[Best,T,info]=DiagnosticPSO(model,state,20,P,seed,'RouteOnly',[]);
profile off;p=profile('info');calls=p.FunctionTable(strcmp({p.FunctionTable.FunctionName},'EvaluateDiagnostic'));
assert(numel(calls)==1&&calls.NumCalls==FE);
[Again,S]=DiagnosticPSO(model,state,20,P,seed,'RouteOnly',[]);assert(isequal(Best,Again)&&isequal(T,S));
fprintf('PASS RouteOnly exact hand case, key plateau, FE113 and replay.\n');
% Fixed reverse route must really remain fixed; no controls from witness needed.
for i=1:2,model.orders(i).ready=0;model.orders(i).due=1e9;end;model.depotDue=1e9;
control=.5*ones(3,2,3);control(:,:,1)=repmat(([1/3 2/3]-.05)/.9,3,1);
[~,v]=EvaluateDiagnostic(control(:)',model,state,'ControlOnly',[2 1]);
assert(isequal(v.route,[2 1])&&v.totalLate==0&&v.depotLate==0&&v.totalWaiting==0&&abs(v.distance-12)<1e-10);
rng(seed);state.initialPopulation=rand(P,18);
profile clear;profile on;
[Best,T,info]=DiagnosticPSO(model,state,20,P,seed,'ControlOnly',[2 1]);
profile off;p=profile('info');calls=p.FunctionTable(strcmp({p.FunctionTable.FunctionName},'Fitness'));
assert(numel(calls)==1&&calls.NumCalls==FE);
assert(isequal(Best.Route,[2 1]));[Again,S]=DiagnosticPSO(model,state,20,P,seed,'ControlOnly',[2 1]);
assert(isequal(Best,Again)&&isequal(T,S));
fprintf('PASS ControlOnly fixed order, FE113 and replay.\n');
% Exact collision-count plateau: same length while gradually reducing penetration.
m=model;m.obstacles=struct('x',5,'y',0,'r',2,'zMin',2,'zMax',8);offsets=[0 .5 1 1.5 1.9 2 2.1];rows=zeros(7,5);
for i=1:7
 points=[0 offsets(i) 4;10 offsets(i) 4];p=EvaluatePath(points,m);
 cost=p.distance+m.smoothWeight*p.smoothness;
 if p.obstacleViolation>1e-8,cost=cost+100000+10000*p.obstacleViolation;end
 rows(i,:)=[offsets(i) max(0,2-offsets(i)) p.obstacleViolation cost p.distance];
end
assert(all(rows(1:6,3)==1)&&all(rows(1:6,4)==110010)&&rows(7,3)==0&&rows(7,4)==10);
writetable(array2table(rows,'VariableNames',{'LateralOffset','RadialPenetration','CollisionCount','Cost','Distance'}),fullfile(out,'collision_plateau.csv'));
fprintf('PASS decreasing penetration from2 to0 leaves penalty110010 unchanged until leaving the closed cylinder.\n');
end
