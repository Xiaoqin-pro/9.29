# DSS-RLCSO V3 与 V3.1 公平机会评分对比

开发实验：F3、F5、F13、F15、F19、F30；D=30，50 个体，300000 FE，seed 1:3，4 个并行 worker。

## 唯一改动

- V3：Seeking 猫的第一层机会评分使用候选距离的 `min/max`，Tracing 猫只有一个 trial。
- V3.1：第一层对每只猫的候选集合使用平均空间潜力；第二层 Seeking 候选仍使用 near-best + far-center。奖励、α、γ、ρ、SMP 和四个动作均未改。

同时记录 `WasExploration`、`GreedyActionHistory` 和 `EpsilonHistory`。

## 结果

| 函数 | V3 平均误差 | V3.1 平均误差 | V3.1 相对变化 |
| --- | ---: | ---: | ---: |
| F3 | 1.595 | 1.197 | -24.9% |
| F5 | 213.75 | 166.64 | -22.0% |
| F13 | 69933.68 | 144282.04 | +106.3% |
| F15 | 32752.02 | 81714.77 | +149.5% |
| F19 | 395385.92 | 227283.44 | -42.5% |
| F30 | 1445264.80 | 1103319.65 | -23.7% |

V3.1 按函数均值赢 4/6（F3、F5、F19、F30），输 2/6（F13、F15）。它改善了 F19，但丢失了 V3 在 F13/F15 上的收益，因此暂时不能替换 V3。

## 资源分配诊断

V3 Tracing FE 约 9.0%；V3.1 升至约 61.9%。V3.1 的 `SelectedTracingCatShare` 是“入选猫中 Tracing 的条件比例”，不能直接与生成比例相除解释资源份额；`diagnostics.csv` 另给出按每轮约 3 个入选猫与 50 个生成猫折算的 `SelectedPerGeneratedCat`。

V3.1 的 Q-learning 贪心 A4 比例约 98%–99%，整体 A4 仍约 77%–79%；探索率约 0.27。说明平均机会评分修正了模式资源偏置，但没有解决动作集合中 A4 的主导问题。

## 文件

- `raw_runs.csv`：36 次原始记录。
- `summary.csv`：按函数和版本的均值、标准差、诊断汇总。
- `comparison.csv`：V3/V3.1 配对比较。
- `diagnostics.csv`：生成/入选 Tracing、实际 FE 比例和无 Tracing 轮次。
- `histories/`：本地保留完整 Best/T/info 历史，未上传。

当前结论是：机会评分确实是独立机制问题，但简单平均会过度偏向 Tracing；下一步应在模式公平评分和 A4 recovery 拆分之间做更明确的结构设计，不直接进入正式 30 次实验。
