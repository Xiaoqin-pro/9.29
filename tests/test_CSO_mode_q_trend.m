function test_CSO_mode_q_trend
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(2001);p0=lb+rand(50,D).*(ub-lb);exact=0;
for fid=[1,6,13]
 for policy={'fixed2','fixed4','fixed6','q'}
  for budget=[50,151,600]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'modePolicy',policy{1},'logTrajectory',true);
   f=@(x)CEC2017Function(x,fid);[B0,T0,I0]=ASE_CSO_ModeQ(f,state,[],50,2002);R0=rng;[B,T,I]=ASE_CSO_ModeQ_Trend(f,state,[],50,2002);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.DecisionLog,I.DecisionLog)&&isequal(I0.QTable,I.QTable));
   L=I.TrendLog;assert(size(L,1)==ceil((budget-50)/100)+1 && all(isfinite(L),'all') && all(L(:,2:3)>=0,'all'));
   assert(abs(L(1,2)-sqrt(mean(((p0-mean(p0,1))./(ub-lb)).^2,'all')))<1e-15);
   assert(isequal(L(:,6),T(L(:,1))));
   improvements=find(diff(T)<0)+1;for k=1:size(L,1),past=improvements(improvements<=L(k,1)&improvements>50);last=50;if ~isempty(past),last=past(end);end;assert(L(k,5)==L(k,1)-last);end
   exact=exact+1;
  end
 end
end
out=fullfile(root,'work','cso_mode_q_trend_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'logging_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('ExactPairs',exact,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS trajectory-neutral %d pairs\n',exact);
end
