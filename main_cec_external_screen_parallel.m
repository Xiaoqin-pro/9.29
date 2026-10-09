clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

functionIDs=setdiff(1:30,2);
D=30;
population=50;
maxEvaluations=10000*D;
repeatIDs=16:20;                     % 5个统一开发seed，正式seed仍保留101:130
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
variants={'CSO','CLPSO','DSS-Range','Global-Cap2-Range'};

resumeFolder=''; % 续跑时填入已有结果目录名，留空时创建新实验
if isempty(resumeFolder)
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
    resultDir=fullfile(root,'results','cec',['cec2017_external_screen_' stamp]);
    mkdir(resultDir);
else
    resultDir=fullfile(root,'results','cec',resumeFolder);
end

jobs=struct('FunctionID',{},'Run',{},'Algorithm',{}, ...
    'InitSeed',{},'SearchSeed',{},'InitialPopulation',{});
count=0;
for functionID=functionIDs
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        initialPopulation=lb+rand(population,D).*(ub-lb);
        for k=1:numel(variants)
            count=count+1;
            jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
                'Algorithm',variants{k},'InitSeed',initSeed, ...
                'SearchSeed',initSeed+100000, ...
                'InitialPopulation',initialPopulation);
        end
    end
end

workerCount=4;
pool=gcp('nocreate');
if isempty(pool)
    parpool('local',workerCount);
elseif pool.NumWorkers~=workerCount
    delete(pool);
    parpool('local',workerCount);
end

