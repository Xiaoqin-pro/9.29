# FCS 执行修复与开发验证（2026-10-12）

## 范围
用户确认继续自己的创新点，下一步修FCS。先恢复Continue/Switch真实行为，不把修bug当创新。旧src与历史结果保留到archive/fcs_repair_20261012/；当前改动在src/ASE_CSO_FCSQ.m。

## 已知执行缺陷与修复边界
1. selectStarters预选已经counts=1，主循环首访后再+1。预选仍保留原算法，只在预选后清零“实际评价计数”；每次真实评价后+1。usedRows仍保留所有预留starter行，不能提前抢该行。
2. odd targetSeek使用floor导致少一个FE。改ceil(targetSeek/2)；完整6Seeking仍3starter+3follow，奇数尾预算为ceil首访+floor跟随。总目标quota本轮填满，不另开虚假尾轮。
3. 其余候选生成、随机Tracing、原候选排序、精英/rollback、4T6S、6状态、二值奖励、alpha=.1/gamma=.9/epsilon=.1、即时followup nextState均保留。即时nextState仍是旧解释，不能宣称长期规划已正确；本轮不改变它。
4. Switch仍是“不同父代”，可以评该其他父代的第二候选，不等于Open未访问父代。真实动作日志明确标注。若要Open，另做后续单因素版本。
5. fallback保持旧逻辑和requested-action Q归因，只记录fallback/mismatch/QFallbackUpdates；发现非零时先解释执行问题，不声称Q学会了未执行动作。

## 同内核控制与B10地位
FCS用随机Tracing和原orderedCandidates；B10用几何Tracing/平衡near-far Seeking，不能把二者差异全归因顺序分配。batch/continue/switch/random/q使用同FCS内核；增加success(首访改善继续，否则换父代)/reverse规则是比较策略，不改变搜索公式。
保留老师几何候选排序用于本轮修复隔离；不将其作为学生创新，也暂不叠加新筛选/刷新模块。

## 执行诊断
RequestedAction/ExecutedAction/Fallback/父代/候选行/评价前父代次数/更新前anchor及实测值/二值reward/FE序号/nextState。计数一律是actual objective calls。记录实际同父代第二次、他父代第二次、打开新父代、最大父代2次、每轮目标与实际FE；随机组提供按阶段×首访反馈的条件动作成功率，Q组的内生选择样本不当反事实因果证据。
完整决策表只在诊断run启用，性能run关闭避免额外日志开销；标量统计始终保留。

## 运行前确定的验证与实验
A 行为测试：先用旧版重现57/59预算多开尾轮；修后验证N50/D7,D30,D100、budget50–61及400，7策略；batch与旧版目标调用序列/trace/最终rng严格一致；Continue每个正常跟随都同父代、前次数1；requested/actual一致或fallback可追；FE/monotone/bounds/Best独立复查；关闭/开启诊断不改变轨迹或rng。
B 诊断：CEC2017 F1/F6/F12，D30/12000FE，seed901，7个FCS策略（batch/continue/switch/random/success/reverse/q），记录完整动作；21run。
C 主开发pilot：CEC2017 F1/F3/F6/F9/F12/F13/F22/F30，D30/60000FE，seed901–905，8方法（B10-Reference和7 FCS策略），4个本地worker；320run。初始化/搜索随机流分开，同问题seed初始N50种群相同；保留全部结果，不据pilot参数调优后当独立验证。
合计341性能/诊断run，另有小规模行为测试。不是全29函数验证；先看是否能超过随机和合理固定规则，再决定扩全集/几何依赖/真正Open版本。

## 判据
修复验收=实际计数/动作可追且每轮FE达配额；创新验收不同：Q须在最终质量上相对合理固定/随机有可重复增益；只有local success或Q值变化不足以支持。旧Continue/Switch完全重合的数据不能继续否定原机制，也不保证修后必然有收益。
