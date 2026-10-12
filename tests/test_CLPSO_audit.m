function test_CLPSO_audit
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);addpath(fullfile(root,'work','clpso_audit_20261012'));
Ds=[7,30];budgets=[50,51,57,100,500];exact=0;authorExact=0;behavior=0;calls=0;points=[];lb=[];ub=[];
for D=Ds
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(100);p0=lb+rand(50,D).*(ub-lb);
 for budget=budgets
  state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'clpsoVariant','legacy');
  calls=0;points=zeros(budget,D);[B0,T0]=CLPSO_CEC(@capture,state,[],50,101);P0=points;R0=rng;
  calls=0;points=zeros(budget,D);[B,T]=CLPSO_CEC_Audit(@capture,state,[],50,101);
  assert(isequal(B0,B)&&isequal(T0,T)&&isequal(P0,points)&&isequal(R0,rng));exact=exact+1;
  for variant={'legacy','paper-boundary','init20'}
   state.clpsoVariant=variant{1};calls=0;points=zeros(budget,D);[B,T,I]=CLPSO_CEC_Audit(@capture,state,[],50,101);
   assert(calls==budget&&numel(T)==budget&&I.Evaluations==budget&&all(isfinite(T))&&all(diff(T)<=0));assert(abs(sum(B.Vector.^2)-B.Cost)<1e-10*max(1,B.Cost));behavior=behavior+1;
  end
  calls=0;points=zeros(budget,D);[Bo,To,Io]=CLPSO_AuthorOracle(@capture,state,[],50,101);Po=points;Ro=rng;
  calls=0;points=zeros(budget,D);[Ba,Ta,Ia]=CLPSO_CEC_AuthorSource(@capture,state,[],50,101);
  flags=[isequal(Bo.Cost,Ba.Cost),isequal(Bo.Vector,Ba.Vector),isequal(To,Ta),isequal(Po,points),isequal(Ro,rng),Io.Iterations==Ia.Iterations,Io.SkippedOutside==Ia.SkippedOutside];
  assert(all(flags),'Author oracle mismatch D%d budget%d flags%s',D,budget,mat2str(flags));authorExact=authorExact+1;
 end
end
% Forced boundary witness: paper boundary skips a move outside; no out-of-domain evaluations.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(102);p0=lb+rand(50,D).*(ub-lb);p0(1,:)=ub;
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1000,'clpsoVariant','paper-boundary');calls=0;points=zeros(1000,D);[~,~,I]=CLPSO_CEC_Audit(@capture,state,[],50,101);assert(I.SkippedOutside>0&&calls==1000);behavior=behavior+1;
old=cd(fullfile(root,'data','cec2017'));restore=onCleanup(@()cd(old));D=30;lb=-100*ones(1,D);ub=100*ones(1,D);rng(103);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',600);
 f=@(x)CEC2017Function(x,fid);[Bo,To]=CLPSO_AuthorOracle(f,state,[],50,104);Ro=rng;[Ba,Ta]=CLPSO_CEC_AuthorSource(f,state,[],50,104);
 assert(isequal(Bo.Cost,Ba.Cost)&&isequal(Bo.Vector,Ba.Vector)&&isequal(To,Ta)&&isequal(Ro,rng));authorExact=authorExact+1;
end
out=fullfile(root,'work','clpso_audit_20261012');fid=fopen(fullfile(out,'behavior_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('LegacyExactPairs',exact,'SourceOracleExactPairs',authorExact,'BehaviorCases',behavior,'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS CLPSO audit legacy%d source%d behavior%d%c',exact,authorExact,behavior,10);
 function value=capture(x)
  calls=calls+1;assert(all(x>=lb&x<=ub)&&all(isfinite(x)));points(calls,:)=x;value=sum(x.^2);
 end
end
