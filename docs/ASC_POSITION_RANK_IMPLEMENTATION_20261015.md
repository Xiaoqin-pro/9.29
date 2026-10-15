# ASC位置评分改进实现说明

## 入口

`ASC_NoFarness.m`保持用户提供文件原样；本次候选入口为`ASC_NoFarness_PositionRank.m`。输入与原文件一致：`[Best,T,info]=ASC_NoFarness_PositionRank(f,state,[],N,seed)`。

默认唯一生效的搜索改动：`geometryScreen`在选择各粒子下一位置时用`min(rankNear,rankFar)`代替排名和。`state.positionRankRule='sum'`可以恢复原默认位置评分。实际真实评价集合仍按近gbest/远中心分两阶段挑选，未加固定Tracing配额、未加pbest回退、未加半径恢复。

当gbest等于中心且候选距离互异时，排名和为M+1；min可避免全部分数相同，但两个方向的对称秩仍可能并列，因此不能声称完全消除所有并列或保证优化精度更好。默认改动要由全29函数结果判断。

## 分组路径修复

`generateGroupCandidates`的返回值增加vel，主循环接收vel。该修复只在useGroup=true时生效；本次正式比较useGroup=false，未偷偷启用分组、OBL或gaussBest。

## 诊断

新增info.TracingEvaluations、SeekingEvaluations、MaxOwnerEvaluations；RoundLog原15列顺序不动，追加真实Tracing/Seeking次数、实评父代数、下一位置不是该父代本轮实评候选的次数。该位置错配计数在Jump前统计，不包含Jump后的再次移动。这些诊断不抽随机数，不消费目标评价。

原ASC缺少实际模式实评计数，不用候选生成数量冒充实评数量；其统计列保留缺失值。新入口sum模式与原文件逐评价等价，已含完整100k回归测试。

## 验证与证据

11项检查通过，包括手算排名抵消fixture（真实评价集合相同、下一位置不同）、尾预算、边界、可重复性、sum原版逐点等价、默认跳出、分组路径及F1/F6/F13/F27的CEC预检。性能实验仅使用either默认候选，预先固定对照范围和参数。

正式8算法范围与复用核验见ASC_POSITION_RANK_COMPARISON_PROTOCOL_20261015.md。部分算法对同一初始50点池取前40或前30个点，保持已审计默认设置；所有算法真实优化调用均100k。

## 实验回填

1740次新运行及5220条缓存核验已完成。min版相对原ASC10胜19负，29项Holm无显著函数；暂不替换原默认版本。完整8算法报告见results/asc_comparison_30seed_20261015/REPORT.md。原ASC相对冻结SAQ16胜13负，但仍有F1等明显缺口，不能称已全面优于SAQ或强PSO。
