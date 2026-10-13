function test_SAQ_framework_ablation
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
exact=0;behavior=0;denseWitness=0;calls=0;points=[];lb=[];ub=[];f=[];budget=0;N=50;seed=0;state=[];
variants={'Full','Fixed4','Fixed6','RandomSparse-Fixed6','RandomQuota','Dense-NoQ'};
for D=[7,50]
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(351);p0=lb+rand(N,D).*(ub-lb);
 for budget=[50,51,57,63,400,1200,2400]
  for seed=[352,353]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true);
   f=@(x)sum(x.^2);compareExact;
   for v=1:numel(variants)
    state.ablationVariant=variants{v};checkBehavior;
   end
  end
 end
end
% Full branch compares true pure gateQ with alpha/gamma/default state preserved.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(354);p0=lb+rand(N,D).*(ub-lb);
budget=2400;seed=355;state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true);
f=@(x)1;compareExact;
for v=1:numel(variants),state.ablationVariant=variants{v};checkBehavior;end
% Test random selector chooses different actual points under exactly same FE.
state.ablationVariant='Full';calls=0;points=zeros(budget,D);[~,~,Ifull]=SAQ_CSO_AblationVariant(@capture,state,[],N,seed);Pfull=points;
state.ablationVariant='RandomSparse-Fixed6';calls=0;points=zeros(budget,D);[~,~,Irandom]=SAQ_CSO_AblationVariant(@capture,state,[],N,seed);
assert(~isequal(Pfull,points)&&size(Ifull.QTable,1)==3&&Ifull.QUpdates>0&&Irandom.QUpdates==0);
state.ablationVariant='RandomQuota';calls=0;points=zeros(budget,D);[~,~,Ir]=SAQ_CSO_AblationVariant(@capture,state,[],N,seed);assert(Ir.QUpdates==0&&Ir.FreeDecisions>0);
assert(numel(unique(Ir.DecisionLog(Ir.GateLog(:,2)==1,4)))==3);
% Dense sampler first round: independently reconstruct all original candidate formulas.
D=7;budget=400;seed=356;lb=-100*ones(1,D);ub=100*ones(1,D);rng(357);p0=lb+rand(N,D).*(ub-lb);
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'ablationVariant','Dense-NoQ');
f=@(x)sum(x.^2);calls=0;points=zeros(budget,D);[~,~,I]=SAQ_CSO_AblationVariant(@capture,state,[],N,seed);
pred=firstRoundCandidates(p0,lb,ub,seed);obs=points(N+1:I.FrameworkLog(1,2),:);
assert(size(obs,1)==size(pred,1)&&isequal(sortrows(obs),sortrows(pred)));
denseWitness=1;
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(358);p0=lb+rand(N,D).*(ub-lb);
for fid=[1,6,13]
 budget=1200;seed=359;state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true);
 f=@(x)CEC2017Function(x,fid);compareExact;
 for v=1:numel(variants),state.ablationVariant=variants{v};checkBehavior;end
