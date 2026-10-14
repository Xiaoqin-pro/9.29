function diagnose_SAQ_RestartQ_semantics
% Implementation witnesses only; these are not CEC performance experiments.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
outDir=fullfile(root,'work','saq_route_reassessment_20261014');
D=7;N=50;budget=1250;lb=-100*ones(1,D);ub=100*ones(1,D);
rng(123,'twister');p0=lb+rand(N,D).*(ub-lb);
points=[];flat=false;
baseState=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,...
 'stagnationThreshold',1e12,'policy','base');
methods={'base','fixed','random','q','reference-fixed6'};
allPoints=cell(size(methods));allT=cell(size(methods));records=cell(size(methods));
for k=1:numel(methods)
 points=[];s=baseState;s.policy=methods{k};
 if strcmp(methods{k},'reference-fixed6')
  s.modePolicy='fixed6';s.modeTraceQuota=6;
  [B,T,I]=ASE_CSO_QuotaQ_Compact(@objective,s,[],N,456);
 else
  [B,T,I]=SAQ_CSO_RestartQ(@objective,s,[],N,456);
 end
 allPoints{k}=points;allT{k}=T;
 assert(size(points,1)==budget && I.Evaluations==budget);
 assert(abs(sum(B.Vector.^2)-B.Cost)<1e-9*max(1,abs(B.Cost)));
 restartFE=0;if isfield(I,'RestartEvaluations'),restartFE=I.RestartEvaluations;end
 qUpdates=NaN;if isfield(I,'QUpdates'),qUpdates=I.QUpdates;end
 records{k}=struct('Method',methods{k},'CountedObjectiveCalls',size(points,1),...
  'RestartEvaluations',restartFE,'QUpdates',qUpdates,'FinalCost',B.Cost,...
  'PointRowsDifferentFromBase',sum(any(points~=allPoints{1},2)),...
  'MaxTraceDifferenceFromBase',max(abs(T-allT{1})));
end
writetable(struct2table([records{:}]),fullfile(outDir,'rng_and_reference_witness.csv'));
% A flat objective makes greedy rejection observable without any benchmark.
points=[];flat=true;s=baseState;s.policy='fixed';s.stagnationThreshold=1;
s.diversityThreshold=1;s.restartCooldown=100;
[B,T,I]=SAQ_CSO_RestartQ(@objective,s,[],N,456);
flatRecord=struct('CountedObjectiveCalls',size(points,1),'RestartEvaluations',I.RestartEvaluations,...
 'RestartParentSuccesses',I.RestartParentSuccesses,'RestartGlobalSuccesses',I.RestartSuccesses,...
 'BestUnchanged',isequal(B.Vector,p0(1,:)),'TraceConstant',all(T==1));
assert(flatRecord.RestartEvaluations>0 && flatRecord.RestartParentSuccesses==0);
writetable(struct2table(flatRecord),fullfile(outDir,'flat_objective_witness.csv'));
% Inspect partial terminal quotas with independently counted calls.
flat=false;budgets=[50 51 52 55 59 61];tailRecords=cell(size(budgets));
for k=1:numel(budgets)
 points=[];s=baseState;s.maxEvaluations=budgets(k);s.policy='base';
 [~,T,I]=SAQ_CSO_RestartQ(@objective,s,[],N,456);
 tailRecords{k}=struct('RequestedBudget',budgets(k),'CountedObjectiveCalls',size(points,1),...
  'ReportedFE',I.Evaluations,'TraceLength',numel(T),...
  'ExactBudget',size(points,1)==budgets(k));
end
writetable(struct2table([tailRecords{:}]),fullfile(outDir,'terminal_budget_witness.csv'));
disp(struct2table([records{:}]));disp(struct2table(flatRecord));disp(struct2table([tailRecords{:}]));
disp(['Implementation diagnostics saved: ' outDir]);
 function value=objective(x)
  points(end+1,:)=x;
  if flat,value=1;else,value=sum(x.^2);end
 end
end
