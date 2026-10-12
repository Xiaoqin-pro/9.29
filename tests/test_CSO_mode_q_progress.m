function test_CSO_mode_q_progress
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50:61,149,150,151,250,400];policies={'fixed2','fixed4','fixed6','q'};modes={'binary','positive','gain'};exact=0;cases=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(2101);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true);
  for policy=policies
   state.modePolicy=policy{1};state.modeReward='binary';calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ(@capture,state,[],50,2102);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Progress(@capture,state,[],50,2102);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   for mode=modes
    state.modeReward=mode{1};calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Progress(@capture,state,[],50,2102);
    assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(diff(T)<=0)&&~I.PendingAtEnd);
    if ~strcmp(state.modePolicy,'q'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng));end
    L=I.DecisionLog;U=I.UpdateLog;A=I.RewardLog;assert(size(A,1)==size(L,1));gain=max(0,L(:,8)-L(:,9));
    assert(isequal(A(:,2),gain)&&isequal(A(:,4),L(:,9))&&isequal(A(:,3),L(:,10)));
    switch mode{1},case 'binary',expected=2*double(gain>0)-1;case 'positive',expected=double(gain>0);case 'gain',expected=min(1,gain./max(A(:,1),eps));end
    assert(isequal(expected,L(:,10))&&all(A(:,1)>=0));
    if strcmp(state.modePolicy,'q')
     replay=zeros(6,3);visits=zeros(6,3);
     for n=1:size(U,1)
      if U(n,8),future=0;if ~U(n,5),future=.9*max(replay(U(n,4),:));end;s=U(n,1);a=U(n,2);replay(s,a)=replay(s,a)+.1*(U(n,3)+future-replay(s,a));visits(s,a)=visits(s,a)+1;end
     end
     assert(isequal(replay,I.QTable)&&isequal(visits,I.QVisits));
    end
    cases=cases+1;
   end
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(2201);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','logTrajectory',true);
 f=@(x)CEC2017Function(x,fid);[B0,T0,I0]=ASE_CSO_ModeQ(f,state,[],50,2202);R0=rng;[B,T,I]=ASE_CSO_ModeQ_Progress(f,state,[],50,2202);
 assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','cso_mode_q_reward_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('DefaultExactPairs',exact,'Cases',cases,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS progress reward exact%d cases%d\n',exact,cases);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
