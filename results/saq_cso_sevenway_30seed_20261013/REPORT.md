# SAQ-CSO七算法同预算比较结果（2026-10-13）

D50、100k真实FE、29函数、30新种子；所有函数均纳入，未删不利结果。
有效质量记录6090；独立MAT核验6090；870组初始种群共享；HIDMS取前40点，DMS取前30点，其余方法50点。

|算法|平均排名|平均CPU秒/运行|
|---|---:|---:|
|HIDMS-PSO-IndexCorrected|2.103|3.316|
|DMS-PSO-SIS2005|2.379|1.887|
|HCLPSO-AuthorSource|2.586|2.126|
|SAQ-CSO|4.138|9.082|
|HPSO-TVAC-CEC|4.690|1.801|
|CLPSO-AuthorSource|5.138|2.407|
|Original-CSO-MR02|6.966|2.238|

|SAQ对照|函数均值胜/负/平|配对seed胜/负/平|全比较族Holm显著好/差/未显著|
|---|---|---|---|
|Original-CSO-MR02|29/0/0|870/0/0|29/0/0|
|CLPSO-AuthorSource|25/4/0|677/193/0|18/1/10|
|HCLPSO-AuthorSource|6/23/0|213/657/0|0/16/13|
|HIDMS-PSO-IndexCorrected|2/27/0|160/710/0|0/19/10|
|HPSO-TVAC-CEC|17/12/0|569/301/0|16/5/8|
|DMS-PSO-SIS2005|4/25/0|212/658/0|1/17/11|

均值胜负不等于显著胜负。每函数30配对种子采用双侧Wilcoxon（正态近似、tie及连续性校正），全比较族Holm控制；附表同时给每对照29检验族校正。Friedman以29函数均值为block，不把870个seed当独立问题。

Friedman statistic=116.867, p=7.40986e-23。该总体差异检验本身不表示SAQ对每个方法更优。

SAQ运行时显著高于PSO基线；这里不支持同FE更快。CEC目标很便宜，候选生成/筛选时间不能忽略。不同补跑时段的CPU比较仅描述性报告。

Q日志从MAT重新统计；原CSV action share字段为NaN属于汇总缺失，不等于Q未执行。修复汇总后输出q_behavior.csv及q_tables.csv，原始CSV保留。

这批外部比较不证明新增Q优于固定6T4S，不证明稀疏筛选独立贡献；核心消融仍需同骨架Fixed4/Fixed6/同触发Random和无稀疏评价控制。标准500k、其它维度、无人机应用尚不在本结果范围。

HCLPSO主列已替换为作者MATLAB profile；旧Reference列另存historical_hclpso_reference_runs.csv，未删除。来源与32组逐点核验见docs/HCLPSO_AUTHOR_CORRECTION_20261013.md。

HIDMS为2020作者源码、N40、含公开注明的最佳从粒子局部索引修正；与N50算法共享初始前40点。同FE公平，但不假称完全相同人口规模。

新增HPSO-TVAC为2017独立baseline参考实现+公开披露的CEC位置clip；DMS为SIS2005基础版本的论文重建（N30、m3/R5/90%计划代切global），不是含Quasi-Newton的DMS-L-PSO。来源、逐点对照及独立手算见docs/HPSO_DMS_PROTOCOL_20261013.md。

本批新增1204次优化运行；HPSO已有有效536次缓存，已有五算法4350次经source/MAT/p0核验后复用。旧固定惯性DMS的536次记录另存并排除，不是凭性能挑版本。七算法平均排名与174个SAQ-vs-control检验族Holm重新计算，不与五算法116检验族结果混用。


## 独立重评与调用计数

另一个MATLAB进程重评6090个保存的best，最大差0；6090个初始群体按InitSeed重新生成并精确匹配。增加的6090次审计调用单列，不算入每run的100k优化预算。

本轮新增1204次有效优化：修正DMS870+补齐HPSO334；复用536次有效HPSO。错误惯性DMS的536次被保留为historical_superseded_dms_runs.csv并明确排除，原因是原文参数不符，未根据性能选择版本。有效七方法共6090质量记录；此前五方法记录4350不改动。

c1/c2、初速和边界的SIS原文信息不完整，所以DMS列应称论文定义重建与明确参数适配，不能称原作者原代码或已复现原论文表值。HPSO列来源2017独立baseline代码，新增CEC clip，也不冒称2004原作者精确实现。

发布逐seed CSV、均值标准差、统计、全部29函数图、来源哈希和审计记录；完整MAT和运行源码快照保留在本地results/cec。原五算法表仍可用于其原比较集合；七算法rank/174检验族Holm不能和旧rank/116族校正混用。
