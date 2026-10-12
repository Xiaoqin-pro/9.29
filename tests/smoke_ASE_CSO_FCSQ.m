function smoke_ASE_CSO_FCSQ
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
policies={'batch','continue','switch','random','q'};
for p=1:numel(policies)
    D=7; N=50; budget=400; lb=-100*ones(1,D); ub=100*ones(1,D);
    rng(700,'twister'); pop0=lb+rand(N,D).*(ub-lb);
    state=struct('initialPopulation',pop0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'fcsPolicy',policies{p});
    [Best,T,info]=ASE_CSO_FCSQ(@(x)sum(x.^2),state,[],N,701);
    assert(info.Evaluations==budget,'FE mismatch for %s',policies{p});
    assert(numel(T)==budget,'Trace length mismatch for %s',policies{p});
    assert(all(isfinite(T)) && all(diff(T)<=1e-12),'Trace invalid for %s',policies{p});
    assert(abs(sum(Best.Vector.^2)-Best.Cost)<1e-10,'Best recheck mismatch for %s',policies{p});
    fprintf('FCS smoke passed: %s, FE=%d, second-success=%d, final=%.6g\n',policies{p},info.Evaluations,info.SecondEvaluationSuccesses,Best.Cost);
end
fprintf('FCS smoke: all policies passed.\n');
end
