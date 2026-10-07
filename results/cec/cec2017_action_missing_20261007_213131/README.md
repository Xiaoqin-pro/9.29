# Fixed A2 / A4 补跑

9 个函数 × 3 个开发 seed × 2 个配置，共 54 次。D=30，种群50，300000 FE，4 个进程 worker，搜索显式 `rng(seed,'twister')`，修复 fixed2/fixed4 分支后的版本为 `45a90e6`。

54 个历史文件全部检查通过：实际 FE 与历史长度一致，历史有限且单调，初始矩阵一致，动作选择分别全部为 A2/A4。CSV 中 best error 是 BestCost 减去 100×FunctionID，并下截到0。

同随机流的 Q-learning 参照复用 `cec2017_v3_20261007_190313` 的旧 V3 记录，完整汇总见 `../cec2017_action_summary_20261007/`。此前 worker 默认 threefry 的 Random/A1/A3 不作为本组配对参照。MAT 与逐次完整历史保留在本地。
