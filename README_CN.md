# 三维无人机配送：八个MATLAB文件

本目录仅保留 `data/`、`results/`、八个MATLAB文件和本说明。
按胎儿心电项目的习惯写：参数直接设置，数组保存粒子，for循环更新，不用配置类或实验管理器。

## 运行

```matlab
cd('D:\111\Desktop\噜噜\9.29');
main
```

主程序开头：

```matlab
runComparison = false;
```

false：默认多峰地图、20站点、20粒子、100代PSO。`cfg.terrainType`设1/2/3切换山脊沟谷/多峰/秦岭。
true：读取已保存的三地图×六场景，直接for循环运行PSO、CSO、CLPSO、GWO。
对比参数在main开头直接写：

```matlab
runs = 5;
comparisonParticles = 12;
maxEvaluations = 240;
mapIDs = 1:3;
caseIDs = 1:6;
warmStart = true;
plotComparison = true;
comparisonSeed = 20261003;
```

这组参数是小预算对比；正式重复数和预算由用户修改，不代表已经做完正式30次实验。
四算法共用同一个初始矩阵、编码与评价，初始种群包含在搜索评价预算内。CSO的每个新候选也单独计数，收敛横轴按完整Fitness评价次数。
每批比较保存到独立时间戳目录，包含原始MAT、raw_runs.csv、summary.csv、代码和输入快照。

## 八个文件的职责

| 文件 | 内容 |
|---|---|
| main.m | 参数、建模、共同初值、运行算法、保存、简短统计；底部为初值/统计局部函数 |
| CreateModel.m | 读取地图、固定站点、时间窗及圆柱威胁区 |
| Fitness.m | 排序键解码、lambda/d/h转XYZ、三维几何与配送时刻评价 |
| PlotSolution.m | 路线、站点编号、时间窗、对比收敛和箱线图 |
| PSO.m | 连续粒子群的初始化、pbest/gbest与速度更新 |
| CSO.m | 猫群的Seeking/Tracing更新 |
| CLPSO.m | 逐维综合学习粒子群 |
| GWO.m | 三领导者灰狼更新 |

四算法直接写初始化循环，不再调用SwarmStart。它们接收main准备的 `state.initialPopulation`。
一般评价接口为：

```matlab
[cost,detail] = Fitness(position,model,state);
```

其中position是归一化连续向量：订单排序键 + 所有航段的lambda/d/h。
main中的引导初值使用：

```matlab
[~,path] = Fitness(points,model);
```

两参数只评价XYZ折线，内部调用同一套几何实现；不计算订单时间窗，也不是完整配送搜索评价。
这样不需要独立的DeliveryEncoding、EvaluatePath或InitialControl文件。

## 问题模型

站点来自delivery_stations.csv，威胁区来自threat_zones.csv。不是当前RC101实例，也没有动态新增/取消订单。
单无人机出发、各站点恰好访问一次、最后返仓。服务点高度=地形+8，速度6，净空4，安全膨胀2，最高高度42，仓库时间窗[0,240]。
提前到达允许等待；服务开始超过Due或超时返仓不可行。服务点允许悬停调整航向。

每个控制点有三个变量：

```text
base = A + lambda*(B-A)
Cxy  = baseXY + d*side
Cz   = baseZ + h
```

lambda在[0.05,0.95]内并逐航段排序，d/h随控制点一起排序。默认每航段K=2。
目标=三维航程+0.05×等待+2×平滑项。罚项配合显式可行优先，保证最优档案优先保留可行解。
保留地形网格内净空极值、解析圆柱相交、地图边界、最高高度、25°爬升/下降和120°水平转向约束。
必要的竖直/水平航段和相切浮点分支未删，不用粗采样替代。

## 初始化与实验含义

当前引导初始化机制**保持原样**，仅合并为main底部局部函数，包含有限候选枚举及必要的局部PSO修复。
这不等于简单随机初始化，不能把最终可行率解释成“从随机状态找到可行解的能力”。
共同准备开销与完整配送搜索次数分开记录；搜索过程不修复新候选。
`warmStart=false`是独立冷启动协议，四算法仍用相同随机种群。

六场景为10/15/20站点×宽窗45/紧窗12，保存在experiment_cases.mat和experiment_cases/中。
这些窗口围绕固定构造顺序的跨地图时间预先生成，属于人工构造场景，不是原始RC101时间窗。
正常比较只读取固定数据，不自动重新出题。更改main的单图参数不会改变冻结比较场景；需要改比较实例时必须显式重建。

## 数据与输出

三张原始TIF和51×51 MAT全部保留：ridge、peaks、mountain。源数据为Copernicus GLO-90 DSM，包含植被和建筑。
统一去除裁剪最低高程、南北翻转、高度系数0.010615053044490379，XY映射0–100。距离、高度、时间是标准化仿真单位，不是米/秒物理航区。
来源、裁剪窗口、访问日期2026-10-03和哈希见terrain_manifest.json及MAT中的terrainMeta。

results/ridge、peaks、mountain保存单图主结果、路线/编号图、时间窗图、收敛图及配送CSV。
results/terrain保留纯地形图。results/experiments保存历史或新对比批次；历史360次记录没有改写。
质量统计仅使用可行解，无可行解时保留NaN，不能用罚项Cost充当航程。

## 数据重建工具

PrepareTerrain和PrepareExperimentCases不是日常运行文件，已保存到项目外：

```text
C:\Users\111\Documents\Codex\2026-09-29\d-111-desktop-new\compact929_20261003_183543\data_tools
```

需要重建时，将该目录和本项目加入MATLAB路径，再显式传入项目目录：

```matlab
root = 'D:\111\Desktop\噜噜\9.29';
PrepareTerrain(root);                  % 读取原TIF，需Mapping Toolbox
PrepareExperimentCases(cfg,root);      % cfg是main中的参数，重建会覆盖冻结实例
```

普通main直接读取MAT，不需Mapping Toolbox。不要为了日常运行执行数据重建。
完整合并前备份及本轮验证脚本在上述compact929目录，不堆在本工程中。
