# SAQ-CSO五算法正式对比结果（2026-10-13）

本轮结果已完成并独立核验：CEC2017 F1/F3–F30，D50，每次100000真实FE，30个种子3001–3030。主表5个算法，共4350份质量记录；原始算法文件与数据不因胜负删改。

|算法|平均函数均值排名|平均CPU秒/运行|
|---|---:|---:|
|HIDMS-PSO-IndexCorrected|1.517|3.316|
|HCLPSO-AuthorSource|1.897|2.126|
|SAQ-CSO|2.862|9.082|
|CLPSO-AuthorSource|3.724|2.407|
|Original-CSO-MR02|5.000|2.238|

|SAQ-CSO对照|函数均值胜/负|全116检验族Holm显著好/差/未显著|
|---|---|---|
|Original-CSO-MR02|29/0|29/0/0|
|CLPSO-AuthorSource|25/4|18/1/10|
|HCLPSO-AuthorSource|6/23|0/16/13|
|HIDMS-PSO-IndexCorrected|2/27|0/19/10|

SAQ-CSO明显改善仓库原CSO，在多数函数优于CLPSO；作者HCLPSO和HIDMS-PSO总体更强。因此不能写成优于所有PSO变体或当前最优算法。外部对比尚不能把收益单独归因Q或稀疏筛选，同骨架消融仍需要Fixed4、Fixed6、同触发Random及无稀疏评价控制。

## 复现更正

- HCLPSO：首次NEORL移植版未做充分行为对齐，主表已改用作者MATLAB profile，32组逐点/全T/Best/RNG/迭代数对照通过，870run重新完成；旧列独立保留。
- HIDMS-PSO：使用2020作者源码；其异构单元要求population为8的倍数，故N40，其余方法N50，共享50点初始池前40点。最佳slave局部索引一行修正公开披露；35组核验，包括实际helper、突变/拓扑、两个100k实例。不是未说明的忠实原源码标签。
- 全4350MAT/CSV/FE/初始群体/节点/边界一致，870个Q版本的870000次决策及Q更新重放通过。
- 独立重新评价4350个best、重建4350个初始群体均通过；best最大差0。
- 60份D50输入文件hash全部匹配。

完整结果：results/saq_cso_fiveway_30seed_20261013/REPORT.md。逐seed数据all_quality_runs.csv、主表summary.csv及paper_mean_std.csv、统计function_comparison.csv、图all29_convergence.png、source_manifest.json和独立核验记录均在同目录。

本次上传结果而非完整运行归档；完整MAT和源快照在本地results/cec保留。没有启动新的消融或算法调参，等待用户决定下一步。
