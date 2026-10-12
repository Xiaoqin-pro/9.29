# 已选短窗口+10 reward的Q访问计数学习率（2026-10-12）

前两个反馈duration方案与+10bonus有限开发均未过学习强门。Bonus10-100对Fixed6函数5:3/pair20:20、对alwaysQ6:2/27:13，比长窗口候选较好；仍败同Random/Eps。仅测试state/action访问信息用于更新平均，state/动作/reward/B10公式/half径不变。

原固定α=.1改为α(s,a)=1/(1+已发生eligibleQ更新计数)，然后计数+1。phase/state分组不混阶段，未训练healthy行保持0；nextstate discount仍.9^actualFE/100、terminal0。第一样本α=1，后续累计平均，非平稳收益可能使旧样本权重不适合，故需对照验证不能理论担保。原默认fixed模式必须逐点评价/Best/T/Q/RNG回归。

D50/100k八函数五原seed2201–2205，同p0/searchseed，40新run/4MFE，原560质量cached不算独立确认。2smoke F1/F13/600FE四worker单线程。只一项step-rate机制，不扫.01/.05/.2learningrate。保存RateLog，每更新独立用QVisits与nextstate重放。

候选平均rankstrict胜Fixed6/alwaysQ/100gateQ/Bonus10-100/100Random/2/4/Eps与500Random，各>=4/8均值不差、>=20/40seed不差、无双方>1e−8mean>10倍退化，才新seedconfirm；若fail本轮停止，不再连续扩state/reward/window。所有previous失败结果留存，五seed同格开发非显著/非劣，不把稳定/统计估计=修好。
