clc
clear
close all

root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data','cec2017'))
cd(fullfile(root,'data','cec2017'))

% 最小结构修正对比；正式 DSS_RLCSO_CEC 仍固定旧 modeAware。
algorithms={'DSS_RLCSO','DSS_RLCSO','CLPSO_CEC'};
algorithmNames={'DSS-RLCSO-V1','DSS-RLCSO-V3','CLPSO'};
rlModes={'modeAware','modeAwareV3',''};
functionIDs=[3 5 10 13 15 19 25 28 30];
D=30;
population=50;
maxEvaluations=10000*D;
repeatIDs=1:3;
seedBase=20271004;
searchSeedOffset=100000;
lb=-100*ones(1,D);
ub=100*ones(1,D);

stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir=fullfile(root,'results','cec',['cec2017_v3_' stamp]);
historyDir=fullfile(resultDir,'histories');
mkdir(historyDir)
copyfile(fullfile(root,'DSS_RLCSO.m'),resultDir)
copyfile(fullfile(root,'CLPSO_CEC.m'),resultDir)
copyfile(fullfile(root,'main_cec2017_v3.m'),resultDir)
save(fullfile(resultDir,'protocol.mat'),'functionIDs','repeatIDs','D', ...
    'population','maxEvaluations','seedBase','searchSeedOffset','rlModes', ...
    'algorithms','algorithmNames');

records=cell(numel(functionIDs)*numel(repeatIDs)*numel(algorithms),1);
count=0;
for functionID=functionIDs
    f=@(x)CEC2017Function(x,functionID);
    for repeat=repeatIDs
        initSeed=seedBase+repeat;
        searchSeed=initSeed+searchSeedOffset;
        rng(initSeed)
        state=struct('lowerBound',lb,'upperBound',ub, ...
            'maxEvaluations',maxEvaluations, ...
            'initialPopulation',lb+rand(population,D).*(ub-lb));
        for k=1:numel(algorithms)
            state.rlMode=rlModes{k};
            [Best,T,info]=feval(algorithms{k},f,state, ...
                ceil(maxEvaluations/population),population,searchSeed);
            assert(info.Evaluations==maxEvaluations && numel(T)==maxEvaluations)
            assert(all(isfinite(T)) && all(diff(T)<=0) && T(end)==Best.Cost)
            assert(isequal(info.InitialPopulation,state.initialPopulation))
            count=count+1;
            runRecord=struct('Function',sprintf('F%02d',functionID), ...
                'FunctionID',functionID,'Dimension',D,'Algorithm',algorithmNames{k}, ...
                'RLMode',rlModes{k},'Run',repeat,'InitSeed',initSeed, ...
                'SearchSeed',searchSeed,'Evaluations',info.Evaluations, ...
                'BestCost',Best.Cost,'BestError',max(0,Best.Cost-100*functionID), ...
                'Seconds',info.Seconds,'TraceFreeRoundRate',NaN, ...
                'MeanTraceSamplesLast5Rounds',NaN, ...
                'OpportunitySelectionChangedRate',NaN,'BalancedModeRate',NaN, ...
                'UnderSampledRoundRate',NaN);
            if k<=2
                runRecord.TraceFreeRoundRate=mean(info.TracingEvaluationsPerRound==0);
                traceWindow=filter(ones(1,5),1,info.TracingEvaluationsPerRound);
                runRecord.MeanTraceSamplesLast5Rounds=mean(traceWindow(5:end));
                runRecord.BalancedModeRate=mean(info.ModeStateHistory==2);
            end
            if k==2
                runRecord.OpportunitySelectionChangedRate= ...
                    mean(info.OpportunitySelectionChanged);
                runRecord.UnderSampledRoundRate=mean(any(info.ModeSampleCounts<10,2));
            end
            records{count}=runRecord;
            save(fullfile(historyDir,sprintf('F%02d_%s_r%03d.mat', ...
                functionID,algorithmNames{k},repeat)),'Best','T','info','runRecord');
            rawRuns=struct2table([records{1:count}]);
            writetable(rawRuns,fullfile(resultDir,'raw_runs_checkpoint.csv'));
            fprintf('F%02d %s r%02d error=%.6g time=%.2fs [%d/%d]\n', ...
                functionID,algorithmNames{k},repeat,runRecord.BestError, ...
                info.Seconds,count,numel(records));
        end
    end
end
writetable(rawRuns,fullfile(resultDir,'raw_runs.csv'));

summaryRecords={};
count=0;
for functionID=functionIDs
    for k=1:numel(algorithms)
        rows=rawRuns(rawRuns.FunctionID==functionID & ...
            strcmp(rawRuns.Algorithm,algorithmNames{k}),:);
        count=count+1;
        summaryRecords{count}=struct('Function',sprintf('F%02d',functionID), ...
            'Algorithm',algorithmNames{k},'Runs',height(rows), ...
            'MeanError',mean(rows.BestError),'StdError',std(rows.BestError), ...
            'MedianError',median(rows.BestError),'MeanSeconds',mean(rows.Seconds), ...
            'TraceFreeRoundRate',mean(rows.TraceFreeRoundRate), ...
            'MeanTraceSamplesLast5Rounds',mean(rows.MeanTraceSamplesLast5Rounds), ...
            'OpportunitySelectionChangedRate',mean(rows.OpportunitySelectionChangedRate), ...
            'BalancedModeRate',mean(rows.BalancedModeRate), ...
            'UnderSampledRoundRate',mean(rows.UnderSampledRoundRate));
    end
end
summary=struct2table([summaryRecords{:}]);
writetable(summary,fullfile(resultDir,'summary.csv'));
save(fullfile(resultDir,'v3_results.mat'),'rawRuns','summary');
fprintf('Saved V3 development results to %s\n',resultDir);
