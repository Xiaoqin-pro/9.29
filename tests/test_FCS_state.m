function test_FCS_state
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);addpath(fullfile(root,'archive','fcs_state_20261012'));
[good,cut]=fcs.relativeQuality(9,[1:49,100]',10);assert(good && cut==10);[good,cut]=fcs.relativeQuality(90,[1:49,90]',10);assert(~good && cut==10);
[good,cut]=fcs.relativeQuality(5*9+100,5*[1:49,100]'+100,10);assert(good && cut==150);assert(fcs.relativeQuality(1,ones(50,1),10));assert(~fcs.relativeQuality(1.1,ones(50,1),10));
D=7;budget=1000;lb=-100*ones(1,D);ub=100*ones(1,D);rng(700,'twister');p0=lb+rand(50,D).*(ub-lb);calls=0;positions=[];pairs=0;
policies={'batch','continue','switch','random','success','reverse','q'};
for j=1:numel(policies)
 for mode=1:2
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy',policies{j},'auditDecisions',true);
  if mode==2,state.rewardMode='global_binary';state.gamma=0;end
  calls=0;positions=zeros(budget,D);[B1,T1,I1]=ASE_CSO_FCSQ_RewardBaseline(@capture,state,[],50,701);P1=positions;R1=rng;
  calls=0;positions=zeros(budget,D);[B2,T2,I2]=ASE_CSO_FCSQ(@capture,state,[],50,701);assert(isequal(B1,B2) && isequal(T1,T2) && isequal(I1.QTable,I2.QTable) && isequal(I1.DecisionLog,I2.DecisionLog) && isequal(P1,positions) && isequal(R1,rng));pairs=pairs+1;
 end
end
checks=0;differentSignals=0;
for signalMode={'quality','phase'}
 for policy={'q','signal','reverse_signal','success','reverse','random'}
  for budget=[59,400,1000]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy',policy{1},'auditDecisions',true,'fcsState',signalMode{1},'rewardMode','global_binary','gamma',0);
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_FCSQ(@capture,state,[],50,701);assert(calls==budget && numel(T)==budget && I.Evaluations==budget && all(diff(T)<=0) && I.ActionMismatchCount==0);
   assert(abs(sum(B.Vector.^2)-B.Cost)<=1e-10*max(1,abs(B.Cost)));L=I.DecisionLog;S=I.StateSignalLog;
   if ~isempty(L)
    assert(all(S(:,1)==0 | S(:,1)==1));roundStart=I.RoundLog(L(:,1),2);phase=min(2,floor(3*(roundStart-50)/max(1,budget-50)));assert(isequal(L(:,3),1+2*phase+double(~S(:,1))));
    if strcmp(signalMode{1},'quality'),assert(all(isfinite(S(:,2))) && all(S(:,1)==(L(:,18)<=S(:,2))));differentSignals=differentSignals+sum(S(:,1)~=L(:,6));
    else,assert(all(S(:,1)==1) && all(isnan(S(:,2))));end
    if strcmp(policy{1},'signal'),assert(all(L(:,7)==1+double(~S(:,1))));end
    if strcmp(policy{1},'reverse_signal'),assert(all(L(:,7)==1+S(:,1)));end
    if strcmp(policy{1},'success'),assert(all(L(:,7)==1+double(~L(:,6))));end
    if strcmp(policy{1},'reverse'),assert(all(L(:,7)==1+L(:,6)));end
    if strcmp(policy{1},'q')
     replay=zeros(6,2);for n=1:size(L,1),s=L(n,3);a=L(n,7);reward=L(n,14);replay(s,a)=replay(s,a)+.1*(reward-replay(s,a));end
     assert(isequal(replay,I.QTable),'Immediate value update used unrelated future state.');
    end
   end
   checks=checks+1;
  end
 end
end
assert(differentSignals>0);
% Fixed policies do not depend on the representation bit; cached controls remain valid.
for policy={'batch','continue','switch','random'}
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1000,'fcsPolicy',policy{1},'rewardMode','global_binary','gamma',0);
 [B1,T1]=ASE_CSO_FCSQ(@(x)sum(x.^2),state,[],50,701);R1=rng;state.fcsState='quality';[B2,T2]=ASE_CSO_FCSQ(@(x)sum(x.^2),state,[],50,701);assert(isequal(B1,B2) && isequal(T1,T2) && isequal(R1,rng));pairs=pairs+1;
end
cd(fullfile(root,'data','cec2017'));D=30;lb=-100*ones(1,D);ub=100*ones(1,D);rng(901,'twister');p0=lb+rand(50,D).*(ub-lb);state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',6000,'fcsPolicy','q','rewardMode','global_binary','gamma',0);f=@(x)CEC2017Function(x,1);
[B1,T1,I1]=ASE_CSO_FCSQ_RewardBaseline(f,state,[],50,902);R1=rng;[B2,T2,I2]=ASE_CSO_FCSQ(f,state,[],50,902);assert(isequal(B1,B2) && isequal(T1,T2) && isequal(I1.QTable,I2.QTable) && isequal(R1,rng));pairs=pairs+1;
file=fullfile(root,'work','fcs_repair_20261012','state_checks.json');fid=fopen(file,'w');fprintf(fid,'%s',jsonencode(struct('ExactDefaultAndControlPairs',pairs,'StateCases',checks,'DifferentSignalWitnesses',differentSignals,'HandFixtures',5,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('FCS state checks passed: exact pairs %d, state cases %d, informative-bit witnesses %d.%c',pairs,checks,differentSignals,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x)) && all(x>=lb & x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
