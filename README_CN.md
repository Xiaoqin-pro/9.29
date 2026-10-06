# 三维无人机配送优化应用

## 当前候选协议

当前主程序使用 `benchmark-v1`。应用固定为 20 个配送站、每段 3 个中间控制点，并提供五个异质配送场景。五个场景同时改变地形、站点坐标和预约时间窗，适合检验算法在不同综合环境中的稳定性。正式论文实验仍要先用开发 seed 做参数冻结，不能把开发结果当作算法优越性结论。

五张地图分别是 `ridge`、`peaks`、`mountain`、`hills` 和 `plateau`。它们使用不同的地形文件，也使用不同的站点坐标和预约中心，数据位于 `data/map_scenarios_v6/`。站点保持在整个 100×100 区域内分散分布，避免把所有订单挤在地图中心。

## 运行方式

```matlab
cd('D:\111\Desktop\噜噜\9.29');
main
```

`main.m` 开头直接设置实验参数。

- `runComparison=false`：运行一张地图的 PSO 单图演示。
- `runComparison=true`：运行五张地图和当前算法列表的配对比较。
- `developmentMode=true`：使用重复编号 `1:3` 和 30000 次 Fitness 评价做开发筛选。
- `developmentMode=false`：切换到正式重复编号 `101:130` 和 30000 次 Fitness 评价。
- 两种模式都固定使用 60 个粒子和 30000 次 Fitness 评价，只切换 seed；地图、站点和时间窗不变。

多场景比较输出写入 `results/experiments/benchmark_v1_*`，并保存原始运行、汇总、代码和输入快照。诊断材料统一放在 `results/diagnostics/`。

## 场景与模型

每个场景读取一份冻结的 N20 CSV。20 个订单按固定空间参考路线分成 5 个时间带，每带 4 个订单；带内允许多种访问顺序，带间仍保留时间先后约束。预约中心和窗口宽度预先写入 CSV，五个场景使用不同的中心偏移和宽度。窗口宽度约为 140--172 个时间单位，保留明显的等待和迟到约束，不通过算法结果反向修改实例。

每航段使用三个中间控制点，控制变量为 lambda、横向偏移和高度偏移，搜索维度为：

```text
D = N + 3*K*(N+1) = 209
```

当前应用参数为：

```text
speed           = 10
serviceHeight   = 16
minClearance    = 4
maxAltitude     = 42
maxClimbAngle   = 35 deg
maxTurnAngle    = 120 deg
maxSideOffset   = 4
maxHeightOffset = 4
depotWindow     = [0, 360]
```

提高速度是为了让分散航点和时间窗处于可搜索区间，服务高度和控制点偏移范围则保持统一。五张地图的独立参考路线在上述参数下均存在可行解，地图不会因为某个算法暂时找不到解而改变。

目标由三维航程、等待和路线平滑度构成。迟到、返仓超时、碰撞、净空不足、地图越界及角度/高度限制作为约束处理。`Fitness.m` 负责路线解码、排程和路径评价。

## 比较规则

- 同一地图和重复编号下，所有算法读取同一个随机初始种群。
- 所有算法使用相同的粒子数和 Fitness 评价预算；初始化评价计入预算，搜索结束后的复算单独记录。
- 先比较可行率和首次可行评价次数；距离、目标值、等待和平滑度只在可行运行中比较。
- 收敛图明确标记为带罚项的最优 Cost；另外输出 Feasible rate vs Fitness evaluations，不把不可行罚项和可行目标混称为同一个物理量。
- 开发阶段使用 seed `1:3` 检查场景和资源；算法自己的参数只能在开发阶段调整。开发和正式阶段使用相同的粒子数和 Fitness 预算。
- 正式测试使用全新的 seed `101:130`，冻结场景、速度、粒子数、评价次数和算法参数后不再修改。
- 当前主比较只纳入群智能算法：PSO、CSO、CLPSO、GWO 和 SCSO，后续接入提出的新群智能算法。

## 加入新算法

算法沿用统一接口：

```matlab
[Best,T,info] = Method(model,state,maxgen,population,seed)
```

读取 `state.initialPopulation`，调用同一 `Fitness`，遵守 `state.maxEvaluations` 并记录实际评价次数。把方法名加入 `main.m` 开头的 `algorithms` 即可参与同一协议；调参只能使用开发重复编号。

## 文件分工

```text
main.m                         参数、建模、实验循环、结果保存
CreateModel.m                  地形、订单和威胁区
Fitness.m                      解码、排程、约束和目标评价
PlotSolution.m                 路线、时间窗及比较图
PSO.m / CSO.m / CLPSO.m / GWO.m / SCSO.m
data/map_scenarios_v6/         五个场景各自的 N20 站点与时间窗
results/diagnostics/v6_witness.csv       五个场景的独立参考路线检查
```


