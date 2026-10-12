# FCS奖励开发结果

新增280次，缓存对照320次。协议：docs/FCS_REWARD_STUDY_PROTOCOL_20261012.md。

| Condition | AverageFunctionRank | FunctionsBest | Source |
| --- | --- | --- | --- |
| Batch | 5.25 | 2 | S0-cache |
| G1-g0 | 5.375 | 1 | new-study |
| G10-g9 | 5.875 | 1 | new-study |
| P-g0 | 6.875 | 0 | new-study |
| P-g9 | 7.25 | 0 | S0-cache |
| Random | 7.25 | 2 | S0-cache |
| B10 | 7.25 | 2 | S0-cache |
| Success | 8.25 | 0 | S0-cache |
| M10-g9 | 8.625 | 0 | new-study |
| G1-g9 | 9 | 0 | new-study |
| Continue | 9.25 | 0 | S0-cache |
| G10-g0 | 9.25 | 0 | new-study |
| Reverse | 9.375 | 0 | S0-cache |
| M10-g0 | 10.25 | 0 | new-study |
| Switch | 10.875 | 0 | S0-cache |

## 预定确认门槛

| Condition | BatchFunctionWins | BatchFunctionLosses | BatchSeedWins | BatchSeedLosses | RandomFunctionWins | RandomFunctionLosses | RandomSeedWins | RandomSeedLosses | EligibleForConfirmation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| G1-g0 | 3 | 5 | 22 | 18 | 5 | 3 | 23 | 17 | False |
| G1-g9 | 2 | 6 | 15 | 25 | 2 | 6 | 21 | 19 | False |
| G10-g0 | 1 | 7 | 15 | 25 | 4 | 4 | 20 | 20 | False |
| G10-g9 | 5 | 3 | 20 | 20 | 4 | 4 | 18 | 22 | False |
| M10-g0 | 1 | 7 | 16 | 24 | 2 | 6 | 19 | 21 | False |
| M10-g9 | 2 | 6 | 18 | 22 | 4 | 4 | 18 | 22 | False |
| P-g0 | 4 | 4 | 20 | 20 | 3 | 5 | 21 | 19 | False |
| P-g9 | 3 | 5 | 17 | 23 | 4 | 4 | 23 | 17 | False |

## 两两比较

| Condition | Control | FunctionWins | FunctionLosses | FunctionTies | SeedWins | SeedLosses | SeedTies |
| --- | --- | --- | --- | --- | --- | --- | --- |
| G1-g0 | Batch | 3 | 5 | 0 | 22 | 18 | 0 |
| G1-g0 | Random | 5 | 3 | 0 | 23 | 17 | 0 |
| G1-g0 | P-g9 | 5 | 3 | 0 | 20 | 20 | 0 |
| G1-g0 | B10 | 5 | 3 | 0 | 21 | 19 | 0 |
| G1-g9 | Batch | 2 | 6 | 0 | 15 | 25 | 0 |
| G1-g9 | Random | 2 | 6 | 0 | 21 | 19 | 0 |
| G1-g9 | P-g9 | 3 | 5 | 0 | 19 | 21 | 0 |
| G1-g9 | B10 | 3 | 5 | 0 | 17 | 23 | 0 |
| G10-g0 | Batch | 1 | 7 | 0 | 15 | 25 | 0 |
| G10-g0 | Random | 4 | 4 | 0 | 20 | 20 | 0 |
| G10-g0 | P-g9 | 4 | 4 | 0 | 20 | 20 | 0 |
| G10-g0 | B10 | 2 | 6 | 0 | 14 | 26 | 0 |
| G10-g9 | Batch | 5 | 3 | 0 | 20 | 20 | 0 |
| G10-g9 | Random | 4 | 4 | 0 | 18 | 22 | 0 |
| G10-g9 | P-g9 | 5 | 3 | 0 | 20 | 20 | 0 |
| G10-g9 | B10 | 5 | 3 | 0 | 19 | 21 | 0 |
| M10-g0 | Batch | 1 | 7 | 0 | 16 | 24 | 0 |
| M10-g0 | Random | 2 | 6 | 0 | 19 | 21 | 0 |
| M10-g0 | P-g9 | 2 | 6 | 0 | 20 | 20 | 0 |
| M10-g0 | B10 | 2 | 6 | 0 | 17 | 23 | 0 |
| M10-g9 | Batch | 2 | 6 | 0 | 18 | 22 | 0 |
| M10-g9 | Random | 4 | 4 | 0 | 18 | 22 | 0 |
| M10-g9 | P-g9 | 3 | 5 | 0 | 17 | 23 | 0 |
| M10-g9 | B10 | 5 | 3 | 0 | 20 | 20 | 0 |
| P-g0 | Batch | 4 | 4 | 0 | 20 | 20 | 0 |
| P-g0 | Random | 3 | 5 | 0 | 21 | 19 | 0 |
| P-g0 | P-g9 | 4 | 4 | 0 | 21 | 19 | 0 |
| P-g0 | B10 | 4 | 4 | 0 | 17 | 23 | 0 |
| P-g9 | Batch | 3 | 5 | 0 | 17 | 23 | 0 |
| P-g9 | Random | 4 | 4 | 0 | 23 | 17 | 0 |
| P-g9 | B10 | 3 | 5 | 0 | 19 | 21 | 0 |

选择：None

P=局部±1；G1=global±1；G10=global+10/-1；M10=历史正gain归一正奖励至10/-1；g0/g9为gamma0/.9。只开发reward与gamma，搜索核/状态/动作不变。缓存时间不作速度比较。开发排名不等于独立验证或新颖性通过；全条件保留。
