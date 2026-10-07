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
- 初始化使用 `InitSeed=seed`，算法搜索使用 `SearchSeed=seed+100000`，避免初始种群和搜索随机流重复。
- 所有算法使用相同的粒子数和 Fitness 评价预算；初始化评价计入预算，搜索结束后的复算单独记录。
- 先比较可行率和首次可行评价次数；距离、目标值、等待和平滑度只在可行运行中比较。
- 收敛图明确标记为带罚项的最优 Cost；另外输出 Feasible rate vs Fitness evaluations，不把不可行罚项和可行目标混称为同一个物理量。
- 开发阶段使用 seed `1:3` 检查场景和资源；算法自己的参数只能在开发阶段调整。开发和正式阶段使用相同的粒子数和 Fitness 预算。
- 正式测试使用全新的 seed `101:130`，冻结场景、速度、粒子数、评价次数和算法参数后不再修改。
- 当前主比较只纳入群智能算法：PSO、CSO、CLPSO、GWO 和 SCSO，后续接入提出的新群智能算法。

## CEC 开发实验

暂时不使用 UAV 路径图时，可运行 `main_cec.m`。它在六个经典连续函数上，用相同初始种群和相同 FE 预算比较 `PSO_CEC`、`CSO_CEC` 与冻结的 `DSS_MAQLCSO`。其中 MAQL-V1 固定使用 27 状态的模式感知 Q-learning；`modeAwareV2` 只保留在模式信号消融中，不作为正式候选。当前函数用于算法开发验证，尚未替代正式的官方 CEC2017 移位旋转测试包。

正式基准入口为 `main_cec2017.m`。它使用官方 CEC2017 MATLAB 函数包的 30 维数据、`10000*D` 次评价预算和相同初始种群，比较 `PSO`、`CSO` 与 `DSS-MAQLCSO`。官方 MATLAB 包删除了原始 F2，因此入口使用 `F1,F3,...,F30` 共 29 个函数；`data/cec2017/` 保留对应的 C++ 源文件、Windows MEX 文件和 30 维输入数据。开发阶段运行 3 个 seed；将 `developmentMode=false` 后使用正式 seed `101:130`。运行前需要在 MATLAB 中确认 `cec17_func.mexw64` 可用，或按 `data/cec2017/cec17_func.cpp` 的说明重新编译。

消融实验可运行 `main_cec_ablation.m`，比较 `CSO`、`SS-CSO`、`DSS-CSO` 和 `DSS-RLCSO`。后三个版本共用 `DSS_RLCSO.m`，分别关闭或开启第一层猫筛选、第二层候选筛选和 Q-learning；四个版本使用相同初始种群和相同 FE 预算。结果保存到 `results/cec/ablation_时间戳/`。

动作调度对照可运行 `main_cec_action_ablation.m`，比较固定 A4、随机选择 A1--A4 和 Q-learning 三种方式。三者均保留双层筛选，只改变动作选择方式，结果保存到 `results/cec/action_ablation_时间戳/`。

Q-learning 机制的第一阶段对照可运行 `main_cec_rl_ablation.m`，分别比较旧奖励、连续改进奖励、加入多样性状态以及两者同时启用的版本。旧版本使用 9 个状态，加入多样性后使用 18 个状态，结果保存到 `results/cec/rl_ablation_时间戳/`。

参考论文的 CSO 适配对照可运行 `main_cec_paper_ablation.m`。`rlMode='paper'` 保留 9 状态和简单奖励，并将四个动作分别实现为强化开发、同伴学习、高斯扰动和反向跳跃；实验同时比较 Paper-style Q-learning、随机动作、固定 A3 和原始 Legacy-RLCSO，结果保存到 `results/cec/paper_ablation_时间戳/`。

面向 CSO 双模式的状态感知调度可运行 `main_cec_mode_ablation.m`。`rlMode='modeAware'` 使用阶段、停滞和 Seeking/Tracing 最近成功率构成 27 状态，并保留固定、随机和启发式对照；核心记录还包括状态访问和状态--动作访问次数，结果保存到 `results/cec/mode_ablation_时间戳/`。

模式信号对齐实验可运行 `main_cec_mode_signal_ablation.m`，比较 Legacy、MAQL-V1、单位 FE 改善效率版本 MAQL-V2、随机调度和启发式调度。每次运行的 `StateHistory`、`StateVisitCounts`、`StateActionCounts` 和 Q 表保存在结果 MAT 文件中，结果保存到 `results/cec/mode_signal_ablation_时间戳/`。

## 加入新算法

算法沿用统一接口：

```matlab
[Best,T,info] = Method(model,state,maxgen,population,seed)
```

读取 `state.initialPopulation`，调用同一 `Fitness`，遵守 `state.maxEvaluations` 并记录实际评价次数。CEC 开发入口使用 `DSS_MAQLCSO.m` 固定 MAQL-V1；UAV 主程序仍可通过 `DSS_RLCSO.m` 保留旧模式。把方法名加入对应入口的 `algorithms` 即可参与同一协议；调参只能使用开发重复编号。

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


