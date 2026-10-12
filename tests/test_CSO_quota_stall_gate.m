function test_CSO_quota_stall_gate
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,400,1151];exact=0;cases=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(4101);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true,'modeState','stagnation','stagnationThreshold',100);
  for policy={'fixed6','q','random','epsfixed'}
   state.modePolicy=policy{1};calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_State(@capture,state,[],50,4102);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_StallGate(@capture,state,[],50,4102);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
  end
  for policy={'gateq','gaterandom','gate2','gate4','gateeps6'}
   state.modePolicy=policy{1};calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_StallGate(@capture,state,[],50,4102);L=I.DecisionLog;G=I.GateLog;S=I.StateLog;U=I.UpdateLog;
   assert(calls==budget&&numel(T)==budget&&all(diff(T)<=0)&&~I.PendingAtEnd);
   assert(all(G(:,1)==1)&&isequal(G(:,2),S(:,2))&&isequal(G(:,3),L(:,4))&&all(L(G(:,2)==0,4)==3));
   assert(I.FreeDecisions==sum(G(:,2))&&I.ForcedFixed6Decisions==sum(G(:,2)==0));
   assert(isequal(U(:,8),double(G(:,2)==1&L(:,13)==0)));
   Q=zeros(6,3);V=zeros(6,3);
   if strcmp(policy{1},'gateq')
    for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=.9*max(Q(U(k,4),:));end;s=U(k,1);a=U(k,2);Q(s,a)=Q(s,a)+.1*(U(k,3)+future-Q(s,a));V(s,a)=V(s,a)+1;end;end
    assert(all(I.QTable([1,3,5],:)==0,'all')&&all(I.QVisits([1,3,5],:)==0,'all'));
   end
   assert(isequal(Q,I.QTable)&&isequal(V,I.QVisits));
   if strcmp(policy{1},'gate2'),assert(all(L(G(:,2)==1,4)==1));end
   if strcmp(policy{1},'gate4'),assert(all(L(G(:,2)==1,4)==2));end
   cases=cases+1;
  end
 end
end
% Healthy landscape until threshold: same Fixed6 objective-call prefix under every gate.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',400,'modeState','stagnation','stagnationThreshold',100,'auditSimplify',true,'logTrajectory',true);
state.modePolicy='fixed6';[~,~,I0]=ASE_CSO_ModeQ_StallGate(@(x)1,state,[],50,4102);
for policy={'gateq','gaterandom','gate2','gate4','gateeps6'}
 state.modePolicy=policy{1};[~,T,I]=ASE_CSO_ModeQ_StallGate(@(x)1,state,[],50,4102);assert(all(T==1)&&I.FreeDecisions>=2&&I.ForcedFixed6Decisions==1&&isequal(I0.EvalPoints(1:150,:),I.EvalPoints(1:150,:)));cases=cases+1;
end
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(4201);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modeState','stagnation','modePolicy','q','logTrajectory',true);f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_State(f,state,[],50,4202);R0=rng;[B,T,I]=ASE_CSO_ModeQ_StallGate(f,state,[],50,4202);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','quota_q_gap_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'gate_behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('OriginalExactPairs',exact,'GateCases',cases,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS stallgate exact%d cases%d%c',exact,cases,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
