# 简洁配额Q研究候选

入口ASE_CSO_QuotaQ_Candidate.m固定配置，原正式ASE_CSO入口不变。本候选为之前较稳gate+10版的无损表压缩，40组CEC逐点Best/T/RNG和自由状态Q等价检查通过。

- 真实连续1000FE无gbest改善作为一个触发条件；健康固定6T4S。
- 停滞时按预算进度三阶段的有效3×3小表，选2T8S/4T6S/6T4S，每100FE更新。
- 当前区间真改善+10，否则−1；α.1/γ.9/ε.1，Q初值0。
- 不加额外搜索算子/半径恢复/可变窗口/计数学习率；B10 Searching/Tracing原公式、MR.4和真实锚点管理保留。

调用与仓库其它CEC算法一致：[Best,T,info]=ASE_CSO_QuotaQ_Candidate(f,state,[],50,seed)。state必须含initialPopulation、lowerBound、upperBound、maxEvaluations。logTrajectory与auditSimplify仅作可选检查，默认关闭，不改RNG/trajectory。

性能边界：对旧Q开发6:2/27:13、对Fixed65:3/20:20，仍未胜同触发Random/Eps，未通过学习强门。简化没有创造新性能收益，不贴“已成功SCI方法”。该入口独立复现依赖ASE_CSO_QuotaQ_Compact.m，不把复现兼容switch都列为论文机制。

简洁消融：相同原搜索骨架+Fixed6；相同触发+uniformRandom三配额；相同触发+epsilon.1利用Fixed6；完整候选。始终真实FE相同并计initialization，不将改MR基线当纯删Q。具体结果见docs/QUOTA_Q_SIMPLICITY_FINAL_20261012.md。
