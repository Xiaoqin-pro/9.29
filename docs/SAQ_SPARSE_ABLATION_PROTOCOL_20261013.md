# 稀疏评价框架主消融协议（2026-10-13）

## 冻结目标及六版本

主贡献仅检验：同骨架下，稀疏真实评价是否改善有限预算质量；空间筛选是否优于同等稀疏成本的随机筛选。Q是辅助调度，不开展状态/奖励/alpha/gamma/epsilon/SRD扫描。主算法SAQ源码完全不改。

|版本|每完整轮实评|选择|配额/Q|Purpose|
|---|---|---|---|---|
|Dense-NoQ / FullEval-CSO|全部Tracing候选+全部4个新Seeking候选/父代|全评价|无Q、无稀疏配额动作|稀疏框架对照|
|RandomSparse-Fixed6|10|随机Tracing/Seeking选择、父代cap2|6T4S、无Q|几何选择对照|
|Fixed4 / SpatialSparse-Fixed4|10|原几何|4T6S、无Q|原固定配额参照|
|Fixed6 / SpatialSparse-Fixed6|10|原几何|6T4S、无Q|强固定及两条核心比较的共同参照|
|RandomQuota / SpatialSparse-RandomQuota|10|原几何|健康6T4S；停滞同阈值1000FE时随机2T8S/4T6S/6T4S、无学习|只一项Q非学习对照|
|Full / SAQ-CSO|10|原几何|原3×3 gateQ|当前主算法，870结果缓存|

所有搜索骨架保持N50/MR.4/SMP5/SRD.05/CDC.2、精英引导、Tracing衰减惯性、预先生成候选、真实锚点/接受规则。NoVirtual等已有可选分支不进入本轮矩阵。

## 消融定义和归因边界

1. Fixed6 vsDense：比较稀疏框架整体包，双方无Q。Dense评所有新候选，父代cap自然从2变4，完整轮成本变化、轮数变化都是删除稀疏框架的结果；不能把差异独归空间排序。
2. Fixed6 vsRandomSparse：同10FE、同6T4S、同cap2、同虚拟移动及real-anchor，只改变候选筛选；随机筛选使用独立screenRNG，不扰动候选生成随机流。Tracing保留真实评价顺序随机洗牌；Seeking评父代候选依固定parentorder、随机已选候选顺序。
3. Q辅助只FullvsFixed4/Fixed6/RandomQuota；三种对照不更换搜索公式。Full可能不胜Fixed6或RandomQuota，负面结果不隐藏，不把优于Fixed4写成学习不可替代。
4. 原始CSO属于外部基线，不作为NoSparse消融，避免精英/公式差异混入。
5. Dense不需要重评已可信父代副本；只4个newSeeking候选和1个Tracingtrial实评。相同budget进度用于所有候选公式，不能从500k轨迹截取100k替代独立100k设置。
6. 所有方法末轮按可用真实FE截断，不生成虚假适应度；best一定来自实评。无效mask/fallback在日志标注，原cap回退保持。

## 锁定科学比较与统计

PrimaryC1 Fixed6vsDense-NoQ、PrimaryC2 Fixed6vsRandomSparse-Fixed6；Secondary FullvsFixed4、FullvsFixed6、FullvsRandomQuota，共5×29=145配对检验，完整族Holm。同时给每比较29族校正便于理解，主要显著性用145族；每函数30seed raw误差双侧Wilcoxon（与已发布主表同normalapprox/tie/continuity规则）。Mean票数/逐seed票数/显著票数分开，不平均不同尺度函数的原误差做总score。

一张正文汇总表呈现误差平均排名、完成搜索轮数、实评占候选比例，全文29函数mean/std可补充。仅展示预定比较支持的范围，负面一样报告。可以画若干代表收敛图，但全部29图输出并保留，不用少数好图替代完整结果。

## 正式规模与缓存

CEC2017 F1/F3–F30、D50、100000真实调用、seed3001–3030、N50、4processworker每worker1thread。共同initSeed=261013000+fid*10000+seed/searchseed+1000000。初始种群50×50同池，初始化计FE。

Full主算法870run复用results/cec/saq_cso_formal_100k_30seed_study_20261013_083541，需原srcSHA匹配、p0精确一致、MAT/CSV一致。新五版本4350run/435M预算内调用；六版本共5220质量记录。smoke、独立best重查单列，不冒称5220新run。

正式入口必须通过当前sourceSHA绑定的test_SAQ_framework_ablation：原Full逐点/T/Best/RNG/Q完全等价；六版本的末轮、随机screen、无学习、父代候选唯一、Dense全候选独立见证；所有五新版本100k契约，固定版对独立ASE_CSO_ModeBudget精确匹配。

## 主性能表同步收窄

用户已指定五算法：SAQ-CSO、Original-CSO、CLPSO、HPSO-TVAC、SPSO2011。从原八算法raw固定子集重算rank和116检验族Holm；旧八表保留作为范围补充。报告主表子集是在已有全比较后指定，不隐去更强基线就声称全面先进。核心方法判定由本轮机制消融承担，不再新增外部算法。


## 实际启动与验收状态

2026-10-13完成33组冻结Full点/T/Best/RNG/Q精确对照、192项行为/候选唯一/cap/终轮契约；独立Dense首轮全候选见证、5个新版本100k及fixed4/fixed6对独立预算实现精确一致。集成smoke12次成功（含Full的小预算实跑，smoke不计正式）。

正式已启动results/cec/saq_sparse_ablation_30seed_study_20261013_133122；前168份独立MAT核验通过，后续全5220份验收尚待运行完成。本记录不是性能结论。

有限一次性后处理pipeline `experiments/finish_saq_sparse_ablation.ps1` 等待本批COMPLETED，随后执行独立验证+5预定比较，另起MATLAB重评全部5220个best并重建初始群体；只有都通过才写结果目录ACCEPTED.json。不是循环调参、不会再启动优化任务。中断可用run_saq_sparse_ablation_30seed('study',已有绝对目录)恢复；恢复要求冻结源码hash一致。
