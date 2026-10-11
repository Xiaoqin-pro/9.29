clc
clear

root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'));
addpath(fullfile(root,'archive','legacy'));
dataDir=fullfile(root,'data','cec2017');
cd(dataDir);

functionIDs=[1 3:30];
seeds=101:103;
dimensions=[30 100];
aseN=50;
maxEvaluations=60000;
lbValue=-100; ubValue=100;
workerCount=4;
batchSize=4;
seedBase=20271004;
methods={'ASE-CSO','L-SHADE-standard'};

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results','cec',['ase_lshade_D30_D100_3seed_' stamp]);
mkdir(outDir);

jobs=struct('FunctionID',{},'Run',{},'Seed',{},'Dimension',{},'Method',{}, ...
    'InitSeed',{},'SearchSeed',{});
count=0;
for D=dimensions
    lshadeN=18*D;
    maxN=max(aseN,lshadeN);
    for fid=functionIDs
        for runID=1:numel(seeds)
            seed=seeds(runID);
            initSeed=seedBase+D*1000+seed;
            searchSeed=initSeed+100000;
            for m=1:numel(methods)
                count=count+1;
                jobs(count)=struct('FunctionID',fid,'Run',runID,'Seed',seed, ...
                    'Dimension',D,'Method',methods{m},'InitSeed',initSeed, ...
                    'SearchSeed',searchSeed);
            end
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
        job=batch(j); D=job.Dimension; fid=job.FunctionID;
        aseN=50; lshadeN=18*D; maxN=max(aseN,lshadeN);
        lb=lbValue*ones(1,D); ub=ubValue*ones(1,D);
        rng(job.InitSeed,'twister');
        population=lb+rand(maxN,D).*(ub-lb);
        if strcmp(job.Method,'ASE-CSO')
            pop0=population(1:aseN,:); populationSize=aseN;
        else
            pop0=population; populationSize=lshadeN;
        end
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',pop0);
        if strcmp(job.Method,'L-SHADE-standard')
            state.lshadeProfile='standard';
        end
        f=@(x)CEC2017Function(x,fid);
        t0=tic; status='ok'; errorID=''; errorMessage=''; info=struct('FinalPopulationSize',populationSize);
        finalCost=NaN; evaluations=NaN; recheck=NaN; recheckDiff=NaN;
        error20=NaN; error60=NaN; error80=NaN; traceFinite=false; traceMonotone=false;
        try
            if strcmp(job.Method,'ASE-CSO')
                [Best,T,info]=ASE_CSO_Lean(f,state,[],aseN,job.SearchSeed);
            else
                [Best,T,info]=LSHADE_CEC(f,state,ceil(maxEvaluations/lshadeN),lshadeN,job.SearchSeed);
            end
            finalCost=Best.Cost; evaluations=info.Evaluations;
            recheck=f(Best.Vector); recheckDiff=abs(recheck-finalCost);
            bias=100*fid;
            error20=T(round(.2*maxEvaluations))-bias;
            error60=T(round(.6*maxEvaluations))-bias;
            error80=T(round(.8*maxEvaluations))-bias;
            traceFinite=all(isfinite(T)); traceMonotone=all(diff(T)<=0);
            if evaluations~=maxEvaluations || numel(T)~=maxEvaluations
                status='invalid'; errorID='FE:Mismatch'; errorMessage='FE or trace length mismatch';
            elseif ~traceFinite || ~traceMonotone
                status='invalid'; errorID='Trace:Invalid'; errorMessage='Trace is not finite and monotone';
            end
            finalPopulationSize=populationSize; if isfield(info,'FinalPopulationSize'), finalPopulationSize=info.FinalPopulationSize; end
        catch err
            status='error'; errorID=err.identifier; errorMessage=err.message; finalPopulationSize=populationSize;
        end
        batchResults{j}=struct('FunctionID',fid,'Function',sprintf('F%02d',fid), ...
            'Run',job.Run,'Seed',job.Seed,'Dimension',D,'Method',job.Method, ...
            'Population',populationSize,'InitialPopulationSize',maxN, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Budget',maxEvaluations,'FinalCost',finalCost,'FinalError',finalCost-100*fid, ...
            'Error20FE',error20,'Error60FE',error60,'Error80FE',error80, ...
            'Evaluations',evaluations,'Seconds',toc(t0), ...
            'BestRecheckCost',recheck,'BestRecheckAbsDiff',recheckDiff, ...
            'TraceFinite',traceFinite,'TraceMonotone',traceMonotone, ...
            'FinalPopulationSize',finalPopulationSize, ...
            'Status',status,'ErrorID',errorID,'ErrorMessage',errorMessage);
    end
    records(first:last)=batchResults;
    writetable(struct2table([records{1:last}]),fullfile(outDir,'raw_runs.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end
writetable(struct2table([records{:}]),fullfile(outDir,'raw_runs.csv'));
fid=fopen(fullfile(outDir,'README.md'),'w');
fprintf(fid,['# ASE-CSO versus standard L-SHADE at D30 and D100\n\n' ...
'D=30 and D=100, 60,000 FE, CEC2017 F1 and F3-F30, seeds 101-103, four MATLAB workers. ' ...
'ASE-CSO uses NP=50 and the trajectory-equivalent lean implementation. ' ...
'L-SHADE uses the standard profile: NP0=18D, NPmin=4, archive ratio 2.6 and memory size 6. ' ...
'All runs use the same function data, bounds, FE budget and seed schedule within each dimension.\n']); fclose(fid);
fprintf('Saved raw results to %s\n',outDir);

function value=fieldOr(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
