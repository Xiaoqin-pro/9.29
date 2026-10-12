function test_FCS_reserved
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);addpath(fullfile(root,'archive','fcs_reward_20261012'));
Q=zeros(6,2);Q(2,:)=[1,100];[q,target]=fcs.updateCredit(Q,1,1,2,2,[true,false],.9,.1,false);assert(abs(target-2.9)<1e-12 && abs(q(1,1)-.29)<1e-12);[q,target]=fcs.updateCredit(Q,1,1,2,0,[false,false],.9,.1,true);assert(target==2 && q(1,1)==.2);
Ds=[7,30,100];budgets=[50:61,400];references=cell(numel(Ds),numel(budgets));calls=0;positions=[];lb=[];ub=[];exact=0;
for di=1:numel(Ds)
 D=Ds(di);lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
 for bi=1:numel(budgets)
  budget=budgets(bi);state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy','batch','reservePolicy','keep','auditDecisions',true);
  calls=0;positions=zeros(budget,D);[B1,T1,I1]=ASE_CSO_FCSQ_CountRepair(@capture,state,[],50,701);P1=positions;R1=rng;references{di,bi}=R1;
  calls=0;positions=zeros(budget,D);[B2,T2,I2]=ASE_CSO_ReservedEval(@capture,state,[],50,701);
  assert(isequal(B1,B2) && isequal(T1,T2) && isequal(P1,positions) && isequal(R1,rng),'Keep action does not exactly embed Batch.');
  assert(I1.MeanParentCoverage==I2.MeanParentCoverage);exact=exact+1;
 end
end
configs={'keep',0,1;'explore',0,1;'random',0,1;'progress',0,1;'reverse',0,1;'q',0,1;'q',.9,1;'q',0,10;'q',.9,10};checks=0;neutral=0;
for di=1:numel(Ds)
 D=Ds(di);lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
 for bi=1:numel(budgets)
  budget=budgets(bi);
  for c=1:size(configs,1)
   policy=configs{c,1};gamma=configs{c,2};bonus=configs{c,3};state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'reservePolicy',policy,'gamma',gamma,'rewardBonus',bonus,'auditDecisions',true);
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ReservedEval(@capture,state,[],50,701);globalRng=rng;assert(isequal(globalRng,references{di,bi}),'Policy sampling leaked into proposal RNG.');
   assert(calls==budget && I.Evaluations==budget && numel(T)==budget && all(isfinite(T)) && all(diff(T)<=0));assert(abs(sum(B.Vector.^2)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
   assert(I.TracingEvaluations+I.SeekingEvaluations==budget-50 && I.ActualMaxParentEvaluations<=2 && ~I.PendingAtEnd);
   L=I.DecisionLog;
   if ~isempty(L)
    assert(all(L(:,12)-L(:,18)==L(:,4)+1));assert(isequal(L(:,13),T(L(:,12)-1)) && isequal(L(:,14),T(L(:,12))));assert(isequal(L(:,19),T(L(:,18))));
    assert(all(L(:,3)==(L(:,13)<L(:,19))));phase=min(2,floor(3*(L(:,12)-1-50)/max(1,budget-50)));assert(isequal(L(:,2),1+2*phase+double(~L(:,3))));
    assert(isequal(L(:,15),max(0,L(:,13)-L(:,14))));assert(all(L(:,16)==bonus*double(L(:,15)>0)-double(L(:,15)<=0)));
    keep=L(:,7)==1;explore=~keep;assert(all(L(keep,8)==L(keep,5)) && all(L(keep,9)==L(keep,6)));assert(all(L(explore,10)==1) && all(L(explore,20)==0) && all(L(explore,8)~=L(explore,5)));
    assert(all(floor((L(:,8)-1)/5)+1==L(:,9)) && isequal(I.DecisionPoints,positions(L(:,12),:)));
    assert(all(L(L(:,11)==1,7)==1) && all(L(L(:,11)==1,17)==0));
    if strcmp(policy,'keep'),assert(all(keep));end
    if strcmp(policy,'explore'),assert(all(explore | L(:,11)==1));end
    if strcmp(policy,'progress'),assert(all(L(:,7)==1+double(~L(:,3)) | L(:,11)==1));end
    if strcmp(policy,'reverse'),assert(all(L(:,7)==1+L(:,3) | L(:,11)==1));end
   end
   if strcmp(policy,'q')
    assert(I.QUpdates==sum(I.QVisits) && I.QUpdates==I.FreeDecisions);U=I.UpdateLog;replay=zeros(6,2);
    for n=1:size(U,1)
     prev=U(n,9);assert(U(n,1)==L(prev,2) && U(n,2)==L(prev,7) && U(n,3)==L(prev,16) && U(n,7)==L(prev,12));
     if U(n,5),assert(U(n,4)==0 && U(n,6)==budget);
     else,next=find(L(:,12)-1==U(n,6));assert(isscalar(next) && U(n,4)==L(next,2) && U(n,8)==L(next,17) && U(n,6)>U(n,7));end
     [replay,~]=fcs.updateCredit(replay,U(n,1),U(n,2),U(n,3),U(n,4),[true,logical(U(n,8))],gamma,.1,logical(U(n,5)));
    end
    assert(isequal(replay,I.QTable));
   else,assert(I.QUpdates==0);end
   if D==7 && budget==400
    oldT=T;oldP=positions;state.auditDecisions=false;calls=0;positions=zeros(budget,D);[~,plainT,Iplain]=ASE_CSO_ReservedEval(@capture,state,[],50,701);assert(isequal(T,plainT) && isequal(oldP,positions) && isequal(globalRng,rng) && isequal(I.QTable,Iplain.QTable));neutral=neutral+1;
   end
   checks=checks+1;
  end
 end
end
cd(fullfile(root,'data','cec2017'));D=30;lb=-100*ones(1,D);ub=100*ones(1,D);rng(901,'twister');p0=lb+rand(50,D).*(ub-lb);state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',6000,'fcsPolicy','batch','reservePolicy','keep');f=@(x)CEC2017Function(x,1);
[B1,T1]=ASE_CSO_FCSQ_CountRepair(f,state,[],50,902);R1=rng;[B2,T2]=ASE_CSO_ReservedEval(f,state,[],50,902);assert(isequal(B1,B2) && isequal(T1,T2) && isequal(R1,rng));exact=exact+1;
fid=fopen(fullfile(root,'work','fcs_repair_20261012','reserved_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('BatchExactPairs',exact,'Cases',checks,'AuditNeutralReplays',neutral,'MaskedAndTerminalFixtures',2,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('Reserved FE checks passed: %d exact Batch pairs, %d behavior cases, %d neutral replays.%c',exact,checks,neutral,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x)) && all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
