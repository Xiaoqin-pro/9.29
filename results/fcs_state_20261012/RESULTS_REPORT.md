# FCS相对质量状态结果

新增160次，缓存对照320次。协议：docs/FCS_STATE_STUDY_PROTOCOL_20261012.md。

| Condition | AverageFunctionRank | FunctionsBest | Source |
| --- | --- | --- | --- |
| Batch | 4 | 2 | S0-cache |
| Q-success | 4.625 | 1 | reward-cache |
| B10 | 5.5 | 2 | S0-cache |
| Random | 5.625 | 2 | S0-cache |
| Q-quality | 6 | 0 | new-study |
| Success | 6.125 | 0 | S0-cache |
| Rule-quality | 6.375 | 0 | new-study |
| Continue | 7.125 | 0 | S0-cache |
| Reverse | 7.5 | 0 | S0-cache |
| Q-phase | 8 | 0 | new-study |
| Switch | 8.5 | 0 | S0-cache |
| Rule-reverse-quality | 8.625 | 1 | new-study |

## 预定确认门槛

| Condition | BatchFunctionWins | BatchFunctionLosses | BatchSeedWins | BatchSeedLosses | RandomFunctionWins | RandomFunctionLosses | RandomSeedWins | RandomSeedLosses | Rule-qualityFunctionWins | Rule-qualityFunctionLosses | Rule-qualitySeedWins | Rule-qualitySeedLosses | DevelopmentComparisonsPassed | EligibleForConfirmation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Q-success | 3 | 5 | 22 | 18 | 5 | 3 | 23 | 17 | 4 | 4 | 20 | 20 | False | False |
| Q-phase | 2 | 6 | 17 | 23 | 2 | 6 | 17 | 23 | 3 | 5 | 18 | 22 | False | False |
| Q-quality | 2 | 6 | 20 | 20 | 3 | 5 | 17 | 23 | 5 | 3 | 22 | 18 | False | False |

## 两两比较

| Condition | Control | FunctionWins | FunctionLosses | FunctionTies | SeedWins | SeedLosses | SeedTies |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Q-success | Batch | 3 | 5 | 0 | 22 | 18 | 0 |
| Q-success | Random | 5 | 3 | 0 | 23 | 17 | 0 |
| Q-success | Rule-quality | 4 | 4 | 0 | 20 | 20 | 0 |
| Q-success | B10 | 5 | 3 | 0 | 21 | 19 | 0 |
| Q-phase | Batch | 2 | 6 | 0 | 17 | 23 | 0 |
| Q-phase | Random | 2 | 6 | 0 | 17 | 23 | 0 |
| Q-phase | Rule-quality | 3 | 5 | 0 | 18 | 22 | 0 |
| Q-phase | Q-success | 0 | 8 | 0 | 11 | 29 | 0 |
| Q-phase | B10 | 2 | 6 | 0 | 13 | 27 | 0 |
| Q-quality | Batch | 2 | 6 | 0 | 20 | 20 | 0 |
| Q-quality | Random | 3 | 5 | 0 | 17 | 23 | 0 |
| Q-quality | Rule-quality | 5 | 3 | 0 | 22 | 18 | 0 |
| Q-quality | Q-success | 4 | 4 | 0 | 19 | 21 | 0 |
| Q-quality | B10 | 4 | 4 | 0 | 17 | 23 | 0 |

选择：None

Q-quality用首访实测候选在真实fitness前20%的质量位；Q-success是同奖励/参数的原成功位；Q-phase删去反馈位；Rule-quality/反向为匹配固定规则。reward固定global±1，gamma0，仍6状态2动作，无额外FE。缓存时间不作速度比较。开发排名不是独立验证或新颖性通过。
