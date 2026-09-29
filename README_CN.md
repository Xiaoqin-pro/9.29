# 9.29：三维动态无人机路径规划基础模型

本仓库使用老师胎儿心电项目中的简单 MATLAB 风格，建立三维动态无人机订单路径规划底座。

## 当前研究内容

1. RC101 订单二维位置；
2. Gaussian 三维地形；
3. 订单局部地形高度；
4. 圆柱体建筑障碍物；
5. 直线、左右绕行和上方绕行航迹；
6. 时间窗和订单服务时间；
7. 动态新增订单；
8. Random-key PSO 基础算法。

当前版本只保留一个优化算法：

```text
PSO：优化订单访问顺序
Fitness：评价整条路线
Plan3DPath：生成相邻节点之间的三维航迹
ExecuteUntilEvent：执行路线到动态事件
DynamicEvent：应用新增或取消订单
```

后续在统一的问题模型和评价函数基础上研究动态优化算法。

## 代码结构

```text
main.m                  动态三维 PSO baseline
PSO.m                   Random-key PSO
CreateModel.m           RC101、地形、障碍物、订单和事件
Fitness.m               距离、时间窗和安全约束评价
Plan3DPath.m            三维候选航迹规划
ExecuteUntilEvent.m     执行旧路线到事件时刻
DynamicEvent.m          应用动态订单事件
PlotSolution.m          绘制三维场景和路线
test_path.m             五类独立航段测试
RunStaticBaseline.m     静态时间窗难度校准
data/rc101.txt          RC101 订单二维数据
results/                运行结果
```

## 运行

```matlab
cd('D:\111\Desktop\噜噜\9.29');
test_path
RunStaticBaseline
main
```

`main.m` 当前运行：

```text
14 个初始订单
+ 6 个未来订单
+ Level 2 时间窗
+ serviceTime = 3
+ 第一个新增订单事件
+ 事件后 Restart-PSO
```

主程序输出：

```text
results/main_result.mat
results/baseline_route_3D.png
results/baseline_replanning_convergence.png
```

当前基础算法只做随机初始化和标准 PSO 更新。后续算法改进将在这个干净 baseline 上单独增加。
