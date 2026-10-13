function verify_saq_sparse_ablation_best(runDir,outDir)
% Independent objective re-evaluation + exact seed regeneration after complete run.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
assert(isfile(fullfile(runDir,'COMPLETED.json')));
raw=readtable(fullfile(runDir,'raw_runs.csv'),'TextType','string');assert(height(raw)==5220&&all(raw.Status=="ok"));
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));diffs=zeros(height(raw),1);
for k=1:height(raw)
 r=raw(k,:);d=load(fullfile(runDir,'runs',sprintf('job_%04d.mat',r.JobID)),'B','p0');
 rng(r.InitSeed,'twister');p=-100+200*rand(50,50);assert(isequal(d.p0,p));
 value=CEC2017Function(d.B.Vector,r.FunctionID);diffs(k)=abs(value-d.B.Cost);
 assert(diffs(k)<=1e-8*max(1,abs(d.B.Cost))&&abs(value-r.FinalCost)<=1e-8*max(1,abs(value)));
end
if ~isfolder(outDir),mkdir(outDir);end
raw.IndependentBestDifference=diffs;writetable(raw(:,{'JobID','FunctionID','Seed','Condition','FromCache','IndependentBestDifference'}),fullfile(outDir,'independent_best_rechecks.csv'));
fid=fopen(fullfile(outDir,'independent_matlab_recheck.json'),'w');fprintf(fid,'%s',jsonencode( ...
 struct('Passed',true,'QualityRecords',height(raw),'RegeneratedInitialPopulations',height(raw), ...
 'ObjectiveAuditCallsOutsideOptimizationBudget',height(raw),'MaxBestDifference',max(diffs)),PrettyPrint=true));fclose(fid);
fprintf('PASS all5220 best re-evaluations and seed-regenerated populations\n');
end
