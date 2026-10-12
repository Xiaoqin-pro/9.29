function test_CSO_mode_q_reheat
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
Ds=[7,50];budgets=[50,51,149,150,151,400,1051];policies={'fixed2','fixed4','fixed6','q'};exact=0;cases=0;activeSeen=0;calls=0;positions=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(2501);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'auditSimplify',true,'logTrajectory',true,'modeState','stagnation','stagnationThreshold',100);
  for policy=policies
   state.modePolicy=policy{1};state.useReheat=false;calls=0;positions=zeros(budget,D);[B0,T0,I0]=ASE_CSO_ModeQ_State(@capture,state,[],50,2502);P0=positions;R0=rng;
   calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Reheat(@capture,state,[],50,2502);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable)&&isequal(I0.DecisionLog,I.DecisionLog));exact=exact+1;
   for radius={'reset','floor','spread'}
    state.useReheat=true;state.radiusMode=radius{1};calls=0;positions=zeros(budget,D);[B,T,I]=ASE_CSO_ModeQ_Reheat(@capture,state,[],50,2502);
    assert(calls==budget&&I.Evaluations==budget&&all(diff(T)<=0)&&~I.PendingAtEnd&&I.MaxParentEvaluations<=2);
    L=I.DecisionLog;S=I.StateLog;H=I.ReheatLog;R=I.RadiusRoundLog;assert(all(H(:,4)==double(S(:,2)==1&L(:,4)==1)));
    assert(I.ReheatBlocks==sum(H(:,4))&&I.ReheatSeekingEvaluations==sum(H(:,6))&&all(R(:,2:4)>=0,'all'));
    if strcmp(policy{1},'fixed6')||strcmp(policy{1},'fixed4'),assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,positions)&&isequal(R0,rng));end
    if ~isempty(L)
     blocks=sum((I.RoundLog(:,1)'-L(:,2))>=0,1)+1;
     for ri=1:size(R,1)
      bi=blocks(ri);active=H(bi,4);progress=(R(ri,1)-50)/max(1,budget-50);width=.05*(ub-lb)/2*(1-progress);
      if active
       switch radius{1},case 'reset',width=.05*(ub-lb)/2;case 'floor',width=.05*(ub-lb)/2*max(.2,1-progress);case 'spread',width=I.RadiusWidths(bi,:);assert(all(width>=.1*.05*(ub-lb)/2)&all(width<=.05*(ub-lb)/2));end
      end
      assert(max(abs(R(ri,2:4)-[min(width),mean(width),max(width)]))<1e-12);
     end
     activeSeen=activeSeen+sum(H(:,4));
    end
    U=I.UpdateLog;replay=zeros(6,3);visits=zeros(6,3);
    if strcmp(policy{1},'q')
     for k=1:size(U,1),if U(k,8),future=0;if ~U(k,5),future=.9*max(replay(U(k,4),:));end;s=U(k,1);a=U(k,2);replay(s,a)=replay(s,a)+.1*(U(k,3)+future-replay(s,a));visits(s,a)=visits(s,a)+1;end;end
    end
    assert(isequal(replay,I.QTable)&&isequal(visits,I.QVisits));cases=cases+1;
   end
  end
 end
end
% Flat objective guarantees stagnation, exercises triggering and terminal blocks.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);state=struct('initialPopulation',ones(50,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',400,'modePolicy','stallrule','modeState','stagnation','stagnationThreshold',100,'useReheat',true,'logTrajectory',true);
for radius={'reset','floor','spread'}
 state.radiusMode=radius{1};[~,T,I]=ASE_CSO_ModeQ_Reheat(@(x)1,state,[],50,2502);L=I.DecisionLog;S=I.StateLog;
 assert(all(L(:,4)==3-2*S(:,2))&&I.ReheatBlocks>=2&&all(T==1));activeSeen=activeSeen+I.ReheatBlocks;cases=cases+1;
end
assert(activeSeen>0);
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(2601);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600,'modePolicy','q','logTrajectory',true,'modeState','stagnation');f=@(x)CEC2017Function(x,fid);
 [B0,T0,I0]=ASE_CSO_ModeQ_State(f,state,[],50,2602);R0=rng;[B,T,I]=ASE_CSO_ModeQ_Reheat(f,state,[],50,2602);
 assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable,I.QTable));exact=exact+1;
end
out=fullfile(root,'work','cso_mode_q_reheat_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('NoReheatExactPairs',exact,'Cases',cases,'ActiveBlocksChecked',activeSeen,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS reheat exact%d cases%d active%d\n',exact,cases,activeSeen);
 function value=capture(x)
  calls=calls+1;assert(all(isfinite(x))&&all(x>=lb&x<=ub));positions(calls,:)=x;value=sum(x.^2);
 end
end
