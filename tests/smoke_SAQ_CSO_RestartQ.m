function smoke_SAQ_CSO_RestartQ
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
for policy={'base','fixed','random','q'}
 D=7;N=50;budget=1200;lb=-100*ones(1,D);ub=100*ones(1,D);rng(123);p0=lb+rand(N,D).*(ub-lb);
 state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'policy',policy{1});
 if strcmp(policy{1},'fixed'), state.stagnationThreshold=10; state.diversityThreshold=1; state.restartCooldown=100; end
 [B,T,I]=SAQ_CSO_RestartQ(@(x)sum(x.^2),state,[],N,456);
 assert(I.Evaluations==budget && numel(T)==budget && all(isfinite(T)) && all(diff(T)<=1e-12));
 assert(abs(sum(B.Vector.^2)-B.Cost)<1e-9);
 fprintf('RestartQ smoke %s FE=%d Q=%d restartFE=%d final=%.6g\n',policy{1},I.Evaluations,I.QUpdates,I.RestartEvaluations,B.Cost);
end
state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'policy','fixed','stagnationThreshold',10,'diversityThreshold',1,'restartCooldown',100);
[~,~,Ifixed]=SAQ_CSO_RestartQ(@(x)sum(x.^2),state,[],N,456);
assert(Ifixed.RestartEvaluations>0 && Ifixed.MeanRestartCandidateDistance>0,'Restart candidates were not written back.');
disp('RestartQ smoke passed.');
end
