function test_ASE_CSO_regression
% Exact regression only; no parameter search or new scientific comparison.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root); setup_project(true);
[dimensions,functions,seeds]=ndgrid([30 100],[3 6 9 12 13 20 28 30],[101 102]);
pool=gcp('nocreate');
if isempty(pool),parpool('Processes',4);
else,assert(pool.NumWorkers==4,'Use exactly four workers.');end
rows=cell(numel(dimensions),1);
out=fullfile(root,'results','validation',['frozen_regression_' datestr(now,'yyyymmdd_HHMMSS')]);
mkdir(out);
parfor k=1:numel(dimensions)
    rows{k}=compare_frozen_pair(dimensions(k),functions(k),seeds(k),60000,true);
    writetable(rows{k},fullfile(out,sprintf('pair_%02d.csv',k)));
end
report=vertcat(rows{:}); writetable(report,fullfile(out,'regression.csv'));
fprintf('Exact regression passed: %d pairs. Report: %s\n',height(report),out);
end
