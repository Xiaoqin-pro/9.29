function [Best,T,info]=SPSO2011_CEC(f,state,~,N,seed)
% Official SPSO2011 pure-standard native C profile, no extra local search.
% Scalar project objective is still evaluated by MATLAB's unchanged CEC MEX.
clockStart=tic;assert(N==40&&size(state.initialPopulation,1)==N);
assert(state.maxEvaluations>=N&&state.maxEvaluations==floor(state.maxEvaluations));
assert(all(isfinite(state.initialPopulation),'all')&&all(state.initialPopulation>=state.lowerBound&state.initialPopulation<=state.upperBound,'all'));
[vector,cost,T,info]=SPSO2011_native(f,state.initialPopulation,state.lowerBound,state.upperBound,state.maxEvaluations,seed);
Best=struct('Vector',vector,'Cost',cost);
info.Algorithm='SPSO-2011-OfficialC';info.InitialPopulation=state.initialPopulation;
info.InitialCost=T(N);info.Seed=seed;info.Seconds=toc(clockStart);info.Population=N;
info.W=1/(2*log(2));info.C=.5+log(2);info.K=3;info.LinkProbability=1-(1-1/N)^3;
info.RadialDistribution='uniform-radius';info.Topology='adaptive-Bernoulli';info.Controller='native-C';
info.FirstImprovementEvaluation=NaN;j=find(T(N+1:end)<T(N),1);if ~isempty(j),info.FirstImprovementEvaluation=N+j;end
end
