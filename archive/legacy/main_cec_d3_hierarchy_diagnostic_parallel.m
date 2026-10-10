function main_cec_d3_hierarchy_diagnostic_parallel
% Compare Global, legacy DSS and shortlist-then-joint screening on frozen D3.
clc; clear; close all
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))
functionIDs=[3 6 9 12 13 20 28 30];
repeatIDs=141:145; D=30; population=50; maxEvaluations=60000;
seedBase=20271004; lb=-100*ones(1,D); ub=100*ones(1,D);
workerCount=4; batchSize=4;
variants={ ...
 struct('Name','D3-G','Selection','globalCap2'), ...
 struct('Name','D3-DSS-Old','Selection','legacy'), ...
 struct('Name','D3-DSS-Joint','Selection','jointCap2')};
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_d3_hierarchy_diagnostic_' stamp]);
mkdir(resultDir)
jobs=struct('FunctionID',{},'Run',{},'Variant',{},'Selection',{}, ...
 'InitSeed',{},'SearchSeed',{},'InitialPopulation',{}); count=0;
for fid=functionIDs
 for run=repeatIDs
  initSeed=seedBase+run; rng(initSeed,'twister'); initial=lb+rand(population,D).*(ub-lb);
  for v=1:numel(variants)
   count=count+1; spec=variants{v};
   jobs(count)=struct('FunctionID',fid,'Run',run,'Variant',spec.Name, ...
    'Selection',spec.Selection,'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
    'InitialPopulation',initial);
  end
 end
