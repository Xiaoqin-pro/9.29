# 9.29：三维无人机时间窗路径规划基础模型

这是在老师胎儿心电项目的简单 MATLAB 风格基础上建立的静态三维无人机订单路径规划底座。

## 当前问题模型

- 单架无人机、单仓库；
- 从 Solomon RC101 的 100 个客户中固定抽取 20 个二维位置；
- Gaussian 三维地形；
- 8 个圆柱体建筑障碍物；
- 订单高度为当地地形高度加服务高度；
- 单目标订单访问顺序优化；
- 硬时间窗：提前到达可以等待，超过 `due` 的路线不可行；
- 直接排列粒子、插入式离散 PSO 和连续控制点更新；
- 最大爬升/下降角、最大水平转向角和轨迹平滑度约束。

当前版本只研究静态三维时间窗路径规划，不包含动态新增订单、订单取消或事件后重规划。动态订单机制暂时不进入本项目。

订单位置和原始时间窗来自 RC101；三维高度、地形、障碍物和服务时间由当前 UAV 模型定义。当前问题更接近单无人机 TSPTW 加三维航迹评价，不包含容量和电量约束。

## 插入式离散 PSO

粒子本身直接保存订单排列：

```text
[订单3 订单1 订单5 订单2]
```

每次迭代使用三种带随机概率的插入更新：

```text
pRandom：随机 insertion，保持探索
pPbest：向个体最优 pbest 学习
pGbest：向全局最优 gbest 学习
```

PSO 仍然保留粒子、个体最优、全局最优和迭代更新结构。订单部分的 pbest/gbest 学习采用前驱邻接 insertion，而不是简单复制优秀路线中的绝对位置。

## 文件结构

```text
main.m                  静态三维时间窗主程序
PSO.m                   插入式离散 PSO
CreateModel.m           RC101、地形、圆柱障碍、订单和时间窗
Fitness.m               控制点折线、三维距离、硬时间窗和安全约束评价
PlotSolution.m          路线快照与全部订单空间参考总览
data/rc101.txt          RC101 二维客户数据
results/                main.m 生成的结果
```

## 运行

```matlab
cd('D:\111\Desktop\噜噜\9.29');
main
```

主程序固定使用：

```text
twScale = 1.0（RC101 原始时间窗）
20 个静态订单
serviceTime = 3
nControlPoints = 2
maxSideOffset = 30
maxHeightOffset = 25
maxClimbAngle = 25°
maxTurnAngle = 120°
smoothWeight = 2
```

输出结果：

```text
results/main_result.mat
results/baseline_route_3D.png
results/all_orders_route_3D.png
results/baseline_convergence.png
```

`baseline_route_3D.png` 是 PSO 得到的静态控制点规划路线；`all_orders_route_3D.png` 是全部20个静态订单的最近邻参考路线总览，不是 PSO 结果，也不是实际执行历史。

当前版本的控制点粒子使用 K=2 个控制点。每个粒子包含订单排列和所有航段的 d/h 控制量；其中 d 是相对当前航段的水平侧向偏移，h 是高度偏移，Fitness 再根据当前航段方向解码为 XYZ 控制点。所有粒子都随机初始化，最近邻路线只作为参考对照。Fitness 直接评价控制点折线，解码函数作为 Fitness.m 的局部函数。当前版本的目标是先让老师检查：静态问题定义、控制点折线评价、硬时间窗、控制约束和混合离散-连续 PSO 底座。动态订单和事件重规划后续另行研究。
