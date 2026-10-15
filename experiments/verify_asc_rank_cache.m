function verify_asc_rank_cache(outDir)
cd(fullfile(outDir,'cec_data'));addpath(fullfile(outDir,'source'),'-begin');
rows=readtable(fullfile(outDir,'cache','cached_runs.csv'),'TextType','string');assert(height(rows)==5220);
initMax=zeros(height(rows),1);bestMax=initMax;calls=0;
for k=1:height(rows)
 r=rows(k,:);d=load(char(r.ArtifactPath),'p0','B','T','job','I');
 assert(d.job.FunctionID==r.FunctionID&&d.job.Seed==r.Seed&&d.job.SearchSeed==r.SearchSeed);
 assert(d.job.Budget==100000&&d.job.Population==r.Population&&string(d.job.Condition)==r.Method);
 rng(double(r.InitSeed),'twister');p=-100+200*rand(50,50);assert(isequal(d.p0,p(1:r.Population,:)));
 assert(numel(d.T)==100000&&all(isfinite(d.T))&&all(diff(d.T)<=0)&&d.I.Evaluations==100000);
 initial=inf;
 for j=1:r.Population
  v=CEC2017Function(d.p0(j,:),r.FunctionID);calls=calls+1;initial=min(initial,v);
  initMax(k)=max(initMax(k),abs(initial-d.T(j)));assert(abs(initial-d.T(j))<=1e-10*max(1,abs(initial)));
 end
 v=CEC2017Function(d.B.Vector,r.FunctionID);calls=calls+1;bestMax(k)=abs(v-d.B.Cost);
 assert(bestMax(k)<=1e-10*max(1,abs(v))&&abs(v-r.FinalCost)<=1e-10*max(1,abs(v)));
 if mod(k,500)==0,fprintf('Reference rechecks %d/%d\n',k,height(rows));end
end
rows.InitialTraceMaxDiff=initMax;rows.BestRecheckDiff=bestMax;
writetable(rows,fullfile(outDir,'cache','cache_rechecks.csv'));
report=struct('Passed',true,'Runs',height(rows),'RebuiltInitialPopulations',height(rows),'AuditObjectiveCalls',calls,...
 'MaxInitialDiff',max(initMax),'MaxBestDiff',max(bestMax),'NewOptimizationRuns',0);
f=fopen(fullfile(outDir,'cache','cache_validation.json'),'w');fprintf(f,'%s',jsonencode(report,PrettyPrint=true));fclose(f);
fprintf('All %d cached baselines passed; extra audit calls %d.\n',height(rows),calls);
end
