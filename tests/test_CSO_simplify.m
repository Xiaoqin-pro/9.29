function test_CSO_simplify
% B10 regression, tails, parent/row identity, and audit neutrality.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[1,7,30,50,100];budgets=[50:63,100,400];exact=0;behavior=0;neutral=0;witness=0;
calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(410);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true);
  calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_Lean_B10(@capture,state,[],50,411);P0=positions;R0=rng;
  calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_Simplify(@capture,state,[],50,411);
  assert(isequal(B0,B) && isequal(T0,T) && isequal(P0,positions) && isequal(R0,rng),'Default diverges from B10.');
  assert(I0.TracingEvaluations==I.TracingEvaluations && I0.SeekingEvaluations==I.SeekingEvaluations);exact=exact+1;
  for c=1:3
   state.seekCandidateCount=4;state.useSeekingElite=true;state.auditSimplify=true;
   if c==2,state.seekCandidateCount=2;elseif c==3,state.useSeekingElite=false;end
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_Simplify(@capture,state,[],50,411);R=rng;
   assert(calls==budget && numel(T)==budget && I.Evaluations==budget && all(isfinite(T)) && all(diff(T)<=0));
   assert(abs(sum(B.Vector.^2)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
   assert(I.TracingEvaluations+I.SeekingEvaluations==budget-50 && I.MaxParentEvaluations<=2);
   assert(I.Rounds==ceil((budget-50)/10) && isequal(I.EvalPoints,positions));L=I.EvalLog;SMP=state.seekCandidateCount+1;
   if budget>50
    checkValues=sum(positions(51:end,:).^2,2);assert(all(abs(L(51:end,7)-checkValues)<=1e-12*max(1,abs(checkValues))));
    assert(isequal(L(51:end,8),T(50:end-1)) && isequal(L(51:end,9),T(51:end)));
    seek=L(:,3)==2;assert(all(L(seek,5)>=2 & L(seek,5)<=SMP));
    for r=1:I.Rounds
     ix=L(:,2)==r;Ls=L(ix & seek,:);if ~isempty(Ls)
      pairs=Ls(:,[4,5]);assert(size(unique(pairs,'rows'),1)==size(pairs,1));
      cnt=accumarray(Ls(:,4),1,[50,1]);assert(max(cnt)<=2);
     end
     assert(sum(ix)==I.RoundLog(r,2)-I.RoundLog(r,1));
     assert(sum(L(ix,3)==1)==I.RoundLog(r,3) && sum(L(ix,3)==2)==I.RoundLog(r,4));
    end
   end
   behavior=behavior+1;
   if D==7 && budget==400
    P=positions;oldT=T;state.auditSimplify=false;calls=0;positions=zeros(budget,D);
    [Bplain,Tplain,Iplain]=ASE_CSO_Simplify(@capture,state,[],50,411);
    assert(isequal(P,positions) && isequal(Tplain,oldT) && isequal(B,Bplain) && isequal(R,rng) && isequal(I.RoundLog,Iplain.RoundLog));neutral=neutral+1;
   end
  end
 end
end
% Identical initial cats have zero Seeking elite offset in the first round.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',3*ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',60,'useSeekingElite',true);
calls=0;positions=zeros(60,D);[B,T]=ASE_CSO_Simplify(@capture,state,[],50,500);P=positions;R=rng;state.useSeekingElite=false;
calls=0;positions=zeros(60,D);[B2,T2]=ASE_CSO_Simplify(@capture,state,[],50,500);
assert(isequal(B,B2) && isequal(T,T2) && isequal(P,positions) && isequal(R,rng));witness=witness+1;
% First-round Tracing proposals are unchanged by only removing Seeking offset.
rng(501);state.initialPopulation=lb+rand(50,D).*(ub-lb);state.auditSimplify=true;state.useSeekingElite=true;
calls=0;positions=zeros(60,D);[~,~,Ia]=ASE_CSO_Simplify(@capture,state,[],50,502);Pa=positions;state.useSeekingElite=false;
calls=0;positions=zeros(60,D);[~,~,Ib]=ASE_CSO_Simplify(@capture,state,[],50,502);ta=Ia.EvalLog(:,3)==1;tb=Ib.EvalLog(:,3)==1;
assert(isequal(Ia.EvalLog(ta,4),Ib.EvalLog(tb,4)) && isequal(Pa(ta,:),positions(tb,:)));witness=witness+1;
% CEC objective regression uses actual MEX and known data-directory working path.
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=30;lb=-100*ones(1,D);ub=100*ones(1,D);rng(610);p0=lb+rand(50,D).*(ub-lb);
for caseIndex=1:6
 D=30+20*double(caseIndex>3);lb=-100*ones(1,D);ub=100*ones(1,D);rng(610);p0=lb+rand(50,D).*(ub-lb);funcs=[1,6,12];fid=funcs(mod(caseIndex-1,3)+1);
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600);
 f=@(x)CEC2017Function(x,fid);[B0,T0]=ASE_CSO_Lean_B10(f,state,[],50,611);R0=rng;[B,T]=ASE_CSO_Simplify(f,state,[],50,611);
 assert(isequal(B0,B) && isequal(T0,T) && isequal(R0,rng));exact=exact+1;
end
out=fullfile(root,'work','cso_simplify_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('DefaultExactPairs',exact,'BehaviorCases',behavior,'AuditNeutral',neutral,'DeletionWitnesses',witness,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS simplify exact%d behavior%d neutral%d witnesses%d\n',exact,behavior,neutral,witness);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x)) && all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
