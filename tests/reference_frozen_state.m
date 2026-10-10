function state=reference_frozen_state(pop,budget)
% Only the historical reference adapter uses experimental option names.
state.initialPopulation=pop;
state.lowerBound=-100*ones(1,size(pop,2));
state.upperBound=100*ones(1,size(pop,2));
state.maxEvaluations=budget;
state.actionMode='fixed2'; state.rlMode='modeAwareV41';
state.seekingMode='range'; state.seekSelection='globalCap2';
state.searchCore='elite'; state.eliteGuidance=true;
state.seekingEliteGuidance=true; state.tracingElitistAcceptance=true;
state.tracingDecay=true; state.virtualTracing=true; state.SMP=5;
state.evaluationQuota=2; state.recoveryEnabled=false;
state.useModePreserving=true;
state.ablation=struct('useCatScreen',true,'useCandidateScreen',true,'useRL',false);
end
