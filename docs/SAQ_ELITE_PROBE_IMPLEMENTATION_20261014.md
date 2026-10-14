# 单维精英探测实现合同（2026-10-14）

承接 docs/SAQ_ROUTE_REASSESSMENT_20261014.md。开发代码独立于冻结 SAQ 和旧 RestartQ。

- 新入口 SAQ_CSO_EliteProbe；policy=base/rule/random/q；acceptance=greedy/replace。
- base 使用冻结 Fixed6 的候选公式、搜索 RNG 调用顺序及已修正的几何筛选 helper。policy/probe 使用独立 RandStream。
- 先生成普通候选并分配 6T/4S，再作 100 FE 窗口决策；动作可行性要求窗口进展不足、有 Seeking 名额、有非历史前20%精英的 Seeking 承载者，且移除承载者后剩余常规 Seeking 池容量足够。不足时只有正常动作。
- 探测承载者不接受同轮旧 Seeking 候选，探测安排在普通评价之后。探测从该轮生成前 gbest 出发，以避免同轮普通搜索结果影响已生成候选。真实写回后保留独立历史最优档案。
- progressWindowFE=1000，threshold=1e-4，起点 IQR 归一化；数值保护=max(initialIQR*1e-12,realmin)，不使用目标偏置或 CEC 已知最优。未满1000FE不探测。
- sigma=1-0.9*budgetProgress，1→0.1；单坐标越界反射。每100FE窗口最多1个探测。
- replace 同步 pop/realPop/fitness/pbest/pbestCost，速度归零；greedy 模仿原 Seeking 接受规则，不强制重置速度。
- 学习仅 policy=q。Q 状态阶段3×低进展2，动作正常/探测；只有有两个可行动作时的决策参与学习；bootstrap 按下一节点可行动作取max，末次bootstrap=0；所有动作统一有效进展奖励+1/-1。
- 日志包含每个窗口、每个探测点、旧/新真实位置、旧/新pbest/速度、父代及全局成本、实际写回；每个run保存T与终态MAT。实际目标调用由运行器独立计数，最终档案和真实群体/pbest重算另计为运行后检查。
- 阶段1三方法：Fixed6 / ELS-Greedy / ELS-Replace；F1/6/9/13/21/22/27/30，8101:8110，D50/100k，4worker。源码、依赖、配置、种子清单运行前冻结。算子通过原先开发门后再跑Random/Q调度；不直接扩大正式试验。

用户于执行时将开发规模改为10种子：阶段1为240运行/24M FE；后续规则与Random/Q保持相同10种子。
