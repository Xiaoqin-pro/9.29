clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=[1 3:30];
repeatIDs=41:45;
D=30;
basePopulation=50;
population=18*D;
maxEvaluations=60000;
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
workerCount=4;
batchSize=4;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_lshade_standard_' stamp]);
mkdir(resultDir);

jobs=struct('FunctionID',{},'Run',{},'InitSeed',{},'SearchSeed',{}, ...
    'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        initialPopulation=lb+rand(basePopulation,D).*(ub-lb);
        extraPopulation=lb+rand(population-basePopulation,D).*(ub-lb);
        count=count+1;
        jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
            'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
            'InitialPopulation',[initialPopulation;extraPopulation]);
    end
end

pool=gcp('nocreate');
if isempty(pool)
    parpool('local',workerCount);
elseif pool.NumWorkers~=workerCount
    delete(pool);
    parpool('local',workerCount);
end

records=cell(numel(jobs),1);
curves=cell(numel(jobs),1);
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        f=@(x)CEC2017Function(x,job.FunctionID);
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation, ...
            'lshadeProfile','standard');
        [Best,T,info]=LSHADE_CEC(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
        assert(all(isfinite(T)))
        functionValue=100*job.FunctionID;
        record=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm','LSHADE-N540', ...
            'Run',job.Run,'Population',population,'ArchiveRate',2.6, ...
            'MemorySize',6,'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-functionValue),'Seconds',info.Seconds, ...
            'Error30FE',max(0,T(round(0.3*maxEvaluations))-functionValue), ...
            'Error60FE',max(0,T(round(0.6*maxEvaluations))-functionValue), ...
            'Error80FE',max(0,T(round(0.8*maxEvaluations))-functionValue));
        nodes=(3000:3000:maxEvaluations)';
        curve=table(repmat(job.FunctionID,numel(nodes),1), ...
            repmat({'LSHADE-N540'},numel(nodes),1),repmat(job.Run,numel(nodes),1), ...
            nodes,max(0,T(nodes)-functionValue), ...
            'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
        batchResults{j}=struct('record',record,'curve',curve);
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j}.record;
        curves{first+j-1}=batchResults{j}.curve;
    end
    writetable(struct2table([records{1:last}]), ...
        fullfile(resultDir,'raw_runs_checkpoint.csv'));
    writetable(vertcat(curves{1:last}), ...
        fullfile(resultDir,'convergence_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
writetable(vertcat(curves{:}),fullfile(resultDir,'convergence.csv'));

summaryRecords=cell(numel(functionIDs),1);
for k=1:numel(functionIDs)
    functionID=functionIDs(k);
    rows=rawRuns(rawRuns.FunctionID==functionID,:);
    summaryRecords{k}=struct('Function',sprintf('F%02d',functionID), ...
        'FunctionID',functionID,'Algorithm','LSHADE-N540','Runs',height(rows), ...
        'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
        'MedianError',median(rows.BestError),'MinError',min(rows.BestError), ...
        'MeanSeconds',mean(rows.Seconds),'MeanError30FE',mean(rows.Error30FE), ...
        'MeanError60FE',mean(rows.Error60FE),'MeanError80FE',mean(rows.Error80FE));
end
writetable(struct2table([summaryRecords{:}]),fullfile(resultDir,'summary.csv'));

readme={ ...
    '# Standard L-SHADE validation at 60k FE', ...
    '', ...
    '- Functions: all CEC2017 functions except F2 (29 functions).', ...
    '- Dimension: D=30; initial population: 18D=540; minimum population: 4.', ...
    '- Archive rate: 2.6; historical memory size: 6; p-best rate: 0.11.', ...
    '- Budget: 60,000 FE; repeats: 41:45.', ...
    '- The first 50 initial points reuse the same random stream as the CSO runs; 490 additional points are generated afterward.', ...
    '- The first six functions were used for the protocol pilot; all 29 functions are rerun here under the same standard configuration.', ...
    ''};
fid=fopen(fullfile(resultDir,'README.md'),'w');
fprintf(fid,'%s\n',readme{:});
fclose(fid);

delete(gcp('nocreate'))
fprintf('Saved standard L-SHADE validation to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
