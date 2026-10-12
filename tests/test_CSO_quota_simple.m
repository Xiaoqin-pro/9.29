function test_CSO_quota_simple
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,400,1051];exact=0;cases=0;neutral=0;calls=0;points=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(4901);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'logTrajectory',true,'auditSimplify',true,'episodeFE',100);
  for policy={'q','fixed6','random','phase','epsfixed'}
   for stateMode={'previous','stagnation'}
    state.modePolicy=policy{1};state.modeState=stateMode{1};state.rewardBonus=1;calls=0;points=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_State(@capture,state,[],50,4902);P0=points;R0=rng;
    calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_QuotaQ_Simple(@capture,state,[],50,4902);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   end
   state.rewardBonus=10;state.modeState='stagnation';calls=0;points=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_EpisodeBonus(@capture,state,[],50,4902);P0=points;R0=rng;
   calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_QuotaQ_Simple(@capture,state,[],50,4902);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   for mode={'stagnation','phase'}
    state.modeState=mode{1};calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_QuotaQ_Simple(@capture,state,[],50,4902);R=rng;
    assert(calls==budget&&numel(T)==budget&&I.Evaluations==budget&&all(isfinite(T))&&all(diff(T)<=0)&&~I.PendingAtEnd);
    if strcmp(mode{1},'phase')&&~strcmp(policy{1},'q'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng));end
    L=I.DecisionLog;U=I.UpdateLog;expected=10*double(L(:,9)<L(:,8))-double(L(:,9)>=L(:,8));assert(isequal(expected,L(:,10)));
    if strcmp(mode{1},'phase'),assert(size(I.QTable,1)==3&&isequal(L(:,3),L(:,6)+1)&&all(I.StateLog(:,2)==0));else,assert(size(I.QTable,1)==6&&isequal(L(:,3),1+2*L(:,6)+I.StateLog(:,2)));end
    Q=zeros(size(I.QTable));V=zeros(size(I.QVisits));if strcmp(policy{1},'q'),for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=.9*max(Q(U(k,4),:));end;s=U(k,1);a=U(k,2);Q(s,a)=Q(s,a)+.1*(U(k,3)+future-Q(s,a));V(s,a)=V(s,a)+1;end;end;end
    assert(isequal(Q,I.QTable)&&isequal(V,I.QVisits));cases=cases+1;
    if D==7&&budget==1051
     oldP=points;state.logTrajectory=false;state.auditSimplify=false;calls=0;points=zeros(budget,D);[Bn,Tn,In]=ASE_CSO_QuotaQ_Simple(@capture,state,[],50,4902);assert(isequal(B,Bn)&&isequal(T,Tn)&&isequal(oldP,points)&&isequal(R,rng)&&isequal(I.QTable,In.QTable));neutral=neutral+1;
    end
    state.logTrajectory=true;state.auditSimplify=true;
   end
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(5001);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','modeState','stagnation','rewardBonus',10,'episodeFE',100,'logTrajectory',true);f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_EpisodeBonus(f,state,[],50,5002);R0=rng;[B,T,I]=ASE_CSO_QuotaQ_Simple(f,state,[],50,5002);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','quota_q_simplicity_20261012');if ~isfolder(out),mkdir(out);end;fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('OldExactPairs',exact,'DeletionCases',cases,'LogNeutralPairs',neutral,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS simple quota Q exact%d cases%d neutral%d%c',exact,cases,neutral,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));points(calls,:)=x;value=sum(x.^2);
 end
end
