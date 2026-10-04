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
