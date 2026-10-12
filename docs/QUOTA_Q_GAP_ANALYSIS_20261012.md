# 带Q版失分定位与一次停滞介入修正（2026-10-12）

## 用户方向
用户纠正MR记忆：当前MR=.4固定，Q仅控制真实Tracing/Seeking评价配额。继续分析D50/100k全29函数五seed的Q差距，保留基础搜索方程和半径，不按弱MR基线制造收益。

## 已有完整集诊断
145matched真实Q/Fixed6/p0一致，Q总TraceFE份额41.11%，Fixed6约60%；Q约65.54%决策未达到1000FEstall，其中6T4S仅36.36%。它在健康状态也大量削减Tracing名额，不能把所有调配都描述为escape。

20%FE均值Q/Fixed6胜15:14，到60%8:21、80%10:19，终点13:16，提示中段开始广泛落后。最大函数均值比Q/Fixed6：F1=2.232、F6=1.598、F15=1.512、F11=1.323、F26=1.299、F30=1.247、F12=1.221。F11健康块93.78%，F30=92.32%，F1=74.38%，说明loss不只是持续局部最优。

actualcondition观察中中/后段action3的正reward率常更高，但动作与当前状态/历史路径混合，不能当counterfactual证明action3一定最佳。reward仅记录当前100FE有无gbest改善，未区分幅度/更长期作用；状态仅phase/stall也未充分区分资源需求。这些是机制疑点，不是目标调用或信用执行bug。

## 一个干预试验
healthy固定6，真实stall>=1000才启用Q；六state三action、100FE决策、±1reward、alpha.1/gamma.9/eps.1、初值0、原骨架不变。健康块forced不训练Q，stall块只记自己的收益；nexthealthy未训练Q=0，terminal0。

八诊断函数原seed2201–2205，200新run/20MFE，Fixed6/旧alwaysQ各40质量缓存（非新增或新seed确认）。59无改动逐点回归/75gate cases、10smoke通过；全200独立MAT/真实state/forced/free/eligible/terminal Q重放通过，80cachep0相同。当前无后台实验。

|gateQ对控制|函数均值胜/负|seed胜/负|
|---|---:|---:|
|旧全程Q|7/1|23/17|
|强Fixed6|3/5|15/25|
|同gate随机|3/5|16/24|
|stall固定切2T8S|4/4|22/18|
|stall固定切4T6S|2/6|16/24|
|stall同epsilon利用6|0/8|16/24|

七条件rank：GateEps6=2.75、GateRandom3.25、Fixed6=3.375、Gate2=4、Gate4=4.25、GateQ4.625、AlwaysQ5.75。联合Q必要性门未过；五seed同格development不能当正式显著/非劣。

GateQ确实比旧Q多数函数更好，误差比中位数.750、geometric.809，说明触发时机有可用的改进，但同gate随机和规则比Q更好，不能把gate收益写学习收益。GateQ约62.59%forcedhealthy、37.41%free；整体6T4S占75.26%，同随机75.4%，不只modefraction解释Q和Random差别。GateEps6总体6T4S97.53%，对Fixed6函数4:4/seed22:18，对旧Q7:1/27:13，也只是效率/开发观察。

## 可验证原因和下一步界限
当前损失至少两层：健康搜索中不必要分配扰动；真正stall时Q的响应仍不优于简单策略。仅减少介入已回收部分损失但未解决学习必要性。下一项若继续应针对stall action回报区分度，而非改变MR或更多搜索模式。gate候选保留为改进诊断，不替换原已完整集版、不直接进行paper成功冻结。

可以先比较stall reward是否只追逐小幅改善频率、与最终误差的关联，考虑一项pastwindow机会成本/同反馈规则或更合适信用时长；必须另协议、保持强Fixed6和同gateRandom/Eps，不能让Q靠偏先验或删baseline获胜。按用户简单论文目标，应停止同时调整state/reward/block/radius，不追加gate阈值网格。

## 交付
results/quota_q_gap_20261012/包含全145matchedpast诊断（healthy/phase/action回报，观测非因果）、200newraw/280quality缓存、complete summary/pairs/gate/source/behavior/independentchecks、原全29差距图、gate同控制图和八函数曲线。MAT/source_snapshot results/cec/quota_q_stall_gate_study_20261012_202002/；原fullQ/Fixed6缓存sources单列。协议QUOTA_Q_STALL_GATE_PROTOCOL_20261012.md先于运行保存。
