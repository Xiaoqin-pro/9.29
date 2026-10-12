function test_CSO_mode_quota
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50:63,400];exact=0;cases=0;neutral=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(1601);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true);
  calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_Simplify(@capture,state,[],50,1602);P0=positions;R0=rng;
  calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeBudget(@capture,state,[],50,1602);
  assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.RoundLog,I.RoundLog));exact=exact+1;
  for traceQuota=[2,4,6]
   state.modeTraceQuota=traceQuota;state.auditSimplify=true;calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeBudget(@capture,state,[],50,1602);R=rng;
   assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(diff(T)<=0)&&all(isfinite(T)));
   assert(I.TracingEvaluations+I.SeekingEvaluations==budget-50&&I.MaxParentEvaluations<=2&&isequal(I.EvalPoints,positions));
   L=I.RoundLog;E=I.EvalLog;assert(all(L(:,2)-L(:,1)==L(:,3)+L(:,4)));
   full=L(:,2)-L(:,1)==10;enough=L(:,5)>=traceQuota & 2*L(:,6)>=10-traceQuota;
   assert(all(L(full&enough,3)==traceQuota)&all(L(full&enough,4)==10-traceQuota));
   if budget>50
    assert(isequal(E(51:end,8),T(50:end-1))&&isequal(E(51:end,9),T(51:end)));
    assert(abs(sum(B.Vector.^2)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
   end
   cases=cases+1;
   if D==7&&budget==400
    P=positions;oldT=T;state.auditSimplify=false;calls=0;positions=zeros(budget,D);[Bn,Tn,In]=ASE_CSO_ModeBudget(@capture,state,[],50,1602);
    assert(isequal(B,Bn)&&isequal(P,positions)&&isequal(Tn,oldT)&&isequal(R,rng)&&isequal(I.RoundLog,In.RoundLog));neutral=neutral+1;
   end
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(1701);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,12]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600);
 f=@(x)CEC2017Function(x,fid);[B0,T0]=ASE_CSO_Simplify(f,state,[],50,1702);R0=rng;[B,T]=ASE_CSO_ModeBudget(f,state,[],50,1702);
 assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng));exact=exact+1;
end
out=fullfile(root,'work','cso_mode_quota_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('Quota4ExactPairs',exact,'BehaviorCases',cases,'AuditNeutral',neutral,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS mode quota exact%d behavior%d neutral%d\n',exact,cases,neutral);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
