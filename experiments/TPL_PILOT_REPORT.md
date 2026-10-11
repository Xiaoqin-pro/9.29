# TPL-CSO pilot report

本报告记录第一轮可信候选账本机制预检。它是机制筛查，不是正式 CEC 结论。

## 协议

- 8 个函数：F3、F6、F9、F12、F13、F22、F28、F30
- 5 个配对 seed：201–205；D=30；N=50；60,000 FE；B10 的 4 Tracing + 6 Seeking
- 版本：B10-Reference、TPL-Fixed、TPL-Random、TPL-Q
- 所有运行均通过 FE、有限值和收敛单调性检查。

## 函数均值

| Function | B10-Reference | TPL-Fixed | TPL-Q | TPL-Random |
|---|---|---|---|---|
| F03 | 9102.49 | 13019 | 12041.6 | 12863.6 |
| F06 | 2.73157 | 0.873242 | 0.958488 | 1.0187 |
| F09 | 37.56 | 1.56429 | 2.33202 | 4.15885 |
| F12 | 1.07515e+06 | 1.05139e+06 | 901793 | 1.28732e+06 |
| F13 | 28106.5 | 78096.9 | 299741 | 71116.3 |
| F22 | 589.346 | 100.904 | 100.433 | 100.617 |
| F28 | 421.419 | 415.753 | 414.146 | 413.844 |
| F30 | 98701.5 | 104740 | 595973 | 619749 |

## 函数均值最佳版本

| Method | Functions |
|---|---|
| B10-Reference | 3 |
| TPL-Fixed | 2 |
| TPL-Q | 2 |
| TPL-Random | 1 |

## 逐 seed 配对胜负

- `B10-Reference` vs `TPL-Fixed`：21:19，平局 0
- `B10-Reference` vs `TPL-Q`：20:20，平局 0
- `B10-Reference` vs `TPL-Random`：20:20，平局 0
- `TPL-Fixed` vs `TPL-Q`：22:18，平局 0
- `TPL-Fixed` vs `TPL-Random`：23:17，平局 0
- `TPL-Q` vs `TPL-Random`：21:19，平局 0

## 平均时间与机制统计

| Method | Runs | MeanError | MedianError | MeanSeconds | MeanParentCoverage | MeanConcentration | MeanSeekSuccesses | MeanProposalGenerated | MeanProposalEvaluated |
|---|---|---|---|---|---|---|---|---|---|
| B10-Reference | 40 | 151514 | 3919.63 | 4.33287 |  |  |  |  |  |
| TPL-Fixed | 40 | 155971 | 4267.3 | 3.74926 | 5.62169 | 0.187684 | 2987.88 | 315727 | 35970 |
| TPL-Q | 40 | 226258 | 3897.39 | 3.84687 | 5.62623 | 0.187431 | 2886.4 | 315618 | 35970 |
| TPL-Random | 40 | 248946 | 3575.52 | 2.62979 | 5.63507 | 0.186941 | 2980.25 | 315564 | 35970 |

## Q 修正后预检

| Function | TPL-Q-corrected mean |
|---|---|
| F03 | 14401.7 |
| F06 | 0.526337 |
| F09 | 1.56556 |
| F12 | 1.59221e+06 |
| F13 | 269248 |
| F22 | 1210.44 |
| F28 | 422.871 |
| F30 | 260236 |

| mean |
|---|
| 5995 |
| 315798 |
| 35970 |
| 135554 |
| 5.62826 |
| 0.187319 |
| 2879.95 |

修正后的 Q 只使用 Seeking 窗口的改善作为奖励，避免 Tracing 改善污染 Q 反馈。它仍未显示出相对 TPL-Fixed 的稳定收益，因此本阶段停止继续调 Q 参数。

## 决策

1. TPL-Fixed 保留为候选机制，但当前证据不足以替代 B10。
2. TPL-Q 本轮不进入主算法，不再继续扫描 alpha、gamma、epsilon。
3. 下一轮如果继续，只做一个简化的“提案过期 + 边际覆盖”消融，先确认固定账本是否能稳定超过随机和 B10；不新增搜索公式。