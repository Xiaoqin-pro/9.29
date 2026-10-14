function export_saq_seeking_window_diagnostics(outDir)
% Derive probe/window diagnostics from saved immutable run artifacts.
raw=readtable(fullfile(outDir,'raw_runs.csv'),'TextType','string');assert(all(raw.Status=="ok"));
runRows=cell(height(raw),1);probeRows=cell(0,1);curveRows=cell(0,1);stateRows=cell(0,1);
for j=1:height(raw)
 r=raw(j,:);s=load(fullfile(outDir,'runs',char(r.Artifact)),'T','info','record');I=s.info;T=s.T;
 w=I.WindowLog;p=I.EscapeLog;
 if isempty(w),low=0;feasible=0;d0=NaN;dend=NaN;tailEta=NaN;normalRate=NaN;
 else
  low=sum(w(:,7));feasible=sum(w(:,8));d0=w(1,20);dend=w(end,21);
  tail=w(w(:,1)>=.8*double(r.Budget),5);tail=tail(isfinite(tail));tailEta=median(tail);
  normalRate=sum(w(:,23))/max(1,sum(w(:,17:18),'all')-sum(w(:,19)));
 end
 firstProbe=NaN;meanDistance=NaN;meanCostRatio=NaN;worse=0;if ~isempty(p)
  firstProbe=p(1,1);meanDistance=mean(sqrt(sum((I.EscapePoints-I.EscapeBases).^2,2)));
  meanCostRatio=median((p(:,6)-100*double(r.FunctionID))./max(p(:,7)-100*double(r.FunctionID),realmin));
  worse=sum(p(:,6)>p(:,7));
 end
 runRows{j}=struct('JobID',double(r.JobID),'FunctionID',double(r.FunctionID),'Seed',double(r.Seed),...
  'Method',char(r.Method),'Windows',size(w,1),'LowProgressWindows',low,'ProbeFeasibleWindows',feasible,...
  'EscapeEvaluations',size(p,1),'FirstProbeFE',firstProbe,'WorseThanParentProbes',worse,...
  'MeanProbeDistance',meanDistance,'MedianProbeOverParentError',meanCostRatio,...
  'RealDiversityStart',d0,'RealDiversityEnd',dend,'MedianTailProgressRatio',tailEta,'NormalParentSuccessRate',normalRate);
 for stateId=1:6
  rows=w(w(:,3)==stateId,:);eligible=rows(:,8)>0;normal=eligible & rows(:,10)==1;probe=eligible & rows(:,10)==2;
  stateRows{end+1}=struct('JobID',double(r.JobID),'FunctionID',double(r.FunctionID),'Seed',double(r.Seed),'Method',char(r.Method),...
   'State',stateId,'Phase',ceil(stateId/2),'LowProgress',double(mod(stateId,2)==0),'Windows',size(rows,1),...
   'FeasibleWindows',sum(eligible),'NormalChoicesWhenFeasible',sum(normal),'ProbeChoicesWhenFeasible',sum(probe),...
   'ProbeRateWhenFeasible',sum(probe)/max(1,sum(eligible)),'NormalRewardMean',mean(rows(normal,16)),...
   'ProbeRewardMean',mean(rows(probe,16)),'NormalQ',I.QTable(stateId,1),'ProbeQ',I.QTable(stateId,2),...
   'NormalQVisits',I.QVisits(stateId,1),'ProbeQVisits',I.QVisits(stateId,2)); %#ok<AGROW>
 end
 nodes=unique([50 round(linspace(1000,numel(T),101)) 10000 20000 40000 60000 80000 100000]);nodes=nodes(nodes<=numel(T));
 for n=nodes
  curveRows{end+1}=struct('JobID',double(r.JobID),'FunctionID',double(r.FunctionID),'Seed',double(r.Seed),...
   'Method',char(r.Method),'FE',n,'BestError',T(n)-100*double(r.FunctionID)); %#ok<AGROW>
 end
end
writetable(struct2table([stateRows{:}]),fullfile(outDir,'policy_state_diagnostics.csv'));
writetable(struct2table([curveRows{:}]),fullfile(outDir,'convergence_nodes.csv'));
writetable(struct2table([runRows{:}]),fullfile(outDir,'run_diagnostics.csv'));
if ~isempty(probeRows),writetable(struct2table([probeRows{:}]),fullfile(outDir,'probe_diagnostics.csv'));end
fprintf('Exported diagnostics for %d runs, %d probes.%c',height(raw),numel(probeRows),10);
end
