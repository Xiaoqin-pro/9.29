# 9.29：三维动态无人机路径规划基础模型

这是在老师胎儿心电项目的简单 MATLAB 风格基础上建立的三维无人机订单路径规划底座。

## 当前问题模型

- 单架无人机、单仓库；
- 从 Solomon RC101 的 100 个客户中固定抽取 20 个二维位置；
- Gaussian 三维地形；
- 8 个圆柱体建筑障碍物；
- 订单高度为当地地形高度加服务高度；
- 单目标订单访问顺序优化；
- 硬时间窗：提前到达可以等待，超过 `due` 的路线不可行；
- 一个动态新增订单事件；
- 当前只使用标准 PSO 作为基础算法。

RC101 只提供订单二维空间位置，三维高度、地形、障碍物、服务时间和动态时间窗由当前 UAV 模型定义。当前问题更接近带时间窗的动态单无人机订单排序与三维航迹评价，不包含容量和电量约束。

## 标准 PSO 的编码方式

PSO 本身是普通连续粒子群算法。每个客户对应一个连续位置值，按照位置值从小到大排序，排序结果就是订单访问顺序：

```text
连续粒子位置
    ↓ 排序
订单访问序列
    ↓
三维航迹与时间窗评价
```

这种表示方法通常称为 random-key encoding，但当前算法名称只称为：

```text
Standard PSO
```

动态事件发生后，重新调用同一个 `PSO.m`，不保留旧种群信息。这只是动态执行策略，不是另一种 PSO 算法。

## 文件结构

```text
main.m                  一键运行入口
PSO.m                   标准 PSO 与排序编码
CreateModel.m           RC101、地形、圆柱障碍、订单和事件
Fitness.m               三维距离、硬时间窗和安全约束评价
Plan3DPath.m            直线、左右绕行和上方绕行
ExecuteUntilEvent.m     沿实际三维航迹执行到事件时刻
DynamicEvent.m          应用动态新增/取消订单
PlotSolution.m          绘制三维地形、障碍物和路线
data/rc101.txt          RC101 二维客户数据
results/                main.m 生成的结果
```

## 运行

```matlab
cd('D:\111\Desktop\噜噜\9.29');
main
```

当前主程序固定使用：

```text
14 个初始订单
6 个预留未来订单
Level 2 时间窗：initial before=30，after=45，future=45
serviceTime = 3
eventTime = 35
事件后重新调用标准 PSO
```

主程序结果：

```text
results/main_result.mat
results/baseline_route_3D.png
results/baseline_replanning_convergence.png
```

当前版本的目标是让老师先检查：问题定义、三维航迹评价、动态执行语义和标准 PSO 底座。后续算法改进不放在这个基础版本中。
