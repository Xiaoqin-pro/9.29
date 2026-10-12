function test_CSO_quota_episode
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,400,650,651,1151];policies={'fixed6','q','gateq','gaterandom','gate2','gate4','gateeps6'};exact=0;cases=0;neutral=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(4301);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true,'modeState','stagnation','stagnationThreshold',100);
  for policy=policies
   state.modePolicy=policy{1};state.episodeFE=100;calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_StallGate(@capture,state,[],50,4302);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Episode(@capture,state,[],50,4302);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   state.episodeFE=500;calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Episode(@capture,state,[],50,4302);R=rng;
   assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0)&&~I.PendingAtEnd&&I.MaxParentEvaluations<=2);
   if ~startsWith(policy{1},'gate'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng));end
   L=I.DecisionLog;G=I.GateLog;U=I.UpdateLog;S=I.StateLog;
   if ~isempty(L)
    durations=L(:,2)-L(:,1);planned=100*ones(size(durations));if startsWith(policy{1},'gate'),planned(G(:,2)==1)=500;end
    assert(isequal(durations,min(planned,budget-L(:,1)))&&L(1,1)==50&&L(end,2)==budget&&isequal(L(1:end-1,2),L(2:end,1)));
    assert(isequal(I.DiscountLog,.9.^(durations/100))&&isequal(L(:,8),T(L(:,1)))&&isequal(L(:,9),T(L(:,2))));
    assert(all(U(1:end-1,4)==L(2:end,3))&&U(end,5)==1&&U(end,4)==0);
   end
   Q=zeros(6,3);V=zeros(6,3);
   if ismember(policy{1},{'q','gateq'}),for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=I.DiscountLog(k)*max(Q(U(k,4),:));end;s=U(k,1);a=U(k,2);Q(s,a)=Q(s,a)+.1*(U(k,3)+future-Q(s,a));V(s,a)=V(s,a)+1;end;end;end
   assert(isequal(Q,I.QTable)&&isequal(V,I.QVisits));cases=cases+1;
   if D==7&&budget==1151
    oldP=positions;oldT=T;state.auditSimplify=false;state.logTrajectory=false;calls=0;positions=zeros(budget,D);[Bn,Tn,In]=ASE_CSO_ModeQ_Episode(@capture,state,[],50,4302);assert(isequal(B,Bn)&&isequal(oldP,positions)&&isequal(oldT,Tn)&&isequal(R,rng)&&isequal(I.QTable,In.QTable));neutral=neutral+1;
   end
   state.auditSimplify=true;state.logTrajectory=true;
  end
 end
end
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',1651,'modeState','stagnation','stagnationThreshold',100,'episodeFE',500,'logTrajectory',true);
for policy={'gateq','gaterandom','gate2','gate4','gateeps6'}
 state.modePolicy=policy{1};[~,T,I]=ASE_CSO_ModeQ_Episode(@(x)1,state,[],50,4302);L=I.DecisionLog;G=I.GateLog;assert(all(T==1)&&G(1,2)==0&&all(G(2:end,2)==1)&&L(1,2)-L(1,1)==100&&all(L(2:end-1,2)-L(2:end-1,1)==500));cases=cases+1;
end
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(4401);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modeState','stagnation','modePolicy','gateq','episodeFE',100,'logTrajectory',true);f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_StallGate(f,state,[],50,4402);R0=rng;[B,T,I]=ASE_CSO_ModeQ_Episode(f,state,[],50,4402);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','quota_q_episode_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('HundredFEExactPairs',exact,'EpisodeCases',cases,'LogNeutralPairs',neutral,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS episode exact%d cases%d neutral%d%c',exact,cases,neutral,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
