# 复现与正式结果核验入口（2026-10-13）

## 方法身份

|方法|本轮身份|N|源码核验|
|---|---|---:|---|
|Original CSO|仓库原始CSO，MR=.2|50|保持原实现，不称严格复现某篇CSO表值|
|SAQ-CSO|已冻结稀疏CSO+停滞配额Q候选|50|源码与运行前快照匹配，870份Q轨迹与更新逐条重放|
|CLPSO|作者公开MATLAB代码profile|50|既有oracle与D50入口核验，不混用旧clip适配版|
|HCLPSO|作者公开MATLAB代码profile，15/35分组|50|32组逐点输入/全T/Best/RNG/迭代数匹配；旧NEORL移植版单独保留|
|HIDMS-PSO|2020作者MATLAB代码+声明一行best-slave索引修正|40|35组源码对照；实际masterhelper、突变端点、单元分组和两个100k实例|

“代码profile正确适配”不等于已经复现原论文的表值；本轮是统一CEC2017/D50/100k协议。

## 可重新执行的前置核验

```powershell
python experiments/prepare_baseline_oracles.py
matlab -batch "addpath(pwd);setup_project(true);test_CLPSO_D50_adapter;test_HCLPSO_author_adapter;test_HIDMS_adapter;"
```

prepare脚本按固定commit和SHA256下载源文件、建立机械oracle；不修改正在使用的算法文件。源文件和测试fixture保存在work中。

## 核验范围

1. 来源：固定commit、下载文件SHA256、未经修改作者源码、运行前source_snapshot。
2. 搜索行为：oracle对照、随机调用顺序、边界、示范、分组、终止截断；HIDMS索引修正单独披露并实际执行该分支检查。
3. 正式数据：每份MAT与CSV匹配、T完整有限单调、严格100k实调、p0共享及合法域、节点值、返回best；SAQ所有state/reward/gate/terminal-Q重放。
4. 独立工程校验：60份官方D50旋转/置乱输入hash；原MEX身份固定；全部有效方法返回best另进程重评，并用InitSeed重建每个初始种群。
5. 统计：每函数30配对seed，完整29函数；主表报告均值/标准差、中位数、函数平均排名；双侧Wilcoxon和跨对照Holm族控制；不把870seed当870独立函数，不把均值胜场当显著胜场。

仍有边界：这些检查提高当前实现和数据的可信度，不能证明一切可能输入下绝对无bug，或证明SAQ在其它预算/维度/SOTA基线上全面更优。对Q和稀疏评价的独立归因仍需要同骨架消融。
