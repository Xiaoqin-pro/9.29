function test_SPSO2011_reference
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
work=fullfile(root,'work','spso2011_audit_20261013');addpath(work,fullfile(work,'native_build'));
checks=0;repeats=0;calls=0;points=[];budget=0;lb=[];ub=[];f=[];state=[];seed=0;D=0;
for D=[3,7,50]
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(815);pool=lb+rand(50,D).*(ub-lb);
 for budget=[40,41,57,160,600]
  for seed=[816,817]
   state=struct('initialPopulation',pool(1:40,:),'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
   f=@(x)sum(x.^2);oneCase;
  end
 end
end
% Flat objective and coincident boundary population validate strict ties/topology.
D=7;lb=-100*ones(1,D);ub=100*ones(1,D);budget=200;seed=818;
state=struct('initialPopulation',100*ones(40,D),'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);f=@(x)1;oneCase;
calls=0;points=zeros(budget,D);[~,~,I]=SPSO2011_CEC(@capture,state,[],40,seed);
assert(I.TopologyRebuilds==I.Iterations && I.BoundaryClips>0 && all(diag(eye(40))==1));
% Independent distribution/geometry fixtures for the precise pure defaults.
x=[1,2,3];p=[4,-2,6];l=[-1,5,7];c=.5+log(2);
G=(x+(x+c*(p-x))+(x+c*(l-x)))/3;
assert(max(abs(G-(x+c*(p+l-2*x)/3)))<1e-14);
selfG=(x+(x+c*(p-x)))/2;assert(max(abs(selfG-(x+c*(p-x)/2)))<1e-14);
u=[.01,.25,.5,.99];assert(isequal(u,u.^1)&&any(abs(u-u.^(1/50))>.1));
trial=[-101,103,5];v=[-8,10,2];clipped=max(-100,min(100,trial));hit=trial~=clipped;v(hit)=-.5*v(hit);
assert(isequal(clipped,[-100,100,5])&&isequal(v,[4,-5,2]));
assert(abs(I.W-1/(2*log(2)))<eps && abs(I.LinkProbability-(1-(39/40)^3))<eps);
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);
for fid=[1,3:30],assert(isfinite(CEC2017Function(zeros(1,D),fid)));end
rng(819);pool=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 budget=600;seed=820;state=struct('initialPopulation',pool(1:40,:),'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
 f=@(x)CEC2017Function(x,fid);oneCase;
end
% Full100k native deterministic repeats, not a claim of full MATLAB/C exactness.
for fid=[6,13]
 budget=100000;seed=821;state.maxEvaluations=budget;f=@(x)CEC2017Function(x,fid);
 calls=0;points=zeros(budget,D);[B,T,I]=SPSO2011_CEC(@capture,state,[],40,seed);P1=points;
 calls=0;points=zeros(budget,D);[B2,T2,I2]=SPSO2011_CEC(@capture,state,[],40,seed);
 assert(isequal(B,B2)&&isequal(T,T2)&&isequal(P1,points)&&isequal(I.KissX,I2.KissX));
 assert(calls==budget&&I.Evaluations==budget&&T(end)==B.Cost&&all(diff(T)<=0)&&all(isfinite(T)));
 assert(abs(f(B.Vector)-B.Cost)<=1e-10*max(1,abs(B.Cost)));repeats=repeats+1;
end
fid=fopen(fullfile(work,'preflight.json'),'w');fprintf(fid,'%s',jsonencode(struct( ...
 'CrossLanguageOraclePairs',checks,'Full100kNativeRepeatPairs',repeats,'D50FiniteFunctions',29, ...
 'GravitySelfBranchWitness',true,'RadiusLawWitness',true,'ConfinementVelocityWitness',true, ...
 'StrictTieTopologyWitness',true,'MaxPositionTolerance',1e-8,'PureStandardDefault',true, ...
 'SourceHashes',struct('Wrapper',SourceFileSHA256(fullfile(root,'src','SPSO2011_CEC.m')), ...
 'NativeMex',SourceFileSHA256(fullfile(work,'native_build','SPSO2011_native.mexw64'))),'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS SPSO cross-language%d full100k repeat%d\n',checks,repeats);
 function oneCase
  calls=0;points=zeros(budget,D);[Bo,To,Io]=SPSO2011_MatlabOracle(@capture,state,[],40,seed);Po=points;
  calls=0;points=zeros(budget,D);[B,T,I]=SPSO2011_CEC(@capture,state,[],40,seed);
  delta=max(abs(Po-points),[],'all');td=max(abs(To-T)./max(1,abs(To)));
  flags=[delta<=1e-8,td<=1e-10,abs(Bo.Cost-B.Cost)<=1e-10*max(1,abs(Bo.Cost)), ...
   Io.UniformDraws==I.UniformDraws,Io.TopologyRebuilds==I.TopologyRebuilds,Io.Iterations==I.Iterations];
  assert(all(flags),'Cross-language mismatch D%d budget%d seed%d delta%g flags%s',D,budget,seed,delta,mat2str(flags));
  for name={'KissX','KissY','KissZ','KissW','KissCarry'},assert(Io.(name{1})==I.(name{1}));end
  assert(calls==budget && T(end)==B.Cost&&all(diff(T)<=0));checks=checks+1;
 end
 function value=capture(x)
  calls=calls+1;assert(calls<=budget&&all(x>=lb&x<=ub)&&all(isfinite(x)));points(calls,:)=x;value=f(x);
 end
end
