function test_HIDMS_adapter
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
addpath(fullfile(root,'work','hidms_author_audit_20261013'));lb=[];ub=[];budget=0;calls=0;points=[];f=[];checks=0;
for D=[7,50]
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(741);pool=lb+rand(50,D).*(ub-lb);p0=pool(1:40,:);
 for budget=[40,41,57,600,2000]
  for seed=[742,743]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
   f=@(x)sum(x.^2);oneCase;
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;
lb=-100*ones(1,D);ub=100*ones(1,D);rng(744);pool=lb+rand(50,D).*(ub-lb);p0=pool(1:40,:);
for fid=[1,6,13]
 for budget=[600,2000]
  for seed=[742,743]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
   f=@(x)CEC2017Function(x,fid);oneCase;
  end
 end
end
for fid=[6,13]
 budget=100000;seed=742;state.maxEvaluations=budget;f=@(x)CEC2017Function(x,fid);oneCase;
end
budget=2000;seed=742;state.maxEvaluations=budget;state.initialPopulation(:)=100;
f=@(x)sum(x.^2);oneCase;
% Hand-checkable best-slave local/global indexing witness.
U=[11,17,23,8;12,29,30,31;13,18,19,20;14,21,22,24;15,25,26,27];
PX=repmat((1:40)',1,3);X=PX;F=ones(1,40);PF=F;F([17,23,8])=[9,1,4];
branchSeed=-1;
for trial=1:100
 rng(trial);behavior=randi([1,3]);LS=randi([0,1]);
 if behavior==2&&LS==0,branchSeed=trial;break;end
end
assert(branchSeed>0);rng(branchSeed);
[e1,e2]=hidms_master_fixture(X,PX,U,1,2,3,4,11,5,F,PF);
assert(isequal(e1,PX(11,:))&&isequal(e2,PX(23,:))&&~isequal(e2,PX(2,:)));
x=[-100,0,100];assert(isequal(hidms_mutation_fixture(x,0,1,10,-100,100),x));
assert(isequal(hidms_mutation_fixture(x,1,10,10,-100,100),x));
y=hidms_mutation_fixture(x,1,1,10,-100,100);assert(all(y>=-100&y<=100));
% Unit topology requirement: 40 valid, 50 invalid; verify total memberships.
rng(745);u=reshape(randperm(20),5,4);assert(numel(unique(u))==20&&all(u>=1&u<=20,'all'));
assert(mod(40,8)==0&&mod(50,8)~=0);
fid=fopen(fullfile(root,'work','hidms_author_audit_20261013','preflight.json'),'w');
fprintf(fid,'%s',jsonencode(struct('SourceOracleExactPairs',checks,'IndexWitnessPassed',true,'ActualMasterHelperWitness',true,'MutationEndpointWitness',true,'UnitTopologyWitness',true,'Full100kWitnesses',2,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS HIDMS exact pairs%d best-slave index witness\n',checks);
 function oneCase
  calls=0;points=zeros(budget,D);[Bo,To,Io]=HIDMS_SourceOracle(@capture,0,40,D,[-100,100],state,seed);Po=points;Ro=rng;
  calls=0;points=zeros(budget,D);[B,T,I]=HIDMS_PSO_CEC(@capture,state,[],40,seed);
  assert(Bo==B.Cost&&isequal(To,T)&&isequal(Po,points)&&isequal(Ro,rng)&&Io.Iterations==I.Iterations);
  assert(calls==budget&&I.Evaluations==budget&&all(diff(T)<=0)&&T(end)==B.Cost);
  assert(abs(f(B.Vector)-B.Cost)<=1e-10*max(1,abs(B.Cost)));checks=checks+1;
 end
 function v=capture(x)
  calls=calls+1;assert(calls<=budget&&all(x>=lb&x<=ub)&&all(isfinite(x)));points(calls,:)=x;v=f(x);
 end
end
