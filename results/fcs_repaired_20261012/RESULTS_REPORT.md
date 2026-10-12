# FCS修复后开发结果

341次运行全部有效，独立复核64530条决策日志。

| Method | MeanFunctionRank | FunctionsBest | MeanSeconds | Runs |
| --- | --- | --- | --- | --- |
| FCS-batch | 3 | 2 | 4.23313 | 40 |
| B10-Reference | 4 | 2 | 3.97042 | 40 |
| FCS-q | 4 | 0 | 4.20146 | 40 |
| FCS-random | 4.25 | 2 | 4.16501 | 40 |
| FCS-success | 4.25 | 1 | 4.18253 | 40 |
| FCS-continue | 5.125 | 1 | 4.20415 | 40 |
| FCS-reverse | 5.375 | 0 | 4.1682 | 40 |
| FCS-switch | 6 | 0 | 4.16325 | 40 |

## 两两胜负（函数均值、逐seed；非显著胜场）

| MethodA | MethodB | FunctionMeanAWins | FunctionMeanBWins | FunctionMeanTies | SeedAWins | SeedBWins | SeedTies |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B10-Reference | FCS-batch | 4 | 4 | 0 | 22 | 18 | 0 |
| B10-Reference | FCS-continue | 5 | 3 | 0 | 27 | 13 | 0 |
| B10-Reference | FCS-q | 5 | 3 | 0 | 21 | 19 | 0 |
| B10-Reference | FCS-random | 4 | 4 | 0 | 21 | 19 | 0 |
| B10-Reference | FCS-reverse | 5 | 3 | 0 | 27 | 13 | 0 |
| B10-Reference | FCS-success | 4 | 4 | 0 | 20 | 20 | 0 |
| B10-Reference | FCS-switch | 5 | 3 | 0 | 25 | 15 | 0 |
| FCS-batch | FCS-continue | 7 | 1 | 0 | 28 | 12 | 0 |
| FCS-batch | FCS-q | 5 | 3 | 0 | 23 | 17 | 0 |
| FCS-batch | FCS-random | 5 | 3 | 0 | 19 | 21 | 0 |
| FCS-batch | FCS-reverse | 7 | 1 | 0 | 30 | 10 | 0 |
| FCS-batch | FCS-success | 6 | 2 | 0 | 23 | 17 | 0 |
| FCS-batch | FCS-switch | 6 | 2 | 0 | 25 | 15 | 0 |
| FCS-continue | FCS-q | 3 | 5 | 0 | 15 | 25 | 0 |
| FCS-continue | FCS-random | 4 | 4 | 0 | 17 | 23 | 0 |
| FCS-continue | FCS-reverse | 4 | 4 | 0 | 20 | 20 | 0 |
| FCS-continue | FCS-success | 4 | 4 | 0 | 16 | 24 | 0 |
| FCS-continue | FCS-switch | 4 | 4 | 0 | 19 | 21 | 0 |
| FCS-q | FCS-random | 4 | 4 | 0 | 23 | 17 | 0 |
| FCS-q | FCS-reverse | 5 | 3 | 0 | 22 | 18 | 0 |
| FCS-q | FCS-success | 6 | 2 | 0 | 21 | 19 | 0 |
| FCS-q | FCS-switch | 6 | 2 | 0 | 24 | 16 | 0 |
| FCS-random | FCS-reverse | 5 | 3 | 0 | 22 | 18 | 0 |
| FCS-random | FCS-success | 3 | 5 | 0 | 23 | 17 | 0 |
| FCS-random | FCS-switch | 7 | 1 | 0 | 23 | 17 | 0 |
| FCS-reverse | FCS-success | 2 | 6 | 0 | 14 | 26 | 0 |
| FCS-reverse | FCS-switch | 5 | 3 | 0 | 21 | 19 | 0 |
| FCS-success | FCS-switch | 7 | 1 | 0 | 20 | 20 | 0 |

## 执行指标

| Method | Seconds | MeanParentCoverage | ExecutedContinue | ExecutedSwitch | SameParentSecondEvaluations | OtherParentSecondEvaluations | OpenedParentEvaluations | SecondEvaluationSuccesses | QUpdates | FallbackCount | ActionMismatchCount |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| B10-Reference | 3.97042 | nan | nan | nan | nan | nan | nan | nan | nan | nan | nan |
| FCS-batch | 4.23313 | 3.45612 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| FCS-continue | 4.20415 | 3 | 17985 | 0 | 17985 | 0 | 0 | 1090.55 | 0 | 0 | 0 |
| FCS-q | 4.20146 | 4.33561 | 7297.35 | 10687.6 | 7297.35 | 2680.68 | 8006.98 | 1560.88 | 17985 | 0 | 0 |
| FCS-random | 4.16501 | 4.16795 | 8993.42 | 8991.58 | 8993.42 | 1989.7 | 7001.88 | 1456.8 | 0 | 0 | 0 |
| FCS-reverse | 4.1682 | 3.26956 | 16146.9 | 1838.1 | 16146.9 | 222.125 | 1615.97 | 1256.2 | 0 | 0 | 0 |
| FCS-success | 4.18253 | 4.89668 | 2042.17 | 15942.8 | 2042.17 | 4572.23 | 11370.6 | 1487.15 | 0 | 0 | 0 |
| FCS-switch | 4.16325 | 5.13005 | 0 | 17985 | 0 | 5215.35 | 12769.6 | 1555.2 | 0 | 0 | 0 |

## 解释范围

FCS组内共有搜索内核、候选排序、Tracing、奖励和参数。B10使用不同Tracing筛选和候选分配，仅为质量参照。Switch保留不同父代语义，可能评价其他父代的第二候选，不自动等于Open。Q nextState保留旧即时follow-up解释，此结果只检验这个小控制器，不证明长期规划或一般Q-learning无效。

8函数5seed是开发筛选；参考几何是借用组件，不作为创新；局部成功率与最终质量必须分开。决策内样本非独立实验重复，跨函数原始gain不作统一性能指标。5seed的精确双侧符号秩最小p为0.0625，显著性推断有限。
