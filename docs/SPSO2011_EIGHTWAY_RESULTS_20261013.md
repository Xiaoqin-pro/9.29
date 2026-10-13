# SPSO-2011新增对照及八算法结果（2026-10-13）

CEC2017、D50、100k真实评价、F1/F3–F30、30个seed3001–3030。SPSO采用官方pure-standard C参考，N40、K3、KISS、uniform-radius、wall速度-.5，native-MEX调用同一CEC2017目标；不加local-search。源码与标准说明核验见SPSO2011_PROTOCOL_20261013.md。

## 新增结果

SAQ对SPSO：函数均值胜/负17/12；配对seed457/413；全203项Holm族显著好/差/NS=5/7/17。不能把17个均值胜场写成17个显著胜场，不支持稳定显著整体领先SPSO。

|算法|平均函数均值排名|平均CPU秒/运行|
|---|---:|---:|
|HIDMS-PSO-IndexCorrected|2.138|3.316|
|DMS-PSO-SIS2005|2.621|1.887|
|HCLPSO-AuthorSource|2.724|2.126|
|SAQ-CSO|4.552|9.082|
|SPSO-2011-OfficialC|4.862|2.558|
|HPSO-TVAC-CEC|5.310|1.801|
|CLPSO-AuthorSource|5.828|2.407|
|Original-CSO-MR02|7.966|2.238|

SPSO为native-C，其它控制器为MATLAB，CPU时差不能全部归因算法机制。主要对比基于相同真实目标调用。

## 全比较

|SAQ对照|函数均值胜/负|全203检验族Holm显著好/差/NS|
|---|---|---|
|Original-CSO-MR02|29/0|29/0/0|
|CLPSO-AuthorSource|25/4|17/1/11|
|HCLPSO-AuthorSource|6/23|0/15/14|
|HIDMS-PSO-IndexCorrected|2/27|0/18/11|
|HPSO-TVAC-CEC|17/12|15/5/9|
|DMS-PSO-SIS2005|4/25|1/17/11|
|SPSO-2011-OfficialC|17/12|5/7/17|

## 复现核验

原始官方C包/标准PDF hash固定；原C内核只改接口、共用p0、seed、维度容量和严格FE/日志；纯标准参数无更改。34组C/MATLAB point/T/Best/KISS状态/邻域重建/iteration匹配（跨语言浮点容差披露），2组100k deterministic-native-repeat逐点/T/Best一致；构建脚本独立重建binary也匹配。无失败正式870run。

八方法6960份MAT/CSV/FE/源hash/p0/bounds核验通过，独立返回best重评最大差0，重建初始群体6960份均匹配。30而非51seed，未称完整官方竞赛协议。SPSO/HIDMS N40，DMS N30，其余N50；共用50点池前缀，人口差异明确。

完整结果results/saq_cso_eightway_30seed_20261013；旧五/七算法表保留。八算法203检验族Holm不能与旧族票数混用。

主方法SAQ参数未改变；这批外部数据不替代稀疏筛选/Q的同骨架消融，也不支持SOTA或所有预算泛化。
