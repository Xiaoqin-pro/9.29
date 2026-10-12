# FCS单保留名额结果

新增320次，缓存对照80次。协议：docs/FCS_RESERVED_STUDY_PROTOCOL_20261012.md。

| Condition | AverageFunctionRank | FunctionsBest | Source |
| --- | --- | --- | --- |
| Keep | 3.5 | 2 | exact-S0-cache |
| Q1-g0 | 3.75 | 1 | new-study |
| Q1-g9 | 4.375 | 1 | new-study |
| Q10-g9 | 4.375 | 1 | new-study |
| Q10-g0 | 5.25 | 0 | new-study |
| B10 | 5.375 | 3 | exact-S0-cache |
| Random | 6.75 | 0 | new-study |
| Progress | 6.875 | 0 | new-study |
| Reverse | 6.875 | 0 | new-study |
| Explore | 7.875 | 0 | new-study |

## 预定确认门槛

| Condition | KeepFunctionWins | KeepFunctionLosses | KeepSeedWins | KeepSeedLosses | RandomFunctionWins | RandomFunctionLosses | RandomSeedWins | RandomSeedLosses | ProgressFunctionWins | ProgressFunctionLosses | ProgressSeedWins | ProgressSeedLosses | EligibleForConfirmation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Q1-g0 | 3 | 5 | 20 | 20 | 7 | 1 | 24 | 16 | 7 | 1 | 25 | 15 | False |
| Q1-g9 | 3 | 5 | 15 | 25 | 6 | 2 | 20 | 20 | 6 | 2 | 23 | 17 | False |
| Q10-g0 | 1 | 7 | 18 | 22 | 6 | 2 | 24 | 16 | 6 | 2 | 25 | 15 | False |
| Q10-g9 | 2 | 6 | 16 | 24 | 5 | 3 | 22 | 18 | 6 | 2 | 27 | 13 | False |

## 两两比较

| Condition | Control | FunctionWins | FunctionLosses | FunctionTies | SeedWins | SeedLosses | SeedTies |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Q1-g0 | Keep | 3 | 5 | 0 | 20 | 20 | 0 |
| Q1-g0 | Explore | 7 | 1 | 0 | 25 | 15 | 0 |
| Q1-g0 | Random | 7 | 1 | 0 | 24 | 16 | 0 |
| Q1-g0 | Progress | 7 | 1 | 0 | 25 | 15 | 0 |
| Q1-g0 | Reverse | 7 | 1 | 0 | 26 | 14 | 0 |
| Q1-g0 | B10 | 5 | 3 | 0 | 18 | 22 | 0 |
| Q1-g9 | Keep | 3 | 5 | 0 | 15 | 25 | 0 |
| Q1-g9 | Explore | 7 | 1 | 0 | 25 | 15 | 0 |
| Q1-g9 | Random | 6 | 2 | 0 | 20 | 20 | 0 |
| Q1-g9 | Progress | 6 | 2 | 0 | 23 | 17 | 0 |
| Q1-g9 | Reverse | 7 | 1 | 0 | 24 | 16 | 0 |
| Q1-g9 | B10 | 5 | 3 | 0 | 18 | 22 | 0 |
| Q10-g0 | Keep | 1 | 7 | 0 | 18 | 22 | 0 |
| Q10-g0 | Explore | 7 | 1 | 0 | 26 | 14 | 0 |
| Q10-g0 | Random | 6 | 2 | 0 | 24 | 16 | 0 |
| Q10-g0 | Progress | 6 | 2 | 0 | 25 | 15 | 0 |
| Q10-g0 | Reverse | 6 | 2 | 0 | 25 | 15 | 0 |
| Q10-g0 | B10 | 3 | 5 | 0 | 17 | 23 | 0 |
| Q10-g9 | Keep | 2 | 6 | 0 | 16 | 24 | 0 |
| Q10-g9 | Explore | 7 | 1 | 0 | 26 | 14 | 0 |
| Q10-g9 | Random | 5 | 3 | 0 | 22 | 18 | 0 |
| Q10-g9 | Progress | 6 | 2 | 0 | 27 | 13 | 0 |
| Q10-g9 | Reverse | 6 | 2 | 0 | 22 | 18 | 0 |
| Q10-g9 | B10 | 5 | 3 | 0 | 18 | 22 | 0 |

选择：None

每轮只控制最后1Seeking FE，先保持batch前缀。Keep与旧Batch逐点等价；Explore选前缀未覆盖父代。Q1/Q10为末FE global改善正奖励1/10否则-1，g0/g9为gamma0/.9。Q更新对应下一实际决策，终止0bootstrap，政策随机流独立。缓存时间不作速度比较；开发排名不是独立验证或新颖性通过。
