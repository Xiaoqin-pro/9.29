function test_FCS_rewards
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);addpath(fullfile(root,'archive','fcs_reward_20261012'));
work=fullfile(root,'work','fcs_repair_20261012');calls=0;positions=[];lb=[];ub=[];
policies={'batch','continue','switch','random','success','reverse','q'};pairs=0;
for settings=[7,400;30,600;100,59]'
 D=settings(1);budget=settings(2);lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
 for j=1:numel(policies)
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy',policies{j},'auditDecisions',true);
  calls=0;positions=zeros(budget,D);[B1,T1,I1]=ASE_CSO_FCSQ_CountRepair(@capture,state,[],50,701);oldPositions=positions;oldRng=rng;
  calls=0;positions=zeros(budget,D);[B2,T2,I2]=ASE_CSO_FCSQ(@capture,state,[],50,701);
  assert(isequal(B1,B2) && isequal(T1,T2) && isequal(I1.QTable,I2.QTable) && isequal(I1.DecisionLog,I2.DecisionLog) && isequal(positions,oldPositions) && isequal(oldRng,rng),'Default reward path changed.');pairs=pairs+1;
 end
end
modes={'parent_binary','global_binary','global_binary','global_gain'};bonuses=[1,1,10,10];passed=0;localOnly=0;starterOnly=0;
for k=1:4
 for gamma=[0,.9]
  for budget=[59,400,1000]
   D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy','q','auditDecisions',true,'rewardMode',modes{k},'rewardBonus',bonuses(k),'gainScaleDecay',.1,'gamma',gamma);
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_FCSQ(@capture,state,[],50,701);assert(calls==budget && I.Evaluations==budget && numel(T)==budget && all(diff(T)<=0));
   assert(abs(sum(B.Vector.^2)-B.Cost)<=1e-10*max(1,abs(B.Cost)));L=I.DecisionLog;R=I.RewardLog;assert(size(L,1)==size(R,1));
   if ~isempty(L)
    followFE=L(:,16);assert(isequal(R(:,1),T(followFE-1)) && isequal(R(:,2),T(followFE)));assert(isequal(R(:,3),max(0,R(:,1)-R(:,2))));
    expected=-ones(size(R,1),1);hit=R(:,3)>0;
    if strcmp(modes{k},'parent_binary'),expected(L(:,13)==1)=bonuses(k);
    elseif strcmp(modes{k},'global_binary'),expected(hit)=bonuses(k);
    else
     first=hit & R(:,4)==0;later=hit & R(:,4)>0;expected(first)=bonuses(k);expected(later)=bonuses(k)*min(1,R(later,3)./R(later,4));
    end
    assert(isequal(L(:,14),expected),'Reward includes an unrelated evaluation or wrong target.');
    s=0;
    for n=1:size(R,1)
     assert(R(n,4)==s);g=R(n,3);if g>0,if s==0,s=g;else,s=.9*s+.1*g;end,end;assert(R(n,5)==s);
    end
    assert(sum(I.ConditionalFollowGlobalSuccesses,'all')==sum(hit));
    if ~strcmp(modes{k},'parent_binary')
     only=L(:,13)==1 & ~hit;localOnly=localOnly+sum(only);assert(all(L(only,14)==-1));
     firstFE=L(:,2);witness=(T(firstFE)<T(firstFE-1)) & ~hit;starterOnly=starterOnly+sum(witness);assert(all(L(witness,14)==-1));
    end
   end
   assert(I.ActionMismatchCount==0 && I.QFallbackUpdates==0);passed=passed+1;
  end
 end
end
assert(localOnly>0 && starterOnly>0,'No attribution witnesses were exercised.');
% A real CEC case verifies exact default behavior before reusing the S0 control.
cd(fullfile(root,'data','cec2017'));D=30;lb=-100*ones(1,D);ub=100*ones(1,D);rng(901,'twister');p0=lb+rand(50,D).*(ub-lb);state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',6000,'fcsPolicy','q');f=@(x)CEC2017Function(x,1);
[B1,T1,I1]=ASE_CSO_FCSQ_CountRepair(f,state,[],50,902);oldRng=rng;[B2,T2,I2]=ASE_CSO_FCSQ(f,state,[],50,902);assert(isequal(B1,B2) && isequal(T1,T2) && isequal(I1.QTable,I2.QTable) && isequal(oldRng,rng));pairs=pairs+1;
fid=fopen(fullfile(work,'reward_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('DefaultExactPairs',pairs,'RewardCases',passed,'LocalOnlyWitnesses',localOnly,'StarterOnlyWitnesses',starterOnly,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('FCS reward checks passed: default exact pairs %d, reward cases %d, local-only/starter-only witnesses %d/%d.%c',pairs,passed,localOnly,starterOnly,10);
 function value=capture(x)
  calls=calls+1;assert(all(x>=lb & x<=ub) && all(isfinite(x)));positions(calls,:)=x;value=sum(x.^2);
 end
end