end
pool=gcp('nocreate');
if isempty(pool),parpool('local',workerCount);else,assert(pool.NumWorkers==workerCount);end
records=cell(numel(jobs),1); curves=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
 last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); out=cell(numel(batch),1); batchCurves=cell(numel(batch),1);
 parfor j=1:numel(batch)
  job=batch(j); f=@(x)CEC2017Function(x,job.FunctionID);
  state=struct('lowerBound',lb,'upperBound',ub,'maxEvaluations',maxEvaluations, ...
   'initialPopulation',job.InitialPopulation,'actionMode','fixed2','rlMode','modeAwareV41', ...
   'seekingMode','range','seekSelection',job.Selection,'searchCore','elite', ...
   'eliteGuidance',true,'seekingEliteGuidance',true,'tracingElitistAcceptance',true, ...
   'tracingDecay',true,'virtualTracing',true,'SMP',5,'evaluationQuota',2, ...
   'recoveryEnabled',false,'useModePreserving',true,'feedbackLogging',true, ...
   'ablation',struct('useCatScreen',true,'useCandidateScreen',true,'useRL',false));
  [best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population),population,job.SearchSeed);
  assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
  assert(all(isfinite(T)) && all(diff(T)<=0) && all(info.EvaluationsPerRound==5))
  assert(all(info.ActualTracingEvaluations==2) && all(info.ActualSeekingEvaluations==3))
  if ~isempty(info.SeekingMaxParentEvaluations)
   assert(max(info.SeekingMaxParentEvaluations)<=2)
  end
  bias=100*job.FunctionID;
  out{j}=struct('Function',sprintf('F%02d',job.FunctionID),'FunctionID',job.FunctionID, ...
   'Algorithm',job.Variant,'Selection',job.Selection,'Run',job.Run, ...
   'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'Dimension',D, ...
   'Population',population,'MaxEvaluations',maxEvaluations,'Evaluations',info.Evaluations, ...
   'BestCost',best.Cost,'BestError',max(0,best.Cost-bias),'Seconds',info.Seconds, ...
   'MeanSeekingParentCoverage',mean(info.SeekingParentCoverage), ...
   'MeanSeekingConcentration',mean(info.SeekingConcentration), ...
   'MeanSeekingMaxParentEvaluations',mean(info.SeekingMaxParentEvaluations));
  nodes=(3000:3000:maxEvaluations)';
  batchCurves{j}=table(repmat(job.FunctionID,numel(nodes),1), ...
   repmat({job.Variant},numel(nodes),1),repmat(job.Run,numel(nodes),1),nodes, ...
   max(0,T(nodes)-bias),'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
 end
 for j=1:numel(batch), records{first+j-1}=out{j}; curves{first+j-1}=batchCurves{j}; end
 writetable(struct2table([records{1:last}]),fullfile(resultDir,'raw_runs_checkpoint.csv'))
 writetable(vertcat(curves{1:last}),fullfile(resultDir,'convergence_checkpoint.csv'))
 fprintf('Completed %d/%d runs.\n',last,numel(jobs))
end
writetable(struct2table([records{:}]),fullfile(resultDir,'raw_runs.csv'))
writetable(vertcat(curves{:}),fullfile(resultDir,'convergence.csv'))
raw=struct2table([records{:}]);
summary=groupsummary(raw,{'Function','FunctionID','Algorithm'},'mean', ...
 {'BestError','Seconds','MeanSeekingParentCoverage','MeanSeekingConcentration', ...
  'MeanSeekingMaxParentEvaluations'});
summary.Properties.VariableNames(end-4:end)={'MeanError','MeanSeconds','MeanParentCoverage', ...
 'MeanConcentration','MeanMaxParentEvaluations'};
writetable(summary,fullfile(resultDir,'summary.csv'))
comparison=BuildComparison(summary,variants);
writetable(comparison,fullfile(resultDir,'comparison.csv'))
SaveText(fullfile(resultDir,'README.md'),sprintf([ ...
 '# D3 hierarchy diagnostic\n\n' ...
 '- Functions: F3, F6, F9, F12, F13, F20, F28, F30; D=30; 60,000 FE; five paired seeds 141:145.\n' ...
 '- Variants: D3-G (Global-Cap2), D3-DSS-Old (legacy parent shortlist plus sequential per-parent selection), and D3-DSS-Joint (two-parent shortlist followed by joint Global-Cap2 selection).\n' ...
 '- All variants use frozen D3 search dynamics, Range Seeking, 2 Tracing + 3 Seeking evaluations, no RL and no Recovery.\n' ...
 '- `comparison.csv` reports function means and paired wins. This is a mechanism diagnostic, not a final 29-function validation.\n' ...
 '\nThe K=8 shadow audit found exact equality with Global-Cap2 on all audited rounds; it is therefore omitted as a redundant performance variant.\n']));
fprintf('Saved hierarchy diagnostic: %s\n',resultDir)
end

function comparison=BuildComparison(summary,variants)
f=unique(summary.FunctionID); rows=cell(numel(f),1);
for q=1:numel(f)
 s=summary(summary.FunctionID==f(q),:); rows{q}=struct('Function',s.Function{1},'FunctionID',f(q));
 for v=1:numel(variants)
  x=s(strcmp(s.Algorithm,variants{v}.Name),:); name=matlab.lang.makeValidName(variants{v}.Name);
  rows{q}.([name 'MeanError'])=x.MeanError;
  rows{q}.([name 'MeanSeconds'])=x.MeanSeconds;
 end
end
comparison=struct2table([rows{:}]);
for v=1:numel(variants)
 for w=v+1:numel(variants)
  a=matlab.lang.makeValidName(variants{v}.Name); b=matlab.lang.makeValidName(variants{w}.Name);
  comparison.([a 'WinsVs' b])=comparison.([a 'MeanError'])<comparison.([b 'MeanError']);
  comparison.([b 'WinsVs' a])=comparison.([b 'MeanError'])<comparison.([a 'MeanError']);
 end
end
end

function SaveText(path,text)
file=fopen(path,'w','n','UTF-8'); assert(file>=0); c=onCleanup(@()fclose(file)); %#ok<NASGU>
fprintf(file,'%s',text);
end