records=cell(numel(jobs),1);
curves=cell(numel(jobs),1);
completed=0;
checkpointFile=fullfile(resultDir,'raw_runs_checkpoint.csv');
curveFile=fullfile(resultDir,'convergence_checkpoint.csv');
if isfile(checkpointFile)
    previous=readtable(checkpointFile);
    completed=height(previous);
    for j=1:completed
        job=jobs(j);
        row=previous(j,:);
        assert(row.FunctionID==job.FunctionID && row.Run==job.Run && ...
            strcmp(row.Algorithm,job.Algorithm) && row.InitSeed==job.InitSeed && ...
            row.SearchSeed==job.SearchSeed && row.Evaluations==maxEvaluations)
        records{j}=table2struct(row);
        nodes=[90000;180000;300000]; % 首次退出前，仅保留了三个FE节点
        curves{j}=table(repmat(job.FunctionID,3,1),repmat({job.Algorithm},3,1), ...
            repmat(job.Run,3,1),nodes,[row.Error30FE;row.Error60FE;row.BestError], ...
            'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
    end
    if isfile(curveFile)
        previousCurves=readtable(curveFile);
        for j=1:completed
            job=jobs(j);
            curves{j}=previousCurves(previousCurves.FunctionID==job.FunctionID & ...
                previousCurves.Run==job.Run & strcmp(previousCurves.Algorithm,job.Algorithm),:);
        end
    end
end
fprintf('Resuming %d/%d completed runs\n',completed,numel(jobs));
batchSize=4;                         % 每批落盘，限制内存占用
for first=completed+1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        f=@(x)CEC2017Function(x,job.FunctionID);
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation, ...
            'actionMode','fixed2','rlMode','modeAwareV41','seekingMode','range', ...
            'seekSelection','dss','recoveryEnabled',false, ...
            'useModePreserving',true,'ablation',struct('useCatScreen',true, ...
            'useCandidateScreen',true,'useRL',false));
        if strcmp(job.Algorithm,'CSO')
            [Best,T,info]=CSO_CEC(f,state,ceil(maxEvaluations/population), ...
                population,job.SearchSeed);
        elseif strcmp(job.Algorithm,'CLPSO')
            [Best,T,info]=CLPSO_CEC(f,state,ceil(maxEvaluations/population), ...
                population,job.SearchSeed);
        else
            if strcmp(job.Algorithm,'Global-Cap2-Range')
                state.seekSelection='globalCap2';
            else
                state.seekSelection='dss';
            end
            [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
                population,job.SearchSeed);
        end
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations && all(isfinite(T)))
        record=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm',job.Algorithm,'Run',job.Run, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-100*job.FunctionID),'Seconds',info.Seconds, ...
            'Error30FE',max(0,T(round(0.3*maxEvaluations))-100*job.FunctionID), ...
            'Error60FE',max(0,T(round(0.6*maxEvaluations))-100*job.FunctionID), ...
            'SeekingParentCoverage',NaN,'SeekingConcentration',NaN, ...
            'SeekingParentSuccessRate',NaN,'SeekingGlobalImprovements',NaN, ...
            'TracingGlobalImprovements',NaN,'MeanDiversity',NaN, ...
            'BudgetFillRate',NaN,'ModeAllocationError',NaN);
        if startsWith(job.Algorithm,'DSS') || startsWith(job.Algorithm,'Global')
            assert(all(info.EvaluationsPerRound==5))
            assert(all(info.ActualTracingEvaluations==2))
            assert(all(info.ActualSeekingEvaluations==3))
            assert(all(info.BudgetFillRate==1))
            assert(max(abs(info.ModeAllocationError),[],'all')==0)
            assert(max(info.SeekingMaxParentEvaluations)<=2)
            record.SeekingParentCoverage=mean(info.SeekingParentCoverage);
            record.SeekingConcentration=mean(info.SeekingConcentration);
            record.SeekingParentSuccessRate=sum(info.SeekingSuccessHistory.* ...
                info.SeekingEvaluationsPerRound)/info.SeekingEvaluations;
            record.SeekingGlobalImprovements=sum(info.SeekingGlobalImprovementCounts);
            record.TracingGlobalImprovements=sum(info.TracingGlobalImprovementCounts);
            record.MeanDiversity=mean(info.DiversityHistory);
            record.BudgetFillRate=mean(info.BudgetFillRate);
            record.ModeAllocationError=max(abs(info.ModeAllocationError),[],'all');
        end
        nodes=(3000:3000:maxEvaluations)';
        curve=table(repmat(job.FunctionID,numel(nodes),1), ...
            repmat({job.Algorithm},numel(nodes),1),repmat(job.Run,numel(nodes),1), ...
            nodes,max(0,T(nodes)-100*job.FunctionID), ...
            'VariableNames',{'FunctionID','Algorithm','Run','FE','BestError'});
        batchResults{j}=struct('record',record,'curve',curve);
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j}.record;
        curves{first+j-1}=batchResults{j}.curve;
    end
    writetable(struct2table([records{1:last}]), ...
        fullfile(resultDir,'raw_runs_checkpoint.csv'));
    writetable(vertcat(curves{1:last}),curveFile);
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
writetable(vertcat(curves{:}),fullfile(resultDir,'convergence.csv'));
summaryRecords=cell(numel(functionIDs)*numel(variants),1);
count=0;
for functionID=functionIDs
    for k=1:numel(variants)
        rows=rawRuns(rawRuns.FunctionID==functionID & ...
            strcmp(rawRuns.Algorithm,variants{k}),:);
        count=count+1;
        summaryRecords{count}=struct('Function',sprintf('F%02d',functionID), ...
            'Algorithm',variants{k},'Runs',height(rows), ...
            'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
            'MedianError',median(rows.BestError),'MinError',min(rows.BestError), ...
            'MeanSeconds',mean(rows.Seconds),'MeanError30FE',mean(rows.Error30FE), ...
            'MeanError60FE',mean(rows.Error60FE), ...
            'MeanParentCoverage',mean(rows.SeekingParentCoverage), ...
            'MeanConcentration',mean(rows.SeekingConcentration), ...
            'SeekingSuccessRate',mean(rows.SeekingParentSuccessRate), ...
            'MeanSeekingGlobalImprovements',mean(rows.SeekingGlobalImprovements), ...
            'MeanTracingGlobalImprovements',mean(rows.TracingGlobalImprovements), ...
            'MeanDiversity',mean(rows.MeanDiversity));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
delete(gcp('nocreate'))
fprintf('Saved external screen to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
