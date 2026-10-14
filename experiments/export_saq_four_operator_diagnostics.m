function export_saq_four_operator_diagnostics(outDir)
raw=readtable(fullfile(outDir,'raw_runs.csv'),'TextType','string');assert(all(raw.Status=="ok"));
curves=cell(0,1);states=cell(0,1);runRows=cell(height(raw),1);
for j=1:height(raw)
 r=raw(j,:);s=load(fullfile(outDir,'runs',char(r.Artifact)),'T','info');I=s.info;w=I.WindowLog;
 for state=1:9
  rows=w(w(:,3)==state,:);
  for action=1:4
   chosen=rows(:,10)==action;
   states{end+1}=struct('FunctionID',r.FunctionID,'Seed',r.Seed,'Method',char(r.Method),'State',state,...
    'Phase',ceil(state/3),'Stagnation',mod(state-1,3)+1,'Action',action,'Windows',sum(chosen),...
    'SeekingFE',sum(rows(chosen,18)),'AlternativeFE',sum(rows(chosen,19)),...
    'MeanReward',mean(rows(chosen,16)),'Q',I.QTable(state,action),'QVisits',I.QVisits(state,action));
  end
 end
 runRows{j}=struct('FunctionID',r.FunctionID,'Seed',r.Seed,'Method',char(r.Method),...
  'Windows',size(w,1),'SevereWindows',sum(w(:,7)),'EffectiveImprovementWindows',sum(w(:,16)==10),...
  'ShapedWindows',sum(w(:,16)==.5),'OrdinaryFE',I.OperatorFE(1),'PeerFE',I.OperatorFE(2),...
  'GaussianFE',I.OperatorFE(3),'OppositionFE',I.OperatorFE(4),...
  'OrdinaryGlobalSuccess',I.OperatorGlobalSuccess(1),'PeerGlobalSuccess',I.OperatorGlobalSuccess(2),...
  'GaussianGlobalSuccess',I.OperatorGlobalSuccess(3),'OppositionGlobalSuccess',I.OperatorGlobalSuccess(4));
 nodes=unique([50 round(linspace(1000,numel(s.T),101)) 10000 20000 40000 60000 80000 100000]);nodes=nodes(nodes<=numel(s.T));
 for n=nodes
  curves{end+1}=struct('JobID',double(r.JobID),'FunctionID',double(r.FunctionID),'Seed',double(r.Seed),...
   'Method',char(r.Method),'FE',n,'BestError',s.T(n)-100*double(r.FunctionID));
 end
end
writetable(struct2table([curves{:}]),fullfile(outDir,'convergence_nodes.csv'));
writetable(struct2table([states{:}]),fullfile(outDir,'policy_state_diagnostics.csv'));
writetable(struct2table([runRows{:}]),fullfile(outDir,'run_diagnostics.csv'));
fprintf('Exported four-operator diagnostics for %d runs.%c',height(raw),10);
end
