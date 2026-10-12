function test_CSO_q_initial_value
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,150,151,400,1051];policies={'fixed2','fixed4','fixed6','random','phase','epsfixed','effrule','reverseeff','q'};exact=0;cases=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(3101);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'modeState','efficiency','auditSimplify',true,'logTrajectory',true,'initialQ',0);
  for policy=policies
   state.modePolicy=policy{1};state.initialQ=0;calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_Efficiency(@capture,state,[],50,3102);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_InitialValue(@capture,state,[],50,3102);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.DecisionLog,I.DecisionLog)&&isequal(I0.QTable,I.QTable));exact=exact+1;
   state.initialQ=-10;calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_InitialValue(@capture,state,[],50,3102);
   assert(calls==budget&&I.Evaluations==budget&&all(diff(T)<=0)&&~I.PendingAtEnd);
   if ~strcmp(policy{1},'q'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng));end
   U=I.UpdateLog;Q=-10*ones(6,3);V=zeros(6,3);
   if strcmp(policy{1},'q'),for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=.9*max(Q(U(k,4),:));end;s=U(k,1);a=U(k,2);Q(s,a)=Q(s,a)+.1*(U(k,3)+future-Q(s,a));V(s,a)=V(s,a)+1;end;end;end
   assert(isequal(Q,I.QTable)&&isequal(V,I.QVisits));cases=cases+1;
  end
 end
end
% One-state flat landscape: lower-bound Q remains -10 before terminal update.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',400,'modePolicy','q','modeState','efficiency','initialQ',-10,'logTrajectory',true);
[~,T,I]=ASE_CSO_ModeQ_InitialValue(@(x)1,state,[],50,3102);assert(all(T==1));U=I.UpdateLog;Q=-10*ones(6,3);
for k=1:size(U,1)-1
 s=U(k,1);a=U(k,2);Q(s,a)=Q(s,a)+.1*(U(k,3)+.9*max(Q(U(k,4),:))-Q(s,a));assert(isequal(Q,-10*ones(6,3)));
end
u=U(end,:);Q(u(1),u(2))=Q(u(1),u(2))+.1*(u(3)-Q(u(1),u(2)));assert(isequal(Q,I.QTable));cases=cases+1;
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(3201);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','modeState','efficiency','initialQ',0,'logTrajectory',true);f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_Efficiency(f,state,[],50,3202);R0=rng;[B,T,I]=ASE_CSO_ModeQ_InitialValue(f,state,[],50,3202);
 assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','cso_q_learning_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'initial_value_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('ZeroInitExactPairs',exact,'Cases',cases,'FlatBellmanLowerBound',true,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS initial-value exact%d cases%d%c',exact,cases,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
