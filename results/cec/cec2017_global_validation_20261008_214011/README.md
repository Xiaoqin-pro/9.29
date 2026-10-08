# CEC2017 Global-Cap2 扩展验证

本目录记录 `DSS-Range` 与 `Global-Cap2-Range` 在此前未纳入 Global 筛选对照的 23 个 CEC2017 函数上的扩展验证。

## 实验协议

- 函数：F1、F4、F6–F12、F14、F16–F18、F20–F29（共 23 个）
- 维度：D=30
- 种群：50
- 预算：300000 FE（10000D）
- 重复：13–15，共 3 个配对 seed
- Seeking：纯 Range
- MR：0.4，固定模式预算
- Recovery：关闭
- 真实评价：每轮 5 次，其中 Tracing=2、Seeking=3
- 并行：4 workers

两种方法使用相同的初始种群、初始化 seed 和搜索 seed。`DSS-Range` 使用原有猫级筛选后再做候选筛选；`Global-Cap2-Range` 在全部 Seeking 候选中进行 near-best/far-center 竞争，同时限制每个父代最多获得 2 次 Seeking 评价。

## 结果摘要

最终误差越小越好。按 23 个函数的均值比较：

| 比较 | Global-Cap2 更好 | DSS 更好 |
|---|---:|---:|
| 函数均值 | 10 | 13 |
| 逐 seed 配对（69 次） | 33 | 36 |

平均排名：`DSS-Range=1.435`，`Global-Cap2-Range=1.565`。逐 seed 符号检验中 Global-Cap2 的 33/69 胜负差异不显著（双侧 p=0.810）。因此，这一扩展集没有支持 Global-Cap2 稳定优于 DSS。

Global-Cap2 在 F1、F10、F11、F16、F18、F24、F25、F27、F28 等函数上均值更好；DSS 在 F6、F7、F8、F9、F12、F14、F17、F20、F21、F22、F23、F26、F29 上均值更好。F9、F12、F22 是 Global-Cap2 退化较明显的函数，F24、F27、F28 是其较明显的优势函数。

## 机制诊断

| 指标 | DSS-Range | Global-Cap2-Range |
|---|---:|---:|
| 平均 Seeking 父代覆盖数 | 2.000 | 2.023 |
| 平均集中度 | 0.556 | 0.550 |
| 平均 Seeking 全局改善次数/运行 | 262.48 | 282.35 |
| 平均运行时间（秒） | 43.50 | 41.06 |

两者的父代覆盖和集中度非常接近，Global-Cap2 的差异不是由明显的父代集中造成的。Global-Cap2 平均全局改善次数略高，但没有转化为 23 个函数上的稳定最终误差优势。

## 当前研发结论

这批扩展验证不支持把 Global-Cap2 直接替换为正式主算法。当前更稳妥的做法是：

1. 保留 `DSS-Range` 作为稳定参考版本；
2. 保留 `Global-Cap2-Range` 作为有潜力的全局筛选对照；
3. 不再继续增加筛选器、Q-learning 或新的 Seeking 公式；
4. 下一步进入固定版本与外部群智能基线的比较，使用新的正式 seed，报告逐函数误差、平均排名、收敛和时间。

此前 6 个开发函数的 Global-Cap2 优势与本次 23 个函数结果合并后，函数均值为 15 胜 14 负，说明它仍值得在论文中作为强对照报告，但不能宣称在完整 CEC2017 上稳定优于 DSS。

## 文件

- `raw_runs.csv`：138 次运行的逐运行结果
- `summary.csv`：逐函数汇总
- `convergence.csv`：每 3000 FE 的收敛记录
- `raw_runs_checkpoint.csv`：运行过程中的最后一次 checkpoint
- `DSS_RLCSO_snapshot.m`：本次实验使用的算法快照
- `histories/`：本地 MAT 历史文件，未纳入 Git 提交
