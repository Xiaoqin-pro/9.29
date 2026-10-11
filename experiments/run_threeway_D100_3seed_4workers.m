clc
clear

root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'));
addpath(fullfile(root,'archive','legacy'));
dataDir=fullfile(root,'data','cec2017');
cd(dataDir);

functionIDs=[1 3:30];
seeds=101:103;
D=100;
N=50;
NRLN=40;
maxEvaluations=60000;
lb=-100*ones(1,D);
ub=100*ones(1,D);
workerCount=4;
batchSize=4;
seedBase=20271004;
methods={'ASE-CSO','CLPSO','NRLPSO-PaperAligned'};

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results','cec',['threeway_D100_3seed_' stamp]);
mkdir(outDir);

for fid=functionIDs
    assert(isfile(fullfile(dataDir,'input_data',sprintf('M_%d_D100.txt',fid))));
    if (fid>=11 && fid<=20) || fid>=29
        assert(isfile(fullfile(dataDir,'input_data',sprintf('shuffle_data_%d_D100.txt',fid))));
    end
end

jobs=struct('FunctionID',{},'Run',{},'Method',{},'InitSeed',{},'SearchSeed',{}, ...
    'InitialPopulation',{},'InitialPopulation40',{});
count=0;
for fid=functionIDs
    for runID=1:numel(seeds)
        seed=seeds(runID);
        initSeed=seedBase+seed;
        searchSeed=initSeed+100000;
        rng(initSeed,'twister');
        pop50=lb+rand(N,D).*(ub-lb);
        for m=1:numel(methods)
            count=count+1;
            jobs(count)=struct('FunctionID',fid,'Run',runID,'Method',methods{m}, ...
                'InitSeed',initSeed,'SearchSeed',searchSeed, ...
                'InitialPopulation',pop50,'InitialPopulation40',pop50(1:NRLN,:));
        end
    end
end

pool=gcp('nocreate');
if isempty(pool)
    parpool('local',workerCount);
elseif pool.NumWorkers~=workerCount
    delete(pool); parpool('local',workerCount);
end

records=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        fid=job.FunctionID;
        f=@(x)CEC2017Function(x,fid);
        if strcmp(job.Method,'NRLPSO-PaperAligned')
            pop0=job.InitialPopulation40; popN=NRLN;
        else
            pop0=job.InitialPopulation; popN=N;
        end
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',pop0);
        t0=tic;
        status='ok'; errorID=''; errorMessage='';
        try
            switch job.Method
                case 'ASE-CSO'
                    [Best,T,info]=ASE_CSO_Lean(f,state,[],N,job.SearchSeed);
                case 'CLPSO'
                    [Best,T,info]=CLPSO_CEC(f,state,ceil(maxEvaluations/popN),popN,job.SearchSeed);
                otherwise
                    [Best,T,info]=NRLPSO_CEC_PaperAligned(f,state,[],job.SearchSeed);
            end
            finalCost=Best.Cost; evaluations=info.Evaluations;
            recheck=f(Best.Vector);
            recheckDiff=abs(recheck-finalCost);
            mutationEvaluations=0; if isfield(info,'MutationEvaluations'), mutationEvaluations=info.MutationEvaluations; end
            mutationCalls=0; if isfield(info,'MutationCalls'), mutationCalls=info.MutationCalls; end
            mutationOutOfBounds=0; if isfield(info,'MutationOutOfBounds'), mutationOutOfBounds=info.MutationOutOfBounds; end
            objectiveCalls=NaN; if isfield(info,'ObjectiveCalls'), objectiveCalls=info.ObjectiveCalls; end
            traceFinite=all(isfinite(T));
            traceMonotone=all(diff(T)<=0);
            if evaluations~=maxEvaluations || numel(T)~=maxEvaluations
                status='invalid'; errorID='FE:Mismatch'; errorMessage='FE or trace length mismatch';
            elseif ~traceFinite || ~traceMonotone
                status='invalid'; errorID='Trace:Invalid'; errorMessage='Trace is not finite and monotone';
            end
        catch err
            finalCost=NaN; evaluations=NaN; recheck=NaN; recheckDiff=NaN;
            mutationEvaluations=NaN; mutationCalls=NaN; mutationOutOfBounds=NaN;
            objectiveCalls=NaN; traceFinite=false; traceMonotone=false;
            status='error'; errorID=err.identifier; errorMessage=err.message;
        end
        batchResults{j}=struct('FunctionID',fid,'Function',sprintf('F%02d',fid), ...
            'Run',job.Run,'Seed',seeds(job.Run),'Method',job.Method, ...
            'Dimension',D,'Budget',maxEvaluations,'Population',popN, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'FinalCost',finalCost,'FinalError',finalCost-100*fid, ...
            'Evaluations',evaluations,'Seconds',toc(t0), ...
            'ObjectiveCalls',objectiveCalls,'MutationEvaluations',mutationEvaluations, ...
            'MutationCalls',mutationCalls,'MutationOutOfBounds',mutationOutOfBounds, ...
            'BestRecheckCost',recheck,'BestRecheckAbsDiff',recheckDiff, ...
            'TraceFinite',traceFinite,'TraceMonotone',traceMonotone, ...
            'Status',status,'ErrorID',errorID,'ErrorMessage',errorMessage);
    end
    records(first:last)=batchResults;
    filled=[records{1:last}];
    writetable(struct2table(filled),fullfile(outDir,'raw_runs.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

raw=struct2table([records{:}]);
writetable(raw,fullfile(outDir,'raw_runs.csv'));
fid=fopen(fullfile(outDir,'README.md'),'w');
fprintf(fid,['# Three-algorithm CEC2017 D100 comparison\n\n' ...
'D=100, 60,000 FE, functions F1 and F3-F30, seeds 101-103, four MATLAB workers. ' ...
'ASE-CSO and CLPSO use NP=50. Paper-aligned NRLPSO uses NP=40 and receives the shared 40-point prefix of each 50-point initial population. ' ...
'ASE-CSO uses the trajectory-equivalent lean runtime implementation. NRLPSO is a paper-aligned independent reproduction, not an official author release.\n\n' ...
'`raw_runs.csv` is written after every batch and contains one row per run. Summary tables are generated after completion.\n']);
fclose(fid);
fprintf('Saved raw results to %s\n',outDir);

function value=fieldOr(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
