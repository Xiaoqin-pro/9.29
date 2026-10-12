function test_CSO_quota_visit_rate
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(4701);p0=lb+rand(50,D).*(ub-lb);exact=0;cases=0;calls=0;points=[];
for budget=[50,51,151,650,1151]
 for policy={'gateq','gaterandom','gate2','gate4','gateeps6'}
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'modeState','stagnation','stagnationThreshold',100,'modePolicy',policy{1},'episodeFE',100,'rewardBonus',10,'logTrajectory',true,'learningRateMode','fixed');
  calls=0;points=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_EpisodeBonus(@capture,state,[],50,4702);P0=points;R0=rng;
  calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_VisitRate(@capture,state,[],50,4702);assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng)&&isequal(I0.DecisionLog,I.DecisionLog)&&isequal(I0.QTable,I.QTable));exact=exact+1;
  state.learningRateMode='visit';calls=0;points=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_VisitRate(@capture,state,[],50,4702);assert(calls==budget&&all(diff(T)<=0)&&~I.PendingAtEnd);if ~strcmp(policy{1},'gateq'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng));end
  U=I.UpdateLog;Q=zeros(6,3);V=zeros(6,3);rates=zeros(size(U,1),1);
  if strcmp(policy{1},'gateq'),for k=1:size(U,1),if U(k,8),s=U(k,1);a=U(k,2);rates(k)=1/(1+V(s,a));future=0;if ~U(k,5),future=I.DiscountLog(k)*max(Q(U(k,4),:));end;Q(s,a)=Q(s,a)+rates(k)*(U(k,3)+future-Q(s,a));V(s,a)=V(s,a)+1;end;end;end
  assert(isequal(Q,I.QTable)&&isequal(V,I.QVisits)&&isequal(rates,I.RateLog));cases=cases+1;
 end
end
out=fullfile(root,'work','quota_q_visit_rate_20261012');if ~isfolder(out),mkdir(out);end;fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('FixedRateExactPairs',exact,'VisitRateCases',cases,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS visitrate exact%d cases%d%c',exact,cases,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));points(calls,:)=x;value=sum(x.^2);
 end
end
