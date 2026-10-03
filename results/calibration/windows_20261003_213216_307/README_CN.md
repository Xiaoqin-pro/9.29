# 时间窗校准：非正式算法成绩

仅peaks/N20、PSO、30粒子、3000次完整Fitness、宽度24/30/36/45/60，各5个配对seed20281304至20281308。
只把due改成ready+width；共享种群、ready、返仓due240、地图、地形、圆柱、角度及罚函数均不变。没有引导初值或修复。

五档均0/5，且全部保存最优解同时违反时间或返仓和几何约束。mean feasible distance保持NaN；不能据此冻结tight30/wide60，也不能将失败解的航程当成可行航程。

- W*/seed_*.mat：逐次Best/T/model/state/info与原始指标。
- raw_runs.csv、summary.csv、calibration_results.mat：逐次/汇总记录。
- source/和input/：搜索当时的源码和输入快照。
- figure_source/：分开显示不同单位违反量的最终绘图代码。
- window_calibration.png：三种可行率与各类违反量，未将不同单位相加。
- independent_check.py及independent_checks.json：独立解码、距离、时刻、爬升转向、解析圆柱相交复查；地形另做0.05步长采样检查。
- two_dimensional_diagnostic.py及JSON：忽略地形/障碍/角度后的精确二维排列枚举，仅说明旧窄窗口的排列限制。
- archived_witness_check.csv：只评价历史保存候选，五档窗口均可行；它未被注入本批搜索，证明0/25不是实例无解。

可用Python运行本目录两个检查脚本。独立检查需要numpy/scipy，二维枚举只用标准库。主程序仍是八个MATLAB文件。
