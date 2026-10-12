# 简洁性删除试验：去触发与去停滞位（2026-10-12）

用户明确机制越简单越好。本轮先删除模块，不添加额外算子。200新run/20MFE，D50/100k八函数五原seed2201–2205，120旧质量cached（非独立确认），200Bestrecheck/10smoke单列。213旧entry精确回归、140deletioncases和10logneutral通过，全部200独立MAT/state/reward/Qterminal/FE检查和120真实cachedp0对齐。

原search骨架与radius不变，真实改善reward+10/否则−1、α.1γ.9eps.1；SimpleQ6删healthyFixed6 gate，全程phase3×stallbit6×3学习；SimpleQ3再删stallbit，phase3×3学习。两个都未过同chanceFixed6/Random/Phase/Eps强门。

Q6对旧gated+10函数2:6/seed16:24，对Fixed6=2:6/15:25，对同Random4:4/18:22；虽比旧reward±1全程Q5:3/21:19，未足够。Q3对Q6=1:7/15:25，对gated+10=1:7/11:29，对Fixed6=2:6/13:27。不能因为表小就选择phase-only。

八条件rankFixed6/gated+10=3.25，Phase3.5，Q6/Random4.5，Eps5.0，旧Q5.375，Q3=6.625。结果说明当前有效机制的删除代价：触发安排与真实stall信号均有价值，而不是所有复杂部分都能无损删。

因此后续只做更针对性压缩：实际停滞才训练Q，正常state三行始终zero可精确移除；保留一次stall检测healthyFixed6，用phase3行×两动作(4T6S/6T4S)的3×2表删除弱2T8S动作，所有same2actionRandom/Eps/Rule4保留。这是结构精简和action删除，不叠新reward/window/rate。新协议QUOTA_Q_COMPACT_PROTOCOL_20261012.md先写；是否有效待实测。

公开results/quota_q_simplicity_20261012/完整raw、oldcachequality/summary/pairs/gate/checks/source及two candidate图，全MAT/source_snapshot在results/cec/quota_q_simplicity_study_20261012_223743/。五seed同格development非significance/noninferiority，negative results保存。
