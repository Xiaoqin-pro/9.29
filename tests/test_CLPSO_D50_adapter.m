function test_CLPSO_D50_adapter
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);addpath(fullfile(root,'work','clpso_audit_20261012'));old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);pairs=0;
for N=[40,50]
 rng(4001);p0=lb+rand(N,D).*(ub-lb);
 for budget=[N,N+1,N+17,600]
  for fid=[1,6,13]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget);f=@(x)CEC2017Function(x,fid);
   [Bo,To,Io]=CLPSO_AuthorOracle(f,state,[],N,4002);Ro=rng;[B,T,I]=CLPSO_CEC_AuthorSource(f,state,[],N,4002);
   assert(isequal(Bo.Vector,B.Vector)&&Bo.Cost==B.Cost&&isequal(To,T)&&isequal(Ro,rng)&&Io.Iterations==I.Iterations&&Io.SkippedOutside==I.SkippedOutside);pairs=pairs+1;
  end
 end
end
% Ensure all requested D50 objectives are finite at the same deterministic point.
values=zeros(29,1);fids=[1,3:30];for k=1:numel(fids),values(k)=CEC2017Function(zeros(1,D),fids(k));end;assert(all(isfinite(values)));
out=fullfile(root,'work','clpso_full_20261012');if ~isfolder(out),mkdir(out);end
fid=fopen(fullfile(out,'preflight.json'),'w');fprintf(fid,'%s',jsonencode(struct('D50SourceOracleExactPairs',pairs,'D50FiniteFunctions',numel(fids),'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS D50 author adapter exact%d finitefunctions%d%c',pairs,numel(fids),10);
end
