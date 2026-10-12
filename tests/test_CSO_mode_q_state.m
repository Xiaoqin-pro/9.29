function test_CSO_mode_q_state
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,250,600];policies={'fixed2','fixed4','fixed6','q'};exact=0;cases=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(2301);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true);
  for policy=policies
   state.modePolicy=policy{1};state.modeState='previous';calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ(@capture,state,[],50,2302);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_State(@capture,state,[],50,2302);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   for threshold=[100,500,1000]
    state.modeState='stagnation';state.stagnationThreshold=threshold;calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_State(@capture,state,[],50,2302);
    assert(calls==budget&&I.Evaluations==budget&&all(diff(T)<=0)&&~I.PendingAtEnd);
    if ~strcmp(policy{1},'q'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng));end
    L=I.DecisionLog;A=I.StateLog;G=I.TrendLog;U=I.UpdateLog;
    assert(isequal(A(:,1),G(1:end-1,5))&&isequal(A(:,2),double(A(:,1)>=threshold))&&isequal(A(:,3),L(:,3)));
    assert(isequal(L(:,3),1+2*L(:,6)+A(:,2))&&isequal(L(:,10),2*double(L(:,9)<L(:,8))-1));
    replay=zeros(6,3);visits=zeros(6,3);
    if strcmp(policy{1},'q')
     for k=1:size(U,1)
      if U(k,8),future=0;if ~U(k,5),future=.9*max(replay(U(k,4),:));end;s=U(k,1);a=U(k,2);replay(s,a)=replay(s,a)+.1*(U(k,3)+future-replay(s,a));visits(s,a)=visits(s,a)+1;end
     end
    end
    assert(isequal(replay,I.QTable)&&isequal(visits,I.QVisits));cases=cases+1;
   end
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(2401);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','logTrajectory',true);
 f=@(x)CEC2017Function(x,fid);[B0,T0,I0]=ASE_CSO_ModeQ(f,state,[],50,2402);R0=rng;[B,T,I]=ASE_CSO_ModeQ_State(f,state,[],50,2402);
 assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','cso_mode_q_state_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('DefaultExactPairs',exact,'Cases',cases,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS state exact%d cases%d\n',exact,cases);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