end
% Full100k preflight: independent frozen-main equivalence and all5 true-FE controls.
full100kCases=0;budget=100000;seed=360;fid=13;
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
f=@(x)CEC2017Function(x,fid);compareExact;
for v=2:numel(variants)
 state.ablationVariant=variants{v};calls=0;points=zeros(budget,D);
 [B,T,I]=SAQ_CSO_AblationVariant(@capture,state,[],N,seed);
 assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0)&&T(end)==B.Cost&&I.QUpdates==0);
 assert(abs(f(B.Vector)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
 assert(I.TracingEvaluations+I.SeekingEvaluations==budget-N);
 if strcmp(variants{v},'Dense-NoQ'),assert(I.MaxParentEvaluations<=4);else,assert(I.MaxParentEvaluations<=2);end
 if any(strcmp(variants{v},{'Fixed4','Fixed6'}))
  s=state;s.modeTraceQuota=4;if strcmp(variants{v},'Fixed6'),s.modeTraceQuota=6;end
  calls=0;points=zeros(budget,D);[B2,T2]=ASE_CSO_ModeBudget(@capture,s,[],N,seed);assert(isequal(B,B2)&&isequal(T,T2));
 end
 full100kCases=full100kCases+1;
end
out=fullfile(root,'work','saq_framework_ablation_20261013');if ~isfolder(out),mkdir(out);end
hashes=struct('Engine',SourceFileSHA256(fullfile(root,'src','SAQ_CSO_FrameworkAblation.m')), ...
 'Variant',SourceFileSHA256(fullfile(root,'src','SAQ_CSO_AblationVariant.m')), ...
 'FrozenMain',SourceFileSHA256(fullfile(root,'src','ASE_CSO_QuotaQ_Compact.m')));
fid=fopen(fullfile(out,'preflight.json'),'w');fprintf(fid,'%s',jsonencode(struct( ...
 'Full100kNewVariants',full100kCases,'FixedQuotaIndependentBudgetEngineMatch',true,'ExactFrozenMainPairs',exact,'VariantBehaviorCases',behavior,'IndependentDensePoolWitness',denseWitness, ...
 'RandomSelectorActualPointDifference',true,'FormalVariants',{variants},'MatchedFixed6RandomScreen',true,'GatedRandomQuotaWithoutQLearning',true, ...
 'SourceHashes',hashes,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS framework ablation exact%d behavior%d dense-pool witness%d\n',exact,behavior,denseWitness);
 function compareExact
  s=state;s=rmfieldIfPresent(s,'ablationVariant');
  calls=0;points=zeros(budget,numel(lb));[B0,T0,I0]=ASE_CSO_QuotaQ_Candidate(@capture,s,[],N,seed);P0=points;R0=rng;
  calls=0;points=zeros(budget,numel(lb));s.ablationVariant='Full';[B,T,I]=SAQ_CSO_AblationVariant(@capture,s,[],N,seed);
  assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng));
  assert(isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog)&&isequal(I0.RoundLog,I.RoundLog));exact=exact+1;
 end
 function checkBehavior
  calls=0;points=zeros(budget,numel(lb));[B,T,I]=SAQ_CSO_AblationVariant(@capture,state,[],N,seed);
  assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(isfinite(T))&&all(diff(T)<=0)&&T(end)==B.Cost);
  assert(abs(f(B.Vector)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
  F=I.FrameworkLog;assert(sum(F(:,5:6),'all')==budget-N && I.TracingEvaluations+I.SeekingEvaluations==budget-N);
  E=I.EvalLog;assert(size(E,1)==budget);
  for round=1:I.Rounds
   records=E(E(:,2)==round,:);actualSeek=records(records(:,3)==2,:);
   pairs=actualSeek(:,[4,5]);assert(size(unique(pairs,'rows'),1)==size(pairs,1));
   if strcmp(I.EvaluationMode,'dense')
    assert(I.QUpdates==0 && I.MaxParentEvaluations<=4);
    if round<I.Rounds,assert(F(round,5)==F(round,3)&&F(round,6)==F(round,4));end
   else,assert(F(round,2)-F(round,1)<=10&&I.MaxParentEvaluations<=2);end
  end
  if any(strcmp(state.ablationVariant,{'Fixed4','Fixed6','RandomSparse-Fixed6','RandomQuota','Dense-NoQ'})),assert(I.QUpdates==0);end
  behavior=behavior+1;
 end
 function value=capture(x)
  calls=calls+1;assert(calls<=budget&&all(x>=lb&x<=ub)&&all(isfinite(x)));points(calls,:)=x;value=f(x);
 end
end
function s=rmfieldIfPresent(s,name)
if isfield(s,name),s=rmfield(s,name);end
end
function points=firstRoundCandidates(pop,lb,ub,seed)
rng(seed,'twister');N=size(pop,1);D=size(pop,2);V=.01*(2*rand(N,D)-1).*(ub-lb);Vmax=.2*(ub-lb);
[~,order]=sort(sum(pop.^2,2));elite=order(1:max(2,ceil(.2*N)));points=zeros(0,D);
for i=1:N
 e=pop(elite(randi(numel(elite))),:);
 if rand<.4
  v=V(i,:)+2*rand(1,D).*(e-pop(i,:));v=.9*V(i,:)+v-V(i,:);v=max(-Vmax,min(Vmax,v));
  points(end+1,:)=max(lb,min(ub,pop(i,:)+v)); %#ok<AGROW>
 else
  for j=2:5
   dims=randperm(D,max(1,round(.2*D)));step=.05*(ub(dims)-lb(dims))/2;
   x=pop(i,:);x(dims)=pop(i,dims)+.25*(e(dims)-pop(i,dims))+step.*(2*rand(1,numel(dims))-1);
   points(end+1,:)=max(lb,min(ub,x)); %#ok<AGROW>
  end
 end
end
end
