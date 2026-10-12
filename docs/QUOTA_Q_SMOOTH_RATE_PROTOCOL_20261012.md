# Q计数学习率的保守首更新修正（2026-10-12）

VisitRate alpha1/visits开发对Fixed6=4:4/24:16，但F30两seed2202/2203误差7.22M/12.77M，均值4.579M vsFixed1.127M，不能只看rank采用。真实初次α=1导致单样本权重过大是实现设计问题非代码执行bug；不将归因当已证。只将递减rate改为α0/(1+α0*n)，α0=.1，n实际已更新state/action次数（首条.1），保留fixed和visit精确分支。等价初始0先验10份权重，不声称理论保证逃逸或非平稳最优。

原healthyFixed6/stall100FE/+10bonus、phase3×stallbit6×3/纯quota/MR.4/原search半径、γ.9/eps.1全不变。40新D50/100k八函数五seed2201–2205（4MFE），cached600旧quality不算新，2smoke，四worker单线程。nochange/fixed默认回归、smooth actualRateLog=.1/(1+.1QVisits)逐次重放、固定ruletrajectory中性，FE/域/Qgatecredit照旧检查。

全部十五控制与三个关键Q（原always/Bonus10-100/VisitRate）公开；门沿上一visit：rankstrict胜Fixed6/always/100gateQ/Bonus10-100/100Random/2/4/Eps及500Random，各>=4/8均值不差、>=20/40pair不差，无双方>1e−8均值>10倍退化。F30两个失败seed必须完整报告，不能新seed替掉。未过本轮停止不继续rate平滑网格，保留较稳候选而不叫已修好。seed已用于开发，非独立确认。
