function test_FCS_repair
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);addpath(fullfile(root,'archive','fcs_repair_20261012'));
work=fullfile(root,'work','fcs_repair_20261012');if ~isfolder(work),mkdir(work);end
policies={'batch','continue','switch','random','success','reverse','q'};calls=0;positions=[];lb=[];ub=[];
% Reproduce the old odd-tail defect before validating its repair.
witness=cell(0,1);D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
for budget=[57,59]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy','continue');
 [~,~,oldInfo]=ASE_CSO_FCSQ_BeforeRepair(@(x)sum(x.^2),state,[],50,701);assert(oldInfo.Rounds==2,'Old tail witness changed.');
 [~,~,newInfo]=ASE_CSO_FCSQ(@(x)sum(x.^2),state,[],50,701);assert(newInfo.Rounds==1);
 witness{end+1}=struct('Budget',budget,'BeforeRounds',oldInfo.Rounds,'AfterRounds',newInfo.Rounds); %#ok<AGROW>
end
writetable(struct2table([witness{:}]),fullfile(work,'tail_witness.csv'));passed=0;
for D=[7,30,100]
 for budget=[50:61,400]
  for p=1:numel(policies)
   lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy',policies{p},'auditDecisions',true);
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_FCSQ(@capture,state,[],50,701);finalRng=rng;
   assert(calls==budget && I.Evaluations==budget && numel(T)==budget);assert(all(isfinite(T)) && all(diff(T)<=0));
   assert(abs(sum(B.Vector.^2)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
   assert(I.SeekingEvaluations+I.TracingEvaluations==budget-50 && I.ActualMaxParentEvaluations<=2);
   assert(I.Rounds==ceil((budget-50)/10));assert(all(I.RoundLog(:,4)==I.RoundLog(:,6)) && all(I.RoundLog(:,5)==I.RoundLog(:,7)));
   assert(sum(I.RoundLog(:,6)+I.RoundLog(:,7))==budget-50);
   L=I.DecisionLog;
   if ~isempty(L)
    assert(all(L(:,8)==1+double(L(:,9)~=L(:,4))));assert(all(L(:,11)<=1));assert(all(L(:,14)==2*L(:,13)-1));
    assert(all(L(:,6)==double(L(:,18)<L(:,17))) && all(L(:,13)==double(L(:,20)<L(:,19))));
    assert(all(floor((L(:,10)-1)/5)+1==L(:,9)) && all(floor((L(:,5)-1)/5)+1==L(:,4)));
    assert(isequal(I.StarterPoints,positions(L(:,2),:)) && isequal(I.FollowPoints,positions(L(:,16),:)),'Logged points differ from actual objective inputs.');
    same=L(:,8)==1;assert(all(L(same,11)==1));firstImproved=same & L(:,6)==1;assert(all(L(firstImproved,19)==L(firstImproved,18)),'Follow-up compared against stale parent anchor.');
    assert(I.FallbackCount==sum(L(:,12)) && I.ActionMismatchCount==sum(L(:,7)~=L(:,8)));
    if strcmp(policies{p},'continue'),assert(all(same) && all(L(:,7)==1));end
    if strcmp(policies{p},'switch'),assert(all(~same) && all(L(:,7)==2));end
    if strcmp(policies{p},'success'),assert(all(L(:,7)==1+double(~L(:,6))));end
    if strcmp(policies{p},'reverse'),assert(all(L(:,7)==1+L(:,6)));end
   end
   assert(I.FallbackCount==0 && I.ActionMismatchCount==0 && I.QFallbackUpdates==0);
   if D==7 && budget==400
    expectedT=T;expectedPositions=positions;state.auditDecisions=false;calls=0;positions=zeros(budget,D);
    [~,plainT]=ASE_CSO_FCSQ(@capture,state,[],50,701);
    assert(isequal(expectedT,plainT) && isequal(expectedPositions,positions) && isequal(finalRng,rng),'Audit flag changed search trajectory/RNG.');
   end
   passed=passed+1;
  end
 end
end
% Batch's computation and RNG must remain exactly equivalent to the old source.
for D=[7,30,100]
 for budget=[59,400]
  lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy','batch');
  calls=0;positions=zeros(budget,D);[B1,T1]=ASE_CSO_FCSQ_BeforeRepair(@capture,state,[],50,701);R1=rng;P1=positions;
  calls=0;positions=zeros(budget,D);[B2,T2]=ASE_CSO_FCSQ(@capture,state,[],50,701);
  assert(isequal(B1,B2) && isequal(T1,T2) && isequal(R1,rng) && isequal(P1,positions),'Unchanged batch path regressed.');
 end
end
fid=fopen(fullfile(work,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('Cases',passed,'TailWitnesses',2,'BatchExactRegressions',6,'AuditNeutralReplays',7,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('FCS repair passed: %d cases, 2 old-tail witnesses, 6 exact batch regressions, 7 audit-neutral replays.%c',passed,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x)) && all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
