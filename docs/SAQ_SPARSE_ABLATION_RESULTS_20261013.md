# 稀疏框架消融最终结果（2026-10-13）

D50、100k真实FE、CEC2017 F1/F3–F30、30seed3001–3030、N50。六版本5220份有效记录（新4350+缓存Full870），无失败；不删不利函数、不修改搜索机制。

|预定比较（左vs右）|均值胜/负|145项Holm显著优/劣/NS|
|---|---:|---:|
|SpatialSparse-Fixed6 vs FullEval-CSO|24/5|13/0/16|
|SpatialSparse-Fixed6 vs RandomSparse-Fixed6|26/3|9/3/17|
|SAQ-CSO vs SpatialSparse-Fixed4|17/12|0/0/29|
|SAQ-CSO vs SpatialSparse-Fixed6|18/11|0/0/29|
|SAQ-CSO vs SpatialSparse-RandomQuota|13/16|0/0/29|

## 主要结论

1. 稀疏评价框架：无Q的SpatialFixed6胜FullEval24:5、显著13/0/16，支持同骨架有限评价资源下的整体价值。全评价完整轮评全部1Ttrial及4Snewcandidates，cap和轮成本变化属删除框架的自然整体差异；不能单归geometry。
2. 空间筛选：同10FE/6T4S/cap2/虚拟锚点下，SpatialFixed6胜RandomSparse26:3、显著9/3/17。F6/F9/F27更差是边界，不宣称万能筛选。
3. Q仅有轻微均值变化，Full不胜RandomQuota总体；RandomQuota平均排名2.483、Full2.621、Fixed6 2.966、Fixed4 3.103、FullEval4.862、RandomSparse4.966。所有Q比较Holm后无显著函数；无法声称学到比随机不可替代的收益，也不能把未显著写成等效。

## 机制与性能边界

- FullEval平均714.4轮，稀疏9995轮。每个稀疏完整轮10trueFE；全评价约139.9FE/轮。
- 稀疏真实评价/新生成候选约7.14%。不是评价20%粒子，也不是全run目标总调用少于100k。
- FullEval平均2.305秒，SpatialFixed6约8.345，Full约9.082（缓存先前批次）。不支持同FE CPU更快，论文讲有限真实评价资源效率和质量，不把CPU额外开销藏掉。

## 核验

5220MAT完整独立检查，870缓存逐轨迹和Q精确匹配；所有best另进程重评最大差0；5220种群按seed重新生成均匹配。新优化4350/435M实际FE；缓存870/87M先前FE；独立best审计新增5220次单列，不冒称新5220优化。

完整结果：results/saq_sparse_framework_ablation_30seed_20261013/REPORT.md。五算法主比较另在results/saq_cso_main_five_30seed_20261013，不混不同平均rank或统计校正family。

本批只统计和发布，不执行新参数开发或无人机实验。
