# 探索记录，不是正式成绩

这些CSV来自平台构造期，只有pso_confirmation.csv对应已验证的最终实现。
早期BuildScenarioTrial的初次参数遗漏K1导致试验中断，没有完整结果，未用于验收。
corridor/positive/holdout试验中MATLAB路径优先用了旧Fitness（h仍为[-12,12]），它们不能证明h[0,12]有效。全部保留注明，不作为正式新域成绩。
TrialCore/heterogeneous_trial是K1、旧对称h的探索。每组只有3次且实例仍未固定，不能做算法排名。
最终live_confirmation的30次来自正式工程Fitness，全部逐解重算和新随机种群核对；最终18个见证用于验证存在性，不进入任何随机种群。
