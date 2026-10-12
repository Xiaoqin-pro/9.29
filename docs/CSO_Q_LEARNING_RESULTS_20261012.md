# 配额Q学习行为诊断与统一初值结果（2026-10-12）

## 精确重放
原effQ40run/40000决策用原独立策略RandStream按原更新时点重放，所有explore/greedy所选action、最终Q与QVisits精确一致；新初值40run也完整重放。没有执行/状态信用错误。

原Q epsilon探索9.94%，greedy state重访换action63.81%，上次该state负reward后换75.73%，正reward后2.90%；top-two greedy gap<.1占72.19%，gap中位.0453。未访问action的初始optimism每run仅约7次，不能归因全部非平稳轮换为初值。标准epsilon-greedy并不保证整个search仅10%动作变化。

## 一项有限实验
reward=[−1,1]、gamma=.9，uniform lower-return bound−1/(1−gamma)=−10。同格40新run/4M预算内FE，原十一条件440质量记录缓存（不算独立确认），两smoke与40Best重查单列。111 default0逐点等价、109行为/flat Bellman下界/terminal检查通过。对所有action给同prior，不给6T4S优势。状态/窗口/动作/搜索公式/reward/alpha/gamma/epsilon都固定；仅改变初值。

行为显著不同：greedy状态重访换action63.8%→10.9%；gap中位.0453→.8393；gap<.1占72.2%→10.0%；负reward后换action75.7%→11.9%。但正reward块16.08%→15.76%，三action整体份额仍近30/34/37，不保证按state选正确配置。

## 质量与选择
LowerInit对原effQ函数4:4、seed18:22；Fixed6仅1:7、13:27；EpsFixed2:6、13:27；effrule3:5、16:24；Random3:5、20:20。十二条件rank7.0，比effQ5.875差，强五控制联合门未过。

Q0“常换”是观测问题，减少换action并未改善quality；偏悲观初值可能更早锁定，不证明稳定=有效。恢复原zero initializer，不继续扫描−1/−5/−20等值，不按函数选init。五seed开发非显著/非劣、缓存原seed不是新seed验证，未开展未过门独立确认。

## 下一项研究判断
当前纯quota接口、三配额和强固定对照保留。已有phase/prevsuccess、连续stall、mode efficiency、奖励和init多个有界结果都未稳定胜Fixed6/EpsFixed，不能继续只靠调一个数宣称Q创新成立。下一项若继续应明确针对“动作收益如何可辨”和长/短反馈间隔的机制问题，而非扩大Q表、半径或init网格。可先在固定控制中检查真实100FE行为回报的区分度、与末端质量的对应，讨论是否改成配额转换/局部决策而保持小Q。需要另写目标与协议，不把本轮失败当代码bug或成功。

## 交付
results/cso_q_learning_20261012/包含原/新40000choices各自explore标签、state revisit/gap/visit/reward、exact replay checks、40新raw/十二条件summary/原440缓存来源、全部pair/gate/源码hash/行为与误差图。MAT/source_snapshot本地results/cec/cso_q_initial_value_study_20261012_175304/。全部优化与诊断已结束，无运行任务。
