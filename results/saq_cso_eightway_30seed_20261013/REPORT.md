# SAQ-CSO八算法同预算比较结果（2026-10-13）

D50、100k真实FE、29函数、30新种子；所有函数均纳入，未删不利结果。
有效质量记录6960；独立MAT核验6960；870组初始种群共享；SPSO/HIDMS取前40点，DMS取前30点，其余方法50点。

|算法|平均排名|平均CPU秒/运行|
|---|---:|---:|
|HIDMS-PSO-IndexCorrected|2.138|3.316|
|DMS-PSO-SIS2005|2.621|1.887|
|HCLPSO-AuthorSource|2.724|2.126|
|SAQ-CSO|4.552|9.082|
|SPSO-2011-OfficialC|4.862|2.558|
|HPSO-TVAC-CEC|5.310|1.801|
|CLPSO-AuthorSource|5.828|2.407|
|Original-CSO-MR02|7.966|2.238|

|SAQ对照|函数均值胜/负/平|配对seed胜/负/平|全比较族Holm显著好/差/未显著|
|---|---|---|---|
|Original-CSO-MR02|29/0/0|870/0/0|29/0/0|
|CLPSO-AuthorSource|25/4/0|677/193/0|17/1/11|
|HCLPSO-AuthorSource|6/23/0|213/657/0|0/15/14|
|HIDMS-PSO-IndexCorrected|2/27/0|160/710/0|0/18/11|
|HPSO-TVAC-CEC|17/12/0|569/301/0|15/5/9|
|DMS-PSO-SIS2005|4/25/0|212/658/0|1/17/11|
|SPSO-2011-OfficialC|17/12/0|457/413/0|5/7/17|

均值胜负不等于显著胜负。每函数30配对种子采用双侧Wilcoxon（正态近似、tie及连续性校正），全比较族Holm控制；附表同时给每对照29检验族校正。Friedman以29函数均值为block，不把870个seed当独立问题。

Friedman statistic=129.667, p=7.3785e-25。该总体差异检验本身不表示SAQ对每个方法更优。

SAQ平均运行时高于PSO基线（描述性统计，不代表做过运行时显著性检验）；这里不支持同FE更快。CEC目标很便宜，候选生成/筛选时间不能忽略。不同补跑时段的CPU比较仅描述性报告。

Q日志从MAT重新统计；原CSV action share字段为NaN属于汇总缺失，不等于Q未执行。修复汇总后输出q_behavior.csv及q_tables.csv，原始CSV保留。

这批外部比较不证明新增Q优于固定6T4S，不证明稀疏筛选独立贡献；核心消融仍需同骨架Fixed4/Fixed6/同触发Random和无稀疏评价控制。标准500k、其它维度、无人机应用尚不在本结果范围。

HCLPSO主列已替换为作者MATLAB profile；旧Reference列另存historical_hclpso_reference_runs.csv，未删除。来源与32组逐点核验见docs/HCLPSO_AUTHOR_CORRECTION_20261013.md。

HIDMS为2020作者源码、N40、含公开注明的最佳从粒子局部索引修正；与N50算法共享初始前40点。同FE公平，但不假称完全相同人口规模。

新增HPSO-TVAC为2017独立baseline参考实现+公开披露的CEC位置clip；DMS为SIS2005基础版本的论文重建（N30、m3/R5/90%计划代切global），不是含Quasi-Newton的DMS-L-PSO。来源、逐点对照及独立手算见docs/HPSO_DMS_PROTOCOL_20261013.md。

本批新增1204次优化运行；HPSO已有有效536次缓存，已有五算法4350次经source/MAT/p0核验后复用。旧固定惯性DMS的536次记录另存并排除，不是凭性能挑版本。八算法平均排名与203个SAQ-vs-control检验族Holm重新计算，不与五算法116检验族结果混用。

新增SPSO-2011采用官方纯标准C内核，N40、K3、KISS、均匀方向/半径、边界速度-.5，不采用MATLAB扩展local-search。新优化870run，全8方法6960质量记录。纯标准定义/34组跨语言核验/2组100k重复见docs/SPSO2011_PROTOCOL_20261013.md。Native-C控制器与其它MATLAB控制器的CPU时差不可全部归算法机制。


## 独立返回解重评与发布验收

另一个MATLAB进程重评6960个保存best，最大差0；按InitSeed重新生成全部6960个初始群体亦精确匹配。新增6960次审计objective调用单列在independent_matlab_recheck.json，不算入每次100k优化预算。

本轮只新增SPSO870次优化；已有七算法6090次记录经MAT/sourcehash/p0一致性核验复用。八算法平均排名、203个SAQ-vs-control检验的Holm全部重算，不能混用七算法174检验族或五算法116检验族的显著票数。原五/七算法发布目录不覆盖；旧错误DMS记录原因及数据另外保留，未按性能排除。

SAQ对SPSO函数均值17:12、配对seed457:413、全203族Holm显著好/差/未显著=5/7/17。支持相近竞争力和均值排名略好，但不支持新增Q收益或稳定显著优于标准SPSO2011。

逐seedCSV、全部函数汇总、图、Q日志统计、primary-source provenance及verification输出公开；完整MAT/原代码和native binary在本地results/cec、work保留。构建脚本可下载固定checksum官方源，再按本机MATLAB/MinGW编译；重建后必须再跑34组跨语言核验。CPU比较明确native-C控制器实现差异，仅描述性报告。

```powershell
python experiments/verify_uploaded_saq_eightway.py results/saq_cso_eightway_30seed_20261013
```
