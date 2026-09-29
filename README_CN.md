# 9.29：三维动态无人机路径规划重建版

这是在老师给出的简单 PSO 代码风格基础上重新整理的版本。

## 研究路线

1. **单目标二维底座**：客户访问顺序由 Random-key PSO 优化，时间窗通过评价函数处理。
2. **三维无人机验证**：使用 RC101 的标准订单平面位置，加入 Gaussian 地形、局部订单高度、圆柱体建筑、飞行距离和安全高度约束。
3. **动态订单**：加入新增订单和取消订单，在事件发生后重新规划。
4. **算法论文主线**：对比 Restart-PSO、Warm-start PSO 和 EAT-PSO；EAT-PSO 用历史路线、事件新增订单插入路线和随机个体重构种群。

## 代码风格

代码保持老师示例的扁平结构：

```text
main.m          主程序
PSO.m           基础粒子群
Warm_PSO.m      基于旧路线的 Warm-start PSO
EAT_PSO.m       事件感知种群重构 PSO
CreateModel.m   生成 RC101 订单、Gaussian 地形、障碍物和事件
test_path.m     独立测试五类三维航段
Fitness.m       统一评价函数
DynamicEvent.m  应用新增/取消订单
ExecuteUntilEvent.m  执行旧路线到事件时刻
Plan3DPath.m   生成直线、左右绕行和上方绕行候选航迹
PlotSolution.m  绘制三维路线
```

不使用复杂的多层工程结构，先保证模型、评价函数、PSO和实验结果都能直接读懂、直接运行。

## 运行

```matlab
cd('D:\111\Desktop\噜噜\9.29');
test_path
main
```

结果写入 `results` 文件夹：

- `main_result.mat`
- `EAT_PSO_route_3D.png`
- `replanning_convergence.png`

## 当前算法含义

- **Restart-PSO**：事件后完全随机初始化。
- **Warm-start PSO**：事件前路线作为部分初始粒子。
- **EAT-PSO**：事件后使用三类信息重构种群：历史路线、对新增订单的插入路线、随机移民。

当前版本先固定底层三维模型和路径评价。CreateModel 默认支持 20 个静态 RC101 订单；main.m 为了演示动态订单，使用 8 个初始订单和 4 个未来订单。下一步先验证静态基线，再恢复正式动态实验，不把所有机制一次性堆进代码。
