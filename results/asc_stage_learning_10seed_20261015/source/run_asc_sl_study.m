function run_asc_sl_study(outDir)
%RUN_ASC_SL_STUDY  Execute the frozen C00/C11/C01/C10 stage-schedule screen.
%
% The run directory is checksum-frozen by prepare_asc_sl_study.py.  The
% preflight reproduces the stored ASC-NoFarness reference record for
% F1/seed3001 in C00 mode and refuses to start if the objective evaluation
% points, the best solution or the trace differ at all.
addpath(fullfile(outDir,'source'),'-begin');cd(fullfile(outDir,'cec_data'));
cfg=jsondecode(fileread(fullfile(outDir,'config.json')));
v=jsondecode(fileread(fullfile(outDir,'validation.json')));
assert(v.Passed);
assert(strcmp(sha(fullfile(outDir,'source','ASC_NoFarness_StageLearning.m')),v.EngineSHA256));
assert(strcmp(sha(fullfile(outDir,'source','ASC_NoFarness.m')),v.OriginalSHA256));
J=readtable(fullfile(outDir,'jobs.csv'),'TextType','char','Delimiter',',', ...
    'ReadVariableNames',true,'VariableNamingRule','preserve');
jobs=table2struct(J);
if ~isfile(fullfile(outDir,'preflight.json'))
    pre=jobs(1);pre.JobID=0;pre.FunctionID=1;pre.Seed=3001;
    pre.InitSeed=261026001;pre.SearchSeed=262026001;pre.CogSeed=262026001+cfg.CogSeedOffset;
    pre.Method='C00';pre.Split='preflight';
    rec=run_asc_sl_job(pre,cfg,outDir);assert(strcmp(rec.Status,'ok'));
    actual=load(fullfile(outDir,'runs',rec.Artifact),'B','T','p0');
    reference=load(cfg.ReferenceArtifact,'B','T','p0');
    assert(isequal(actual.B,reference.B)&&isequal(actual.T,reference.T) ...
        &&isequal(actual.p0,reference.p0),'SLRun:Preflight','C00 did not reproduce the reference.');
    writeJSON(fullfile(outDir,'preflight.json'),struct('Passed',true, ...
        'FullBudgetOriginalParity',true,'ObjectiveCalls',rec.ObjectiveCalls, ...
        'RecheckCalls',rec.PostRunRecheckCalls));
end
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',4);else,assert(pool.NumWorkers==4);end
addAttachedFiles(pool,{fullfile(outDir,'source','ASC_NoFarness_StageLearning.m'), ...
    fullfile(outDir,'source','run_asc_sl_job.m'), ...
    fullfile(outDir,'source','CEC2017Function.m')});
f=parfevalOnAll(pool,@maxNumCompThreads,0,1);wait(f);
records=cell(numel(jobs),1);
for first=1:16:numel(jobs)
    last=min(first+15,numel(jobs));batch=jobs(first:last);result=cell(numel(batch),1);
    parfor j=1:numel(batch)
        name=sprintf('run_%04d_F%02d_seed%d_%s.mat',batch(j).JobID, ...
            batch(j).FunctionID,batch(j).Seed,batch(j).Method);
        path=fullfile(outDir,'runs',name);
        if isfile(path)
            saved=load(path,'job','rec');
            assert(isequal(saved.job,batch(j))&&strcmp(saved.rec.Status,'ok'));
            result{j}=saved.rec;
        else
            result{j}=run_asc_sl_job(batch(j),cfg,outDir);
        end
    end
    records(first:last)=result;
    raw=struct2table([records{1:last}]);
    writetable(raw,fullfile(outDir,'raw_runs.csv'));
    status='running';if any(~strcmp(raw.Status,'ok')),status='failed';end
    writeJSON(fullfile(outDir,'status.json'),struct('Status',status,'Completed',last, ...
        'Total',numel(jobs),'Directory',outDir));
    fprintf('ASC stage-learning %d/%d F%d seed%d %s%c',last,numel(jobs), ...
        batch(end).FunctionID,batch(end).Seed,batch(end).Method,10);
    assert(strcmp(status,'running'),'SLStudy:InvalidRun', ...
        'A counted run failed; retaining all records and stopping.');
end
h=readtable(fullfile(outDir,'prelaunch_hashes.csv'),'TextType','string', ...
    'Delimiter',',','ReadVariableNames',true,'VariableNamingRule','preserve');
for k=1:height(h),assert(strcmp(sha(char(h.Path(k))),char(h.SHA256(k))));end
writeJSON(fullfile(outDir,'status.json'),struct('Status','complete', ...
    'Completed',numel(jobs),'Total',numel(jobs),'SnapshotHashesVerified',true, ...
    'Directory',outDir));
fprintf('COMPLETE ASC STAGE LEARNING %s%c',outDir,10);
end

function writeJSON(path,s)
f=fopen(path,'w');fprintf(f,'%s',jsonencode(s,PrettyPrint=true));fclose(f);
end

function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);
m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);
d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
