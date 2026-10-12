# 保守起步计数更新结果与本轮最终选择（2026-10-12）

VisitRate首sampleα1导致F30两个seed严重退化，试α=.1/(1+.1n)起步.1的单因素。40新run/4MFE，25defaulttrajectory精确对/25smooth update case、2smoke和全Q实际RateLog独立重放通过。首样本平滑并未解决问题：F30seed2203仍8.68M误差（Fixed6=.762M），均值2.527M（Fixed6=1.127M），未按函数删outlier。

Smooth对alwaysQ函数6:2/seed24:16，但对Fixed6=3:5/19:21，Bonus10-100=2:6/17:21（2平），同100Random3:5/16:24，门未过。该结果不支持选择Smooth作为当前较稳版本，也说明先前VisitRaterank更好不够抵消F30风险。

## 本次修正总计
200durationheld+80bonus+40visit+40smooth=360新增优化run/36M实际预算内FE，360Best重查/18smoke分别单列。所有其余记录为质量缓存或原日志诊断，不是新增独立样本。八函数五已用于开发seed2201–2205，非完整29或newseedconfirm。真实预算/域/trajectory/state/reward/discount/Q/visitRate全核验通过，无运行任务。

## 最终保留候选
选择较稳Bonus10-100作为开发候选：原B10骨架、SMP5/MR.4/原半径与Tracing、Q纯名额，healthy固定6，持续stall1000才Q100FE，真实gain+10/否则−1，原α.1/γ.9/ε.1/zeroInit、小6×3表。只保留已有限验证的健康保护与真实reward倍率，撤下held500/visit/smooth版本作主候选；所有代码/结果留作历史。不得把本轮candidate当已冻结/SCI成功。

Bonus10-100对原alwaysQ6:2/27:13，对上版100gateQ6:2/25:15，对Fixed6=5:3/20:20。相对Fixed6误差比中位.951、几何.968，F30mean1.093M比Fixed6=1.127M略低，未出现VisitRate那样的大mean退化；但F6明显更差，对同100Random4:4/16:24，同Eps3:5/18:22，学习强门仍未过。

因此诚实结论是原Q的部分损失可回收，Q本身的稳定增益仍欠缺。不能用candidate对CLPSO基础优势冒称Q贡献，不能拿原弱Fixed4或改MR的消融代替强Fixed6。下一轮如果继续，先原样完整29函数范围检查并保留同gateRandom/Eps/Fixed6/oldQ，或与导师讨论有限辅助Q定位；本轮不再扩reward/window/rate网格。

所有不利F30seed、全部16配置与source来源公開在results/quota_q_smooth_rate_20261012/（640质量记录中本目录新增仅40），其他阶段分别results/quota_q_episode_20261012/、quota_q_episode_bonus_20261012/、quota_q_visit_rate_20261012/。独立METATraces/source snapshots在各results/cec批次。
