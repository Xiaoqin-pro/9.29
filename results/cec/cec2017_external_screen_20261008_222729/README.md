# CEC2017 外部竞争力预检

本目录记录 `CSO`、`CLPSO`、`DSS-Range` 和 `Global-Cap2-Range` 在 CEC2017 上的同预算开发预检。

## 实验协议

- 函数：F1、F3–F30（跳过官方 F2，共 29 个）
- 维度：D=30
- 种群：50
- 预算：300000 FE（10000D）
- 重复：16–20，共 5 个统一 seed
- 初始种群：四种算法在同一函数、同一 seed 下完全相同
- DSS / Global-Cap2：纯 Range Seeking，MR=0.4，无 Recovery，每轮 5 FE（Tracing=2、Seeking=3）
- 并行：4 workers
- L-SHADE、CMA-ES 和 Q-learning 不在本轮比较中

CSO 和 CLPSO 使用仓库中的标准 CEC 接口；DSS-Range 和 Global-Cap2-Range 使用当前固定的筛选实现。四种算法都严格完成 300000 次真实 Fitness 评价。

## 最终误差结果

最终误差越小越好。29 个函数的均值排名如下：

| 算法 | 平均排名 | 函数均值第一名 | 相对原始 CSO 的函数均值胜负 |
|---|---:|---:|---:|
| CLPSO | 1.379 | 22/29 | 29/29 |
| Global-Cap2-Range | 2.069 | 6/29 | 29/29 |
| DSS-Range | 2.552 | 1/29 | 29/29 |
| CSO | 4.000 | 0/29 | — |

相同 seed 的逐次配对结果：

| 比较 | 获胜 | 失败 | 平局 |
|---|---:|---:|---:|
| DSS-Range vs CSO | 138 | 7 | 0 |
| Global-Cap2-Range vs CSO | 135 | 10 | 0 |
| DSS-Range vs CLPSO | 30 | 115 | 0 |
| Global-Cap2-Range vs CLPSO | 40 | 105 | 0 |
| Global-Cap2-Range vs DSS-Range | 87 | 58 | 0 |

按函数均值，CLPSO 在 25 个函数上优于 DSS-Range，在 22 个函数上优于 Global-Cap2-Range。Global-Cap2-Range 在 20 个函数上优于 DSS-Range，DSS-Range 在 9 个函数上优于 Global-Cap2-Range。

## 收敛与时间

30%、60% 和 100% FE 的平均排名分别为：

| FE 节点 | 第一名 | 第二名 | 第三名 | 第四名 |
|---|---|---|---|---|
| 30% | Global-Cap2-Range | CLPSO | DSS-Range | CSO |
| 60% | CLPSO | Global-Cap2-Range | DSS-Range | CSO |
| 100% | CLPSO | Global-Cap2-Range | DSS-Range | CSO |

平均运行时间：

| 算法 | 平均秒数 |
|---|---:|
| CSO | 3.69 |
| CLPSO | 4.21 |
| Global-Cap2-Range | 40.64 |
| DSS-Range | 42.21 |

筛选方法在便宜的 CEC Fitness 上增加了明显的 MATLAB 内部筛选开销。因此当前结果支持的是“固定 FE 下提高搜索质量”，不能声称整体运行更快。对于后续 UAV 等昂贵 Fitness 场景，需要单独报告筛选开销与 Fitness 调用耗时的比例。

## 当前研发结论

1. `CLPSO` 是本轮最强外部基线，不能把 DSS 或 Global-Cap2 宣称为完整 CEC2017 上的总体最优算法。
2. `DSS-Range` 和 `Global-Cap2-Range` 都稳定改善了原始 CSO，说明评价机会筛选机制确实具有价值。
3. Global-Cap2 在早期 30% FE 的平均排名最好，但在 60% 和 100% FE 时 CLPSO 领先；这说明它的优势更偏向前期搜索，而不是最终精度的全面优势。
4. 当前没有证据支持继续加入 Q-learning、混合 DSS/Global 或新的 Seeking 公式。下一步应冻结这两个筛选候选，完善统计分析，并在正式实验中与 CLPSO 同场比较。
5. 本轮是 5 个开发 seed 的竞争力预检，不是正式 30 次统计实验。正式实验继续使用预留的 101–130 seed，并在主算法确定后再执行。

## 文件

- `raw_runs.csv`：580 次逐运行结果
- `raw_runs_checkpoint.csv`：完整 checkpoint
- `summary.csv`：逐函数均值、标准差和时间
- `mean_error_by_function.csv`：四种算法逐函数均值及最佳算法
- `convergence.csv`：每 3000 FE 的收敛记录
- `source_hashes.csv`：关键源码和 CEC MEX 文件的 SHA-256
- `main_cec_external_screen_parallel.m`：4 worker 外部预检脚本
- `resume.log`：续跑日志

本次没有上传 MAT 历史文件；正式入口 `DSS_RLCSO_CEC.m` 仍未切换到 Global-Cap2。
