# 9.29：三维无人机时间窗路径规划结构化混合 PSO

这是在老师胎儿心电项目的简单 MATLAB 风格基础上建立的静态三维无人机订单路径规划版本。

## 当前问题模型

- 单架无人机、单仓库；
- 从 Solomon RC101 的 100 个客户中固定抽取 20 个二维位置；
- 订单位置和原始时间窗来自 RC101；
- Gaussian 三维地形；
- 8 个圆柱体建筑障碍物；
- 订单高度为当地地形高度加服务高度；
- 硬时间窗：提前到达可以等待，超过 `due` 的路线不可行；
- 最大爬升/下降角、最大水平转向角和轨迹平滑度约束；
- 当前只研究静态订单，不包含动态新增订单、订单取消和事件后重规划。

当前问题更接近单无人机 TSPTW 加三维航迹优化，不包含容量和电量约束。

## 订单和控制点编码

订单部分直接保存排列：

```text
[订单3 订单1 订单5 订单2]
```

每次迭代使用三种 insertion 更新：

```text
pRandom：随机 insertion
pPbest：向个体最优路线学习
pGbest：向全局最优路线学习
```

控制点部分采用局部 `lambda/d/h` 参数。对当前航段 A -> B，每个控制点由三个连续变量表示：

```text
lambda：沿 A -> B 的纵向位置比例
d：相对航段的水平侧向偏移
h：相对基准线的高度偏移
```

解码公式为：

```text
base = A + lambda*(B-A)
controlXY = baseXY + d*side
controlZ  = baseZ + h
```

因此控制点不再固定在 1/3、2/3 位置。当前 K=2 时，每条航段的两个控制点都可以沿航段前后移动，同时左右和上下调整。

为了避免控制点沿航段前后交叉，`lambda` 被限制在：

```text
0.05 <= lambda <= 0.95
```

并在每条航段内按 `lambda` 从小到大排序。`d` 和 `h` 会和对应控制点一起排序。

## PSO 结构

订单部分使用 insertion 离散更新，控制点 `lambda/d/h` 使用连续 PSO 更新。

初始化保持简单：

```text
Route：随机排列
lambda：以等比例位置为中心加入小随机扰动
d/h：小随机值
```

不使用旧的 `InitialControlPoints.m`，不注入 reference 粒子，也不使用 reference 生成时间窗。

最近邻路线只作为参考对照，参考控制点使用等比例 `lambda` 和 `d=h=0`，对应各订单间的直接折线基准。

## 文件结构

```text
main.m                  主程序和参数
PSO.m                   insertion + 连续 lambda/d/h PSO
CreateModel.m           RC101、地形、障碍物和时间窗
Fitness.m               控制点解码、三维距离、时间窗和安全约束评价
PlotSolution.m          路线和全部订单参考图
data/rc101.txt          RC101 客户数据
results/                main.m 生成的结果
```

## 当前固定参数

```text
twScale = 1.0
20 个静态订单
serviceTime = 3
nControlPoints = 2
minControlRatio = 0.05
maxControlRatio = 0.95
maxSideOffset = 30
maxHeightOffset = 25
maxClimbAngle = 25°
maxTurnAngle = 120°
smoothWeight = 2
```

当前阶段先校准时间窗难度，再在固定实例上比较可行率、距离、平滑度、收敛速度和稳定性。暂不继续加入 Levy、混沌、突变或动态订单机制。
