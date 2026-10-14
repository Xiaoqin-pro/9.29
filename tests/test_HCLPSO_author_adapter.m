function test_HCLPSO_author_adapter
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);setup_project(true);
addpath(fullfile(root,'work','hclpso_author_audit_20261013'));
checks=0;calls=0;points=[];lb=[];ub=[];f=[];skips=0;
for D=[7,50]
 lb=-100*ones(1,D);ub=100*ones(1,D);rng(931);p0=lb+rand(50,D).*(ub-lb);p0(1,:)=ub;
 for budget=[50,51,67,600,2000]
  for seed=[932,933]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
   f=@(x)sum(x.^2); oneCase;
  end
 end
end
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;
lb=-100*ones(1,D);ub=100*ones(1,D);rng(934);p0=lb+rand(50,D).*(ub-lb);
for fid=[1,6,13]
 for budget=[600,2000]
  for seed=[932,933]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);
   f=@(x)CEC2017Function(x,fid);oneCase;
  end
 end
end
assert(skips>0); out=fullfile(root,'work','hclpso_author_audit_20261013','preflight.json');
fid=fopen(out,'w');fprintf(fid,'%s',jsonencode(struct('SourceOracleExactPairs',checks, ...
 'BoundarySkipWitnesses',skips,'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS HCLPSO author source oracle exact pairs%d skips%d\n',checks,skips);
 function oneCase
  calls=0;points=zeros(budget,D);[Bo,To,Io]=HCLPSO_AuthorOracle(@capture,state,[],50,seed);Po=points;Ro=rng;
  calls=0;points=zeros(budget,D);[B,T,I]=HCLPSO_CEC_AuthorSource(@capture,state,[],50,seed);
  flags=[Bo.Cost==B.Cost,isequal(Bo.Vector,B.Vector),isequal(To,T),isequal(Po,points),isequal(Ro,rng),Io.Iterations==I.Iterations];
  assert(all(flags),'Oracle mismatch D%d budget%d seed%d flags%s',D,budget,seed,mat2str(flags));
  assert(calls==budget && all(diff(T)<=0)&&numel(T)==budget && T(end)==B.Cost);
  assert(abs(f(B.Vector)-B.Cost)<=1e-10*max(1,abs(B.Cost)));
  checks=checks+1;skips=skips+I.SkippedOutside;
 end
 function v=capture(x)
  calls=calls+1;assert(calls<=budget&&all(x>=lb&x<=ub)&&all(isfinite(x)));points(calls,:)=x;v=f(x);
 end
end
