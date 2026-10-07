# 原始并行动作消融：保留作研发记录

本目录的 162 次运行均结束，但不能当作完整六动作实验。

- Fixed-A2、Fixed-A4 共 54 次因未识别动作分支，实际执行 A1；原始标签未改，不能用于 A2/A4 性能结论。
- Q-learning、Random、Fixed-A1、Fixed-A3 共 108 次动作标签有效，搜索使用 worker 默认 threefry。
- 本目录不能直接与显式 twister 的补跑结果做同 seed 配对比较。

动作审计及分随机流汇总见 `../cec2017_action_summary_20261007/`。真正的 A2/A4 补跑见 `../cec2017_action_missing_20261007_213131/`。原始 CSV 保留，避免删除错误实验历史。
