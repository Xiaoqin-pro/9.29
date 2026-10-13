# 稀疏评价框架六版本消融（2026-10-13）

CEC2017 D50、100k真实FE、29函数、30种子。均值票数与显著票数分开。

|方法|平均函数均值排名|平均秒/运行|
|---|---:|---:|
|SpatialSparse-RandomQuota|2.483|8.151|
|SAQ-CSO|2.621|9.082|
|SpatialSparse-Fixed6|2.966|8.345|
|SpatialSparse-Fixed4|3.103|8.510|
|FullEval-CSO|4.862|2.305|
|RandomSparse-Fixed6|4.966|8.338|

|比较（左vs右）|均值胜/负|配对seed胜/负|全族Holm显著好/差/NS|
|---|---|---|---|
|SpatialSparse-Fixed6 vs FullEval-CSO|24/5|654/216|13/0/16|
|SpatialSparse-Fixed6 vs RandomSparse-Fixed6|26/3|601/269|9/3/17|
|SAQ-CSO vs SpatialSparse-Fixed4|17/12|465/405|0/0/29|
|SAQ-CSO vs SpatialSparse-Fixed6|18/11|443/422|0/0/29|
|SAQ-CSO vs SpatialSparse-RandomQuota|13/16|423/441|0/0/29|

全比较族145项Holm；Friedman以29函数均值为block，stat=51.8177,p=5.87965e-10，不是每个seed当独立问题。

主要证据是无Q的FullEval→RandomSparse→SpatialSparse链；固定6的筛选对照才隔离geometry。Dense父代cap4及完整轮成本变化属于删除稀疏框架的自然包差异，不能全部归空间排序。
Q仅作3项辅助控制。若不胜Fixed6/RandomQuota，主文应限制Q新增收益描述，不通过省略强固定或随机控制声称必要性。没有奖励/状态/学习率调参。
所有六条件搜索公式、初始化、N50、MR.4、预算进度一致；Dense无虚假fitness，全部新候选真实评价；RandomSparse仅变筛选，cap2/配额6同Fixed6。
Full870使用冻结主结果缓存，独立p0/T/Q核验；本轮新4350run，不称5220新优化。实评及额外审计调用分列。
30seed3001–3030，D50/100k。所有29函数纳入；末轮预算截断。本文主对照五算法范围已固定，不增加外部方法。


## 已完成结果与可写结论

- 主框架C1：SpatialSparse-Fixed6对FullEval均值24胜5负，654/216配对seed；145族Holm后13显著好、0显著差、16未显著。中位函数均值误差比0.876（描述性跨函数比值）。双方无Q，同搜索骨架，支持这一D50/100k场景下稀疏框架整体价值。
- 空间筛选C2：对RandomSparse-Fixed6均值26胜3负，601/269配对seed；9显著好、3显著差、17未显著。三个更差函数F6/F9/F27全部如实保留。相同10FE/轮、6T4S、cap2及虚拟/锚点规则，支持geometry相对于随机选择的总体收益，不能说每函数均优。
- Q辅助：Full对Fixed4均值17:12、对Fixed6为18:11、对RandomQuota13:16；三组145族Holm均无显著函数。RandomQuota平均排名2.483，Full2.621。数据没有证明学习替代随机选择的必要性；未显著也不证明等效。保持Q为主算法辅助调度可描述，但不把整体收益归Q或隐去RandomQuota。

## 资源/运行时边界

全评价平均714.4轮，每轮约139.9次实评；稀疏版9995轮，每完整轮10次实评，约为全评价轮数的14倍。稀疏实评占所生成新候选约7.14%，这是候选评价比例，不是“评价20%的粒子”。算法各自总FE都100k，不能把此比例说成整次运行减少92.86%总FE。

FullEval平均2.305秒，空间Fixed6为8.345秒，完整SAQ为9.082秒（SAQ取此前批次缓存，不严格归因时间差）。稀疏框架在廉价CEC上没有CPU速度优势，收益是同真实FE预算下的质量及更多搜索轮次。候选生成/几何排序仍耗时，不声称同FE更快。

## 完整验收与数据范围

5220份MAT/CSV/FE/每轮计数/状态奖励/终端Q记录独立核验通过；870份缓存Full的轨迹与Q精确匹配。另一个MATLAB进程重评5220个best，最大差0，按seed重建5220个初始种群也全部匹配。增加5220次审计objective调用单列，不算各优化run的100k预算。

新优化4350、缓存870；全部29函数×30seed保留。完整MAT与source_snapshot在本地results/cec保留，发布逐seedCSV、mean/std、机制计数、预定比较、图和核验记录。主性能五算法表与本六版本消融是不同comparison family，平均排名不能混用。

此批不增加新机制、没有再调Q超参数。下一研究决策应基于上述范围，稀疏框架是当前最强结论；三维无人机应用尚未作为本结果证据。
