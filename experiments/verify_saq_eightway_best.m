function verify_saq_eightway_best(baseDir,hclpsoDir,hidmsDir,newDir,spsoDir,outDir)
% Independent post-run objective re-evaluation and population regeneration.
% These calls are outside optimization budgets and counted separately.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));
raw=readtable(fullfile(baseDir,'raw_runs.csv'),'TextType','string');raw=raw(raw.Condition~="HCLPSO-Reference",:);
raw.RunDirectory=repmat(string(baseDir),height(raw),1);
for path={hclpsoDir,hidmsDir,newDir,spsoDir}
 z=readtable(fullfile(path{1},'raw_runs.csv'),'TextType','string');z.RunDirectory=repmat(string(path{1}),height(z),1);
 % Schemas can differ by the initial-pool metadata field; keep verification keys only.
 keep={'JobID','FunctionID','Seed','Budget','Dimension','Population','Condition','InitSeed','SearchSeed','FinalCost','RunDirectory'};
 raw=raw(:,keep);z=z(:,keep);raw=[raw;z]; %#ok<AGROW>
end
assert(height(raw)==6960);diffs=zeros(height(raw),1);p0checks=0;calls=0;
for k=1:height(raw)
 r=raw(k,:);d=load(fullfile(r.RunDirectory,'runs',sprintf('job_%04d.mat',r.JobID)),'B','p0');
 rng(r.InitSeed,'twister');pool=-100+200*rand(50,50);
 assert(isequal(d.p0,pool(1:r.Population,:)));p0checks=p0checks+1;
 v=CEC2017Function(d.B.Vector,r.FunctionID);calls=calls+1;diffs(k)=abs(v-d.B.Cost);
 assert(diffs(k)<=1e-8*max(1,abs(d.B.Cost)) && abs(v-r.FinalCost)<=1e-8*max(1,abs(v)));
end
if ~isfolder(outDir),mkdir(outDir);end
raw.IndependentBestDifference=diffs;writetable(raw,fullfile(outDir,'independent_best_rechecks.csv'));
fid=fopen(fullfile(outDir,'independent_matlab_recheck.json'),'w');fprintf(fid,'%s',jsonencode( ...
 struct('Runs',height(raw),'ObjectiveRecheckCallsOutsideBudget',calls, ...
 'RegeneratedInitialPopulations',p0checks,'MaxBestDifference',max(diffs),'Passed',true),PrettyPrint=true));fclose(fid);
fprintf('PASS independent best and regenerated populations %d, extra audit calls%d\n',height(raw),calls);
end
