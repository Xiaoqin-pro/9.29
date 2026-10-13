# HPSO-TVAC/DMS-PSO新增对照及七算法结果（2026-10-13）

D50，100k真实FE，F1/F3–F30，30个种子3001–3030。HPSO N50；基础DMS N30（10×3），HIDMS N40，其余N50；共享50行初始池前缀，不假称同population。EPSO仍未加入。

|算法|平均函数均值排名|平均CPU秒/运行|
|---|---:|---:|
|HIDMS-PSO-IndexCorrected|2.103|3.316|
|DMS-PSO-SIS2005|2.379|1.887|
|HCLPSO-AuthorSource|2.586|2.126|
|SAQ-CSO|4.138|9.082|
|HPSO-TVAC-CEC|4.690|1.801|
|CLPSO-AuthorSource|5.138|2.407|
|Original-CSO-MR02|6.966|2.238|

|SAQ-CSO对照|函数均值胜/负|174检验族Holm显著好/差/未显著|
|---|---|---|
|Original-CSO-MR02|29/0|29/0/0|
|CLPSO-AuthorSource|25/4|18/1/10|
|HCLPSO-AuthorSource|6/23|0/16/13|
|HIDMS-PSO-IndexCorrected|2/27|0/19/10|
|HPSO-TVAC-CEC|17/12|16/5/8|
|DMS-PSO-SIS2005|4/25|1/17/11|

新增对照结论：SAQ对HPSO函数均值17:12、显著好/差/NS=16/5/8；对DMS为4:25、1/17/11。本套件SAQ平均排名第四，不能写整体领先所有PSO变体。完整不利结果保留，未删函数。

## 复现身份与更正

- HPSO采用2017EPSO包中独立HPSO_TVAC.m，保留无惯性、零速度重启、cap100、参考进度；增加已说明的CEC位置clip。不是2004原作者源代码的标签。
- DMS采用2005SIS基础版本，m3/R5/末期global、w .9→.2。公开DMS_PSO_func.m实际有DMS-L扩展，不能直接以其mask/Quasi-Newton/.729冒称基础版。
- 初次检查漏核对基础SIS惯性，正式混合批次1072条时停止。保留536条错误DMS历史，复用536条正确HPSO。修正参数、独立手算及source SHA验收后重跑DMS全870并补HPSO334，本轮有效新优化1204次。
- 原SIS论文没有完整给出c1/c2数值、初速和具体边界算子；取相关作者代码明确适配值，记录在hpso_dms_paper_parameter_audit.json，不声称精确复现原表。
- 每个方法29组point/T/Best/RNG/iteration oracle对照，并有独立首代、重启/cap、DMS分组/重组/切换与两个100k实例。来源/文献定义/代码参数的核验分开。
- 全6090 MAT记录核验通过；独立best重评最大差0；重新生成初始种群6090份全匹配；每run100k严格计数，smoke及审计调用分开。

结果目录：results/saq_cso_sevenway_30seed_20261013。旧五算法不覆盖。详尽协议：docs/HPSO_DMS_PROTOCOL_20261013.md。后续是否保留全部七对照或做消融由用户决定；没有自动新增调参实验。
