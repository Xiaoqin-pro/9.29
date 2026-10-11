clc
clear
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src')); addpath(fullfile(root,'archive','legacy'));
dataDir=fullfile(root,'data','cec2017'); cd(dataDir);

% Frozen validation of the simplest candidate suggested by the 2x2 pilot:
% regenerate proposals each round and use marginal coverage for the Seeking
% candidate set.  No parameters are retuned here.
functionIDs=[1 3:30]; seeds=301:305;
D=30; N=50; maxEvaluations=60000; lb=-100; ub=100;
workerCount=4; batchSize=4;
methods={'B10-Reference','TPL-NoReuse-Marginal'};
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results','cec',['tpl_marginal_validation_' stamp]); mkdir(outDir);
seedBase=20271030; jobs=struct('FunctionID',{},'Run',{},'Seed',{},'Method',{},'InitSeed',{},'SearchSeed',{}); c=0;
for fid=functionIDs
    for r=1:numel(seeds)
        seed=seeds(r); initSeed=seedBase+fid*1000+seed; searchSeed=initSeed+100000;
        for m=1:numel(methods)
            c=c+1; jobs(c)=struct('FunctionID',fid,'Run',r,'Seed',seed,'Method',methods{m},...
                'InitSeed',initSeed,'SearchSeed',searchSeed);
        end
    end
end
pool=gcp('nocreate');
if isempty(pool), parpool('local',workerCount);
elseif pool.NumWorkers~=workerCount, delete(pool); parpool('local',workerCount); end
records=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs)); batch=jobs(first:last); batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j); rng(job.InitSeed,'twister'); pop0=lb+rand(N,D).*(ub-lb);
        state=struct('lowerBound',lb*ones(1,D),'upperBound',ub*ones(1,D),...
            'maxEvaluations',maxEvaluations,'initialPopulation',pop0);
        f=@(x)CEC2017Function(x,job.FunctionID); status='ok'; errID=''; errMsg='';
        finalCost=NaN; evals=NaN; secs=NaN; error20=NaN; error60=NaN; error80=NaN;
        recheckDiff=NaN; traceFinite=false; traceMonotone=false; info=struct(); bias=100*job.FunctionID; t0=tic;
        try
            if strcmp(job.Method,'B10-Reference')
                [Best,T,info]=ASE_CSO_Lean_B10(f,state,[],N,job.SearchSeed);
            else
                state.tplPolicy='fixed'; state.reuseProposals=false; state.marginalCoverage=true;
                [Best,T,info]=ASE_CSO_TPL(f,state,[],N,job.SearchSeed);
            end
            secs=toc(t0); finalCost=Best.Cost; evals=info.Evaluations;
            error20=T(round(.2*maxEvaluations))-bias; error60=T(round(.6*maxEvaluations))-bias; error80=T(round(.8*maxEvaluations))-bias;
            recheckDiff=abs(f(Best.Vector)-finalCost); traceFinite=all(isfinite(T)); traceMonotone=all(diff(T)<=0);
            if evals~=maxEvaluations || numel(T)~=maxEvaluations
                status='invalid'; errID='FE:Mismatch'; errMsg='FE or trace length mismatch';
            elseif ~traceFinite || ~traceMonotone
                status='invalid'; errID='Trace:Invalid'; errMsg='trace invalid';
            end
        catch e
            status='error'; errID=e.identifier; errMsg=e.message; secs=toc(t0);
        end
        row=struct('FunctionID',job.FunctionID,'Function',sprintf('F%02d',job.FunctionID),...
            'Run',job.Run,'Seed',job.Seed,'Dimension',D,'Method',job.Method,'Population',N,...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed,'Budget',maxEvaluations,...
            'FinalCost',finalCost,'FinalError',finalCost-bias,'Error20FE',error20,'Error60FE',error60,'Error80FE',error80,...
            'Evaluations',evals,'Seconds',secs,'BestRecheckAbsDiff',recheckDiff,'TraceFinite',traceFinite,...
            'TraceMonotone',traceMonotone,'Status',status,'ErrorID',errID,'ErrorMessage',errMsg);
        names={'SeekingEvaluations','TracingEvaluations','Rounds','MeanParentCoverage','MeanConcentration',...
            'TraceSuccesses','SeekSuccesses','ProposalGenerated','ProposalEvaluated','ProposalExpired'};
        for q=1:numel(names)
            if isfield(info,names{q}), row.(names{q})=info.(names{q}); else, row.(names{q})=NaN; end
        end
        batchResults{j}=row;
    end
    records(first:last)=batchResults; writetable(struct2table([records{1:last}]),fullfile(outDir,'raw_runs.csv'));
    fprintf('Completed %d/%d runs\n',last,numel(jobs));
end
raw=struct2table([records{:}]); writetable(raw,fullfile(outDir,'raw_runs.csv'));
valid=strcmp(raw.Status,'ok'); summary=groupsummary(raw(valid,:),{'Function','Method'},{'mean','median'},'FinalError');
writetable(summary,fullfile(outDir,'summary.csv')); fprintf('Saved %s\n',outDir);
