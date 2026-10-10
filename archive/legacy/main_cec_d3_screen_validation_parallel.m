clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

diagnosticIDs=[3 6 9 12 13 20 28 30];
allIDs=[1 3:30];
extensionIDs=setdiff(allIDs,diagnosticIDs);
selectionModes={'randomCap2','matchedRandomCap2'};
algorithmNames={'D3-RandomCap2','D3-MatchedRandomCap2'};
functionSets={extensionIDs,diagnosticIDs};
repeatIDs=41:45;
D=30;
population=50;
maxEvaluations=60000;
seedBase=20271004;
lb=-100*ones(1,D);
ub=100*ones(1,D);
workerCount=4;
batchSize=4;

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_d3_screen_validation_' stamp]);
mkdir(resultDir);

jobs=struct('FunctionID',{},'Run',{},'InitSeed',{},'SearchSeed',{}, ...
    'InitialPopulation',{},'Selection',{},'Algorithm',{});
count=0;
for mode=1:numel(selectionModes)
for functionID=functionSets{mode}
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        rng(initSeed,'twister')
        count=count+1;
        jobs(count)=struct('FunctionID',functionID,'Run',repeat, ...
            'InitSeed',initSeed,'SearchSeed',initSeed+100000, ...
            'InitialPopulation',lb+rand(population,D).*(ub-lb), ...
            'Selection',selectionModes{mode},'Algorithm',algorithmNames{mode});
    end
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
for first=1:batchSize:numel(jobs)
    last=min(first+batchSize-1,numel(jobs));
    batch=jobs(first:last);
    batchResults=cell(numel(batch),1);
    parfor j=1:numel(batch)
        job=batch(j);
        f=@(x)CEC2017Function(x,job.FunctionID);
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations,'initialPopulation',job.InitialPopulation, ...
            'actionMode','fixed2','rlMode','modeAwareV41','seekingMode','range', ...
            'seekSelection',job.Selection,'searchCore','elite','eliteGuidance',true, ...
            'tracingElitistAcceptance',true,'tracingDecay',true, ...
            'virtualTracing',true,'SMP',5,'recoveryEnabled',false, ...
            'useModePreserving',true, ...
            'ablation',struct('useCatScreen',true,'useCandidateScreen',true, ...
                'useRL',false));
        [Best,T,info]=DSS_RLCSO(f,state,ceil(maxEvaluations/population), ...
            population,job.SearchSeed);
        assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
        assert(all(isfinite(T)) && all(info.EvaluationsPerRound==5))
        assert(all(info.ActualTracingEvaluations==2))
        assert(all(info.ActualSeekingEvaluations==3))
        assert(all(info.BudgetFillRate==1))
        assert(max(abs(info.ModeAllocationError),[],'all')==0)
        assert(max(info.SeekingMaxParentEvaluations)<=2)
        if strcmp(job.Selection,'matchedRandomCap2')
            assert(isequal(info.SeekingParentCoverage,info.MatchedReferenceCoverage))
            assert(max(abs(info.SeekingConcentration- ...
                info.MatchedReferenceConcentration))<1e-12)
        end
        functionValue=100*job.FunctionID;
        batchResults{j}=struct('Function',sprintf('F%02d',job.FunctionID), ...
            'FunctionID',job.FunctionID,'Algorithm',job.Algorithm,'Run',job.Run, ...
            'InitSeed',job.InitSeed,'SearchSeed',job.SearchSeed, ...
            'Evaluations',info.Evaluations,'BestCost',Best.Cost, ...
            'BestError',max(0,Best.Cost-functionValue),'Seconds',info.Seconds, ...
            'Error30FE',max(0,T(round(0.3*maxEvaluations))-functionValue), ...
            'Error60FE',max(0,T(round(0.6*maxEvaluations))-functionValue), ...
            'Error80FE',max(0,T(round(0.8*maxEvaluations))-functionValue), ...
            'MeanParentCoverage',mean(info.SeekingParentCoverage), ...
            'MeanConcentration',mean(info.SeekingConcentration), ...
            'MaxParentEvaluations',max(info.SeekingMaxParentEvaluations), ...
            'SeekingGlobalImprovements',sum(info.SeekingGlobalImprovementCounts), ...
            'SeekingGlobalGain',sum(info.SeekingGlobalGain));
    end
    for j=1:numel(batch)
        records{first+j-1}=batchResults{j};
    end
    writetable(struct2table([records{1:last}]),fullfile(resultDir,'raw_runs_checkpoint.csv'));
    fprintf('Completed %d/%d runs with %d workers\n',last,numel(jobs),workerCount);
end

rawRuns=struct2table([records{:}]);
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));
summaryRecords={};
for mode=1:numel(selectionModes)
    for functionID=functionSets{mode}
        rows=rawRuns(rawRuns.FunctionID==functionID & ...
            strcmp(rawRuns.Algorithm,algorithmNames{mode}),:);
        summaryRecords{end+1}=struct('Function',sprintf('F%02d',functionID), ...
            'FunctionID',functionID,'Algorithm',algorithmNames{mode}, ...
            'Runs',height(rows),'MeanError',mean(rows.BestError), ...
            'StdError',std(rows.BestError),'MedianError',median(rows.BestError), ...
            'MeanSeconds',mean(rows.Seconds), ...
            'MeanParentCoverage',mean(rows.MeanParentCoverage), ...
            'MeanConcentration',mean(rows.MeanConcentration));
    end
end
writetable(struct2table([summaryRecords{:}]),fullfile(resultDir,'summary.csv'));
delete(gcp('nocreate'))
fprintf('Saved screen validation to %s\n',resultDir);

function value=CEC2017Function(x,functionID)
    value=cec17_func(x',functionID);
    value=value(1);
end
