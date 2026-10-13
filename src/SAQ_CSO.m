function [Best,T,info]=SAQ_CSO(f,state,unused,N,seed)
% SAQ-CSO: Sparse Adaptive-Quota Cat Swarm Optimization.
% Formal paper entry point; mechanics are frozen in the audited candidate.
[Best,T,info]=ASE_CSO_QuotaQ_Candidate(f,state,unused,N,seed);
info.Algorithm='SAQ-CSO';
end
