function test_CSO_mode_q
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
policies={'fixed2','fixed4','fixed6','random','phase','epsfixed','q'};budgets=[50:61,149,150,151,250,400];Ds=[7,50];exact=0;cases=0;neutral=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(1801);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true);
  for quota=[2,4,6]
   state.modeTraceQuota=quota;state.modePolicy=['fixed' num2str(quota)];calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeBudget(@capture,state,[],50,1802);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ(@capture,state,[],50,1802);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.RoundLog,I.RoundLog));exact=exact+1;
  end
  for c=1:numel(policies)
   state.modePolicy=policies{c};state.auditSimplify=true;calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ(@capture,state,[],50,1802);R=rng;
   assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(diff(T)<=0)&&all(isfinite(T))&&~I.PendingAtEnd);
   assert(I.TracingEvaluations+I.SeekingEvaluations==budget-50&&I.MaxParentEvaluations<=2&&isequal(I.EvalPoints,positions));
   L=I.DecisionLog;U=I.UpdateLog;assert(size(L,1)==ceil((budget-50)/100)&&size(U,1)==size(L,1));
   if ~isempty(L)
    assert(all(L(:,2)-L(:,1)==L(:,11)+L(:,12))&&all(L(:,2)>L(:,1))&&all(L(:,2)-L(:,1)<=100));
    assert(isequal(L(:,8),T(L(:,1)))&&isequal(L(:,9),T(L(:,2)))&&isequal(L(:,10),2*double(L(:,9)<L(:,8))-1));
    expectedPrev=[false;L(1:end-1,9)<L(1:end-1,8)];phase=min(2,floor(3*(L(:,1)-50)/max(1,budget-50)));
    assert(isequal(L(:,7),double(expectedPrev))&&isequal(L(:,3),1+2*phase+double(~expectedPrev))&&all(L(:,5)==2*L(:,4)));
    assert(all(U(:,1:3)==L(:,[3,4,10]),'all')&&all(U(:,6:7)==L(:,1:2),'all'));
    assert(all(U(1:end-1,4)==L(2:end,3))&&U(end,4)==0&&U(end,5)==1&&all(U(1:end-1,5)==0));
    assert(isequal(U(:,8),double(L(:,13)==0)));
    if strcmp(state.modePolicy,'q')
     replay=zeros(6,3);visits=zeros(6,3);
     for n=1:size(U,1)
      if U(n,8)
       ns=U(n,4);future=0;if ~U(n,5),future=.9*max(replay(ns,:));end
       ps=U(n,1);pa=U(n,2);replay(ps,pa)=replay(ps,pa)+.1*(U(n,3)+future-replay(ps,pa));visits(ps,pa)=visits(ps,pa)+1;
      end
     end
     assert(isequal(replay,I.QTable)&&isequal(visits,I.QVisits)&&I.QUpdates==sum(visits,'all')&&all(L(:,14)==U(:,8)));
    else,assert(I.QUpdates==0&&all(L(:,14)==0));end
    if startsWith(state.modePolicy,'fixed'),assert(all(L(:,5)==str2double(extractAfter(state.modePolicy,'fixed'))));end
    if strcmp(state.modePolicy,'phase'),assert(all(L(:,4)==2+double(L(:,6)==2)));end
   end
   cases=cases+1;
   if D==7&&budget==400
    P=positions;oldT=T;state.auditSimplify=false;calls=0;positions=zeros(budget,D);[Bn,Tn,In]=ASE_CSO_ModeQ(@capture,state,[],50,1802);
    assert(isequal(B,Bn)&&isequal(P,positions)&&isequal(Tn,oldT)&&isequal(R,rng)&&isequal(I.QTable,In.QTable)&&isequal(I.DecisionLog,In.DecisionLog));neutral=neutral+1;
   end
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(1901);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,12]
 for quota=[2,4,6]
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modeTraceQuota',quota,'modePolicy',['fixed' num2str(quota)]);
  f=@(x)CEC2017Function(x,fid);[B0,T0]=ASE_CSO_ModeBudget(f,state,[],50,1902);R0=rng;[B,T]=ASE_CSO_ModeQ(f,state,[],50,1902);
  assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng));exact=exact+1;
 end
end
out=fullfile(root,'work','cso_mode_q_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('FixedExactPairs',exact,'BehaviorCases',cases,'AuditNeutral',neutral,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS mode Q exact%d behavior%d neutral%d\n',exact,cases,neutral);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
