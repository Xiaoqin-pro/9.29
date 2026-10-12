function test_CSO_mode_efficiency
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,1050,1051,1151];policies={'fixed2','fixed4','fixed6','random','phase','epsfixed','q'};exact=0;cases=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(2901);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true);
  for policy=policies
   for oldState={'previous','stagnation'}
    state.modePolicy=policy{1};state.modeState=oldState{1};calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_State(@capture,state,[],50,2902);P0=positions;R0=rng;
    calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Efficiency(@capture,state,[],50,2902);
    assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   end
  end
  for policy={'fixed6','q','effrule','reverseeff'}
   state.modePolicy=policy{1};state.modeState='efficiency';calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Efficiency(@capture,state,[],50,2902);
   assert(calls==budget&&I.Evaluations==budget&&numel(T)==budget&&all(diff(T)<=0)&&all(isfinite(T))&&~I.PendingAtEnd&&I.MaxParentEvaluations<=2);
   L=I.DecisionLog;F=I.ModeFeedbackLog;R=I.RoundLog;S=I.StateLog;
   for k=1:size(F,1)
    hi=10*(k-1);lo=max(1,hi-99);v=zeros(1,4);if hi>=lo,v=sum(R(lo:hi,[3,4,12,13]),1);end
    rates=[v(3)/max(1,v(1)),v(4)/max(1,v(2))];direction=sign(rates(1)-rates(2));
    assert(isequal(F(k,:),[lo,hi,v,rates,direction]));assert(S(k,2)==double(direction>0)&&S(k,3)==L(k,3));
    assert(L(k,3)==1+2*L(k,6)+double(direction>0));
    if strcmp(policy{1},'effrule'),expected=2;if direction>0,expected=3;elseif direction<0,expected=1;end;assert(L(k,4)==expected);end
    if strcmp(policy{1},'reverseeff'),expected=2;if direction>0,expected=1;elseif direction<0,expected=3;end;assert(L(k,4)==expected);end
   end
   U=I.UpdateLog;replay=zeros(6,3);visits=zeros(6,3);
   if strcmp(policy{1},'q'),for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=.9*max(replay(U(k,4),:));end;s=U(k,1);a=U(k,2);replay(s,a)=replay(s,a)+.1*(U(k,3)+future-replay(s,a));visits(s,a)=visits(s,a)+1;end;end;end
   assert(isequal(replay,I.QTable)&&isequal(visits,I.QVisits));cases=cases+1;
  end
 end
end
% Equal-cost landscape witnesses no previous gains/ties and neutral rule action.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',1151,'modeState','efficiency','logTrajectory',true);
for policy={'effrule','reverseeff'}
 state.modePolicy=policy{1};[~,T,I]=ASE_CSO_ModeQ_Efficiency(@(x)1,state,[],50,2902);assert(all(T==1)&&all(I.ModeFeedbackLog(:,9)==0)&&all(I.DecisionLog(:,4)==2));cases=cases+1;
end
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(3001);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 for oldState={'previous','stagnation'}
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','modeState',oldState{1},'logTrajectory',true);f=@(x)CEC2017Function(x,fid);
  [B0,T0,I0]=ASE_CSO_ModeQ_State(f,state,[],50,3002);R0=rng;[B,T,I]=ASE_CSO_ModeQ_Efficiency(f,state,[],50,3002);
  assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
 end
end
out=fullfile(root,'work','cso_mode_efficiency_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('OldExactPairs',exact,'EfficiencyCases',cases,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS mode-efficiency exact%d cases%d%c',exact,cases,10);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
