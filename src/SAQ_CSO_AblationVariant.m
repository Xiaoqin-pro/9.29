function [Best,T,info]=SAQ_CSO_AblationVariant(f,state,unused,N,seed)
% Frozen-framework variants only, not a new algorithm-development interface.
assert(isfield(state,'ablationVariant'));variant=state.ablationVariant;
state.modeState='stagnation';state.stagnationThreshold=1000;state.episodeFE=100;
state.rewardBonus=10;state.modeReward='binary';state.traceQuotas=[2,4,6];
state.seekCandidateCount=4;state.useSeekingElite=true;
state.evaluationMode='sparse';state.screenPolicy='geometry';state.virtualTracing=true;
switch variant
 case {'Full','RandomScreen-Q','NoVirtual-Q'}
  state.modePolicy='gateq';state.compactGate=true;
  if strcmp(variant,'RandomScreen-Q'),state.screenPolicy='random';end
  if strcmp(variant,'NoVirtual-Q'),state.virtualTracing=false;end
 case 'RandomSparse-Fixed6'
  state.modePolicy='fixed6';state.compactGate=false;state.screenPolicy='random';
 case 'RandomQuota'
  state.modePolicy='gaterandom';state.compactGate=true;
 case 'Fixed4'
  state.modePolicy='fixed4';state.compactGate=false;
 case 'Fixed6'
  state.modePolicy='fixed6';state.compactGate=false;
 case 'Dense-NoQ'
  state.modePolicy='fixed6';state.compactGate=false;state.evaluationMode='dense';
 otherwise,error('Unknown frozen ablation variant: %s',variant);
end
[Best,T,info]=SAQ_CSO_FrameworkAblation(f,state,unused,N,seed);
info.Algorithm=['SAQ-Ablation-' variant];info.AblationVariant=variant;
end
