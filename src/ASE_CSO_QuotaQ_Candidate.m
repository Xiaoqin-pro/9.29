function [Best,T,info]=ASE_CSO_QuotaQ_Candidate(f,state,unused,N,seed)
% Small research candidate: one stall trigger, three phases x three true-FE quotas.
% Healthy: fixed6. Stall >=1000 true FE: Q chooses 2T8S/4T6S/6T4S for 100 FE.
% True global improvement +10, otherwise -1; alpha=.1, gamma=.9, epsilon=.1.
% This pins the verified three-action compressed implementation, not a proven paper result.
state.modePolicy='gateq';state.modeState='stagnation';state.stagnationThreshold=1000;
state.episodeFE=100;state.rewardBonus=10;state.modeReward='binary';
state.compactGate=true;state.traceQuotas=[2,4,6];
state.seekCandidateCount=4;state.useSeekingElite=true;
[Best,T,info]=ASE_CSO_QuotaQ_Compact(f,state,unused,N,seed);
info.Algorithm='ASE-CSO-QuotaQ-Candidate';
end
