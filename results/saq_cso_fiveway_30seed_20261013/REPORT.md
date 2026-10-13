# SAQ-CSO同预算比较结果（2026-10-13）

D50、100k真实FE、29函数、30新种子；所有函数均纳入，未删不利结果。
有效质量记录4350；独立MAT核验4350；870组初始种群共享（HIDMS如加入则共享前40点）。

|算法|平均排名|平均CPU秒/运行|
|---|---:|---:|
|HIDMS-PSO-IndexCorrected|1.517|3.316|
|HCLPSO-AuthorSource|1.897|2.126|
|SAQ-CSO|2.862|9.082|
|CLPSO-AuthorSource|3.724|2.407|
|Original-CSO-MR02|5.000|2.238|

|SAQ对照|函数均值胜/负/平|配对seed胜/负/平|全比较族Holm显著好/差/未显著|
|---|---|---|---|
|Original-CSO-MR02|29/0/0|870/0/0|29/0/0|
|CLPSO-AuthorSource|25/4/0|677/193/0|18/1/10|
|HCLPSO-AuthorSource|6/23/0|213/657/0|0/16/13|
|HIDMS-PSO-IndexCorrected|2/27/0|160/710/0|0/19/10|

均值胜负不等于显著胜负。每函数30配对种子采用双侧Wilcoxon（正态近似、tie及连续性校正），全比较族Holm控制；附表同时给每对照29检验族校正。Friedman以29函数均值为block，不把870个seed当独立问题。

Friedman statistic=92.331, p=4.20916e-19。该总体差异检验本身不表示SAQ对每个方法更优。

SAQ运行时显著高于PSO基线；这里不支持同FE更快。CEC目标很便宜，候选生成/筛选时间不能忽略。不同补跑时段的CPU比较仅描述性报告。

Q日志从MAT重新统计；原CSV action share字段为NaN属于汇总缺失，不等于Q未执行。修复汇总后输出q_behavior.csv及q_tables.csv，原始CSV保留。

这批外部比较不证明新增Q优于固定6T4S，不证明稀疏筛选独立贡献；核心消融仍需同骨架Fixed4/Fixed6/同触发Random和无稀疏评价控制。标准500k、其它维度、无人机应用尚不在本结果范围。

HCLPSO主列已替换为作者MATLAB profile；旧Reference列另存historical_hclpso_reference_runs.csv，未删除。来源与32组逐点核验见docs/HCLPSO_AUTHOR_CORRECTION_20261013.md。

HIDMS为2020作者源码、N40、含公开注明的最佳从粒子局部索引修正；与N50算法共享初始前40点。同FE公平，但不假称完全相同人口规模。


## 独立重评验收与发布

另一个MATLAB进程重新评价4350个保存最优解，最大差值0；按InitSeed重建4350个初始种群也全部匹配。增加的4350次审计调用单列在independent_matlab_recheck.json，不计入各优化run的100k预算。

本目录是最终五算法表。此前四算法/HCLPSO Reference的平均排名或Holm校正来自不同比较族，不能与此表混用。旧HCLPSO Reference的870份逐seed结果在historical_hclpso_reference_runs.csv保留。

发布范围包括4350份逐种子质量数据、所有29函数汇总、统计、收敛节点和核验记录。完整FE轨迹/运行前源码快照/MAT仍在本地results/cec，不包含在本次GitHub结果上传中；source_manifest.json保留来源哈希。数值表可单独从上传CSV复算：

```powershell
python experiments/verify_uploaded_saq_statistics.py results/saq_cso_fiveway_30seed_20261013
```
