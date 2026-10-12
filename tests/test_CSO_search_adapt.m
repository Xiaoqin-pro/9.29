function test_CSO_search_adapt
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,400,1051];policies={'fixed2','fixed4','fixed6','q'};exact=0;cases=0;active=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(2701);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true,'modeState','stagnation','stagnationThreshold',100);
  for policy=policies
   state.modePolicy=policy{1};state.adaptSeeking=false;calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_State(@capture,state,[],50,2702);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_SearchAdapt(@capture,state,[],50,2702);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   state.adaptSeeking=true;calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_SearchAdapt(@capture,state,[],50,2702);
   assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(diff(T)<=0)&&~I.PendingAtEnd&&I.MaxParentEvaluations<=2);
   L=I.SearchScaleLog;p=(L(:,1)-50)/max(1,budget-50);assert(isequal(L(:,2),p));
   expected=min(1,3*(1-p));trigger=p>=2/3&L(:,3)>=100;expected(trigger)=1;
   assert(isequal(expected,L(:,4))&&isequal(double(trigger),L(:,5)));
   improvements=find(diff(T)<0)+1;for k=1:size(L,1),past=improvements(improvements<=L(k,1)&improvements>50);last=50;if ~isempty(past),last=past(end);end;assert(L(k,3)==L(k,1)-last);end
   U=I.UpdateLog;replay=zeros(6,3);visits=zeros(6,3);
   if strcmp(policy{1},'q'),for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=.9*max(replay(U(k,4),:));end;s=U(k,1);a=U(k,2);replay(s,a)=replay(s,a)+.1*(U(k,3)+future-replay(s,a));visits(s,a)=visits(s,a)+1;end;end;end
   assert(isequal(replay,I.QTable)&&isequal(visits,I.QVisits));cases=cases+1;
  end
 end
end
% On a flat landscape, every policy receives exactly the same stage/stall scale.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',1051,'modeState','stagnation','stagnationThreshold',100,'adaptSeeking',true,'logTrajectory',true);reference=[];
for policy={'fixed2','fixed4','fixed6','random','phase','epsfixed','q'}
 state.modePolicy=policy{1};[~,T,I]=ASE_CSO_ModeQ_SearchAdapt(@(x)1,state,[],50,2702);
 if isempty(reference),reference=I.SearchScaleLog;else,assert(isequal(reference,I.SearchScaleLog));end
 assert(all(T==1)&&sum(I.SearchScaleLog(:,5))>0);active=active+sum(I.SearchScaleLog(:,5));cases=cases+1;
end
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(2801);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','logTrajectory',true,'modeState','stagnation');f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_State(f,state,[],50,2802);R0=rng;[B,T,I]=ASE_CSO_ModeQ_SearchAdapt(f,state,[],50,2802);
 assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','cso_two_routes_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'shared_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('OriginalExactPairs',exact,'Cases',cases,'RestartRounds',active,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS shared exact%d cases%d restart%d\n',exact,cases,active);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
