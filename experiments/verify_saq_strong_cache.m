function verify_saq_strong_cache
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'archive','legacy'));
out=fullfile(root,'work','saq_strong_confirmation_cache_20261014');
pre=jsondecode(fileread(fullfile(out,'cache_python_validation.json')));assert(pre.Passed);
raw=readtable(fullfile(out,'cached_runs.csv'),'TextType','string');assert(height(raw)==1740);
old=pwd;cleanup=onCleanup(@()cd(old));cd(fullfile(root,'data','cec2017')); %#ok<NASGU>
bestDiff=zeros(height(raw),1);initDiff=zeros(height(raw),1);calls=0;initialChecks=0;
for k=1:height(raw)
 r=raw(k,:);saved=load(char(r.ArtifactPath),'p0','B','T');
 rng(r.InitSeed,'twister');pool=-100+200*rand(50,50);
 assert(isequal(saved.p0,pool(1:r.Population,:)),'Cached initialization changed.');
 initialBest=inf;
 for i=1:r.Population
  value=CEC2017Function(saved.p0(i,:),r.FunctionID);calls=calls+1;
  initialBest=min(initialBest,value);diffValue=abs(initialBest-saved.T(i));initDiff(k)=max(initDiff(k),diffValue);
  assert(diffValue<=1e-10*max(1,abs(initialBest)),'Cached initial trace mismatches current CEC objective.');
 end
 value=CEC2017Function(saved.B.Vector,r.FunctionID);calls=calls+1;bestDiff(k)=abs(value-saved.B.Cost);
 assert(bestDiff(k)<=1e-10*max(1,abs(value)) && abs(value-r.FinalCost)<=1e-10*max(1,abs(value)),'Cached best mismatches current CEC objective.');
 initialChecks=initialChecks+1;
 if mod(k,300)==0,fprintf('Strong cache MATLAB objective checks %d/1740%c',k,10);end
end
raw.InitialTraceMaxAbsDiff=initDiff;raw.IndependentBestAbsDiff=bestDiff;
writetable(raw,fullfile(out,'cache_matlab_rechecks.csv'));
report=struct('Passed',true,'Runs',height(raw),'RegeneratedInitialPopulations',initialChecks,...
 'PostRunAuditObjectiveCalls',calls,'NewOptimizationCalls',0,'MaxInitialTraceDifference',max(initDiff),'MaxBestDifference',max(bestDiff));
f=fopen(fullfile(out,'cache_matlab_validation.json'),'w');fprintf(f,'%s',jsonencode(report,PrettyPrint=true));fclose(f);
fprintf('Strong cache validated: 1740 runs, %d audit objective calls, zero new optimization calls.%c',calls,10);
end
