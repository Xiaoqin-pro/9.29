# FCS单保留名额开发（2026-10-12，运行前冻结）

## 简单主线
现有奖励与首访质量状态均未稳定胜Batch；本轮把干预收窄到每轮最后一个Seeking名额。完整4T6S轮先按同一batch计划真实评价5个候选，剩余1FE选“保留原计划第6候选”或“探索此前未覆盖父代”。两个动作、小6状态Q表，不新增搜索算子、代理模型或状态维度。
state=3搜索阶段×前缀Seeking是否真实改善global best。前缀反馈排除Tracing；reward仅来自最后一个FE的global改善。Q回传到下一实际保留名额决策的状态，终止零bootstrap，mask只用可执行动作。gamma0/.9均合法，不沿用旧即时followup状态。

## 不变与实现约定
候选生成、random Tracing、原排序、SMP5/SRD.05/CDC.2、elite20%、真实锚点与接受/rollback均与FCS-Batch一致。前缀/末位先更新局部最小代价，统一在Seeking结束应用，保留原batch算术和顺序。固定Keep必须逐调用位置/Best/T/global RNG与旧batch严格一致。
探索父代从尚未被本轮前缀评价的Seeking父代中均匀选择，其候选从原4个新提案中均匀选；若原末候选恰属该父代，排除原末行，确保两行动作候选行不同。探索没有新生成点或额外目标调用。当前单元父代最多2FE保持。
政策随机流与搜索随机流分离（policy seed=search seed+2000003取合法范围），避免仅因增加策略抽样改变搜索候选序列。该分离是实现/比较约定，不作创新。
没有可探索父代时强制Keep，不创建新的自主Q样本；上一pending在合法节点按mask兑现；最终未兑现样本terminal兑现。不会把强制动作假装自由选择。

## 预先限定的开发
固定控制Keep（完全复现Batch）、Explore、Random、Progress（前缀有global改善则Keep，否则Explore）、Reverse；Q的alpha.1/epsilon.1固定，gamma0/.9 ×正奖励1/10，共4候选。reward有global改善+bonus，否则-1。
D30/60000真实FE，8函数F1/F3/F6/F9/F12/F13/F22/F30，seed901–905。复用40格旧Batch作为Keep、40格旧B10作为外部参考（严格等价验证后），新跑4固定控制+4Q候选共320run，总10条件400质量记录。所有开发格公开。
若候选在函数均值与逐seed两口径均严格胜Keep、Random、Progress，按总函数胜场、总seed胜场、较小bonus/较小gamma优先选最简单候选，再冻结用seed1001–1010确认（8函数×10seed×Keep/Explore/Random/Progress/Reverse/选定Q/B10=560run）。未过门不扩组合。

## 验证
Keep严格等价包括奇数尾预算与多个维度；所有目标输入有界、预算独立计数；探索父代未被前缀访问，末行不同于原计划；reward对应唯一末FE；Q updates数=自由学习决策数、下一状态为下一实际决策，terminal零bootstrap、mask不学非法动作。几何仍为借用底座，候选是否值得论文化由结果与后续几何依赖消融决定。
