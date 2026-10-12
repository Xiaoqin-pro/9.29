function test_CSO_quota_compact
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);Ds=[7,50];budgets=[50,51,149,150,151,400,1051];exact=0;compressed=0;cases=0;neutral=0;calls=0;points=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(5101);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  for policy={'gateq','gaterandom','gateeps6','gate4'}
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'modeState','stagnation','stagnationThreshold',100,'modePolicy',policy{1},'episodeFE',100,'rewardBonus',10,'logTrajectory',true,'auditSimplify',true,'compactGate',false,'traceQuotas',[2,4,6]);
   calls=0;points=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_EpisodeBonus(@capture,state,[],50,5102);P0=points;R0=rng;
   calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_QuotaQ_Compact(@capture,state,[],50,5102);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng)&&isequal(I0.DecisionLog,I.DecisionLog)&&isequal(I0.QTable,I.QTable));exact=exact+1;
   state.compactGate=true;calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_QuotaQ_Compact(@capture,state,[],50,5102);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng)&&isequal(I0.QTable([2,4,6],:),I.QTable)&&isequal(I0.QVisits([2,4,6],:),I.QVisits));compressed=compressed+1;
   state.traceQuotas=[4,6];calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_QuotaQ_Compact(@capture,state,[],50,5102);R=rng;L=I.DecisionLog;G=I.GateLog;U=I.UpdateLog;
   assert(calls==budget&&I.Evaluations==budget&&all(isfinite(T))&&all(diff(T)<=0)&&~I.PendingAtEnd&&isequal(size(I.QTable),[3,2]));
   assert(all(L(:,3)==L(:,6)+1)&&all(L(:,5)==2+2*L(:,4))&&all(L(G(:,2)==0,4)==2));
   Q=zeros(3,2);V=zeros(3,2);
   if strcmp(policy{1},'gateq'),for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5)&&G(k+1,2),future=I.DiscountLog(k)*max(Q(U(k,4),:));end;s=U(k,1);a=U(k,2);Q(s,a)=Q(s,a)+.1*(U(k,3)+future-Q(s,a));V(s,a)=V(s,a)+1;end;end;end
   assert(isequal(Q,I.QTable)&&isequal(V,I.QVisits));if strcmp(policy{1},'gate4'),assert(all(L(G(:,2)==1,4)==1));end;cases=cases+1;
   if D==7&&budget==1051
    oldP=points;state.logTrajectory=false;state.auditSimplify=false;calls=0;points=zeros(budget,D);[Bn,Tn,In]=ASE_CSO_QuotaQ_Compact(@capture,state,[],50,5102);assert(isequal(B,Bn)&&isequal(T,Tn)&&isequal(oldP,points)&&isequal(R,rng)&&isequal(I.QTable,In.QTable));neutral=neutral+1;
   end
  end
 end
end
% Persistent flat stagnation guarantees many two-action exploration draws.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',5051,'modeState','stagnation','stagnationThreshold',100,'episodeFE',100,'rewardBonus',10,'logTrajectory',true,'compactGate',true,'traceQuotas',[4,6]);
for policy={'gateq','gaterandom','gateeps6','gate4'}
 state.modePolicy=policy{1};[~,T,I]=ASE_CSO_QuotaQ_Compact(@(x)1,state,[],50,5302);assert(all(T==1)&&I.FreeDecisions>=40&&all(ismember(I.DecisionLog(:,4),[1,2])));
 if ~strcmp(policy{1},'gate4'),assert(all(ismember([1,2],unique(I.DecisionLog(I.GateLog(:,2)==1,4)))));end
 cases=cases+1;
end
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(5201);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','gateq','modeState','stagnation','rewardBonus',10,'episodeFE',100,'logTrajectory',true,'compactGate',true,'traceQuotas',[2,4,6]);f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_EpisodeBonus(f,state,[],50,5202);R0=rng;[B,T,I]=ASE_CSO_QuotaQ_Compact(f,state,[],50,5202);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable([2,4,6],:),I.QTable));compressed=compressed+1;
end
out=fullfile(root,'work','quota_q_compact_20261012');if ~isfolder(out),mkdir(out);end;fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('OldExactPairs',exact,'CompressedExactPairs',compressed,'TwoActionCases',cases,'LogNeutralPairs',neutral,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS compact exact%d compressed%d cases%d neutral%d%c',exact,compressed,cases,neutral,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));points(calls,:)=x;value=sum(x.^2);
 end
end
