function main_cec_d3_parentcap_diagnostic_parallel
% Compare Global-Cap1 and the existing Global-Cap2 on the frozen D3 kernel.
clc; clear; close all
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017')); cd(fullfile(root,'data','cec2017'))
functionIDs=[3 6 9 12 13 20 28 30]; repeatIDs=141:145;
D=30; population=50; maxEvaluations=60000; seedBase=20271004;
lb=-100*ones(1,D); ub=100*ones(1,D); workerCount=4; batchSize=4;
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_d3_parentcap_diagnostic_' stamp]); mkdir(resultDir)
jobs=struct('FunctionID',{},'Run',{},'Variant',{},'Selection',{}, ...
 'InitSeed',{},'SearchSeed',{},'InitialPopulation',{}); count=0;
for fid=functionIDs
 for run=repeatIDs
  initSeed=seedBase+run; rng(initSeed,'twister'); initial=lb+rand(population,D).*(ub-lb);
  for selection={'globalCap1','globalCap2'}
   count=count+1; name=selection{1};
   jobs(count)=struct('FunctionID',fid,'Run',run,'Variant',['D3-' name], ...
    'Selection',name,'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
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
  assert(max(info.SeekingMaxParentEvaluations)<=str2double(job.Selection(end)))
  bias=100*job.FunctionID;
  out{j}=struct('Function',sprintf('F%02d',job.FunctionID),'FunctionID',job.FunctionID, ...
   'Algorithm',job.Variant,'Selection',job.Selection,'Run',job.Run, ...
   'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'Dimension',D, ...
   'Population',population,'MaxEvaluations',maxEvaluations,'Evaluations',info.Evaluations, ...
   'BestCost',best.Cost,'BestError',max(0,best.Cost-bias),'Seconds',info.Seconds, ...
   'MeanParentCoverage',mean(info.SeekingParentCoverage), ...
   'MeanConcentration',mean(info.SeekingConcentration), ...
   'MeanMaxParentEvaluations',mean(info.SeekingMaxParentEvaluations));
  nodes=(3000:3000:maxEvaluations)';
  batchCurves{j}=table(repmat(job.FunctionID,numel(nodes),1), ...
   repmat({job.Variant},numel(nodes),1),repmat(job.Run,numel(nodes),1),nodes, ...
   max(0,T(nodes)-bias),'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
 end
 for j=1:numel(batch),records{first+j-1}=out{j}; curves{first+j-1}=batchCurves{j}; end
 writetable(struct2table([records{1:last}]),fullfile(resultDir,'raw_runs_checkpoint.csv'))
 writetable(vertcat(curves{1:last}),fullfile(resultDir,'convergence_checkpoint.csv'))
 fprintf('Completed %d/%d runs.\n',last,numel(jobs))
end
writetable(struct2table([records{:}]),fullfile(resultDir,'raw_runs.csv'))
writetable(vertcat(curves{:}),fullfile(resultDir,'convergence.csv'))
raw=struct2table([records{:}]); summary=groupsummary(raw,{'Function','FunctionID','Algorithm'},'mean', ...
 {'BestError','Seconds','MeanParentCoverage','MeanConcentration','MeanMaxParentEvaluations'});
summary.Properties.VariableNames(end-4:end)={'MeanError','MeanSeconds','MeanParentCoverage', ...
 'MeanConcentration','MeanMaxParentEvaluations'};
writetable(summary,fullfile(resultDir,'summary.csv'))
comparison=BuildComparison(summary);
writetable(comparison,fullfile(resultDir,'comparison.csv'))
SaveText(fullfile(resultDir,'README.md'),sprintf([ ...
 '# D3 parent-cap diagnostic\n\n' ...
 '- D30, 60,000 FE, F3/F6/F9/F12/F13/F20/F28/F30, seeds 141:145, four workers.\n' ...
 '- D3-GlobalCap2 is the existing baseline; D3-GlobalCap1 changes only the Seeking parent cap from 2 to 1.\n' ...
 '- Both variants use frozen D3 dynamics, Range Seeking, Global 2-near + 1-far candidate ranking, 2 Tracing + 3 Seeking FE, no RL and no Recovery.\n' ...
 '- This diagnostic tests whether the three Seeking evaluations should cover three different parents.\n']));
fprintf('Saved parent-cap diagnostic: %s\n',resultDir)
end

function comparison=BuildComparison(summary)
f=unique(summary.FunctionID); rows=cell(numel(f),1);
for q=1:numel(f)
 s=summary(summary.FunctionID==f(q),:); rows{q}=struct('Function',s.Function{1},'FunctionID',f(q));
 a=s(strcmp(s.Algorithm,'D3-globalCap1'),:); b=s(strcmp(s.Algorithm,'D3-globalCap2'),:);
 rows{q}.Cap1MeanError=a.MeanError; rows{q}.Cap2MeanError=b.MeanError;
 rows{q}.Cap1MeanSeconds=a.MeanSeconds; rows{q}.Cap2MeanSeconds=b.MeanSeconds;
 rows{q}.Cap1Wins=double(a.MeanError<b.MeanError); rows{q}.Cap2Wins=double(b.MeanError<a.MeanError);
end
comparison=struct2table([rows{:}]);
end

function SaveText(path,text)
file=fopen(path,'w','n','UTF-8'); assert(file>=0); c=onCleanup(@()fclose(file)); %#ok<NASGU>
fprintf(file,'%s',text);
end
