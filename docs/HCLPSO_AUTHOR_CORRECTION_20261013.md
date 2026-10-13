# HCLPSO作者源码修正及同格补跑（2026-10-13）

原正式批次完整结束，3480 run成功。不覆盖原始数据。SAQ-CSO、原始CSO和CLPSO保持原版本、原种子、原结果。

## 修正原因

此前HCLPSO依据NEORL移植，仅有运行与计数smoke，未完成搜索行为等价核验。现在取得作者原始MATLAB源码，发现差异：

| 项目 | 本轮Reference | 作者MATLAB profile |
|---|---|---|
| 探索/开发群体 | 20/30 | 固定探索15、其余为开发；N50时15/35 |
| 边界 | clip并评价 | 越界移动不评价，继续运动 |
| 示范强制维度 | 全部最终donor为self时另采样 | 只有全部学习mask为self时，保留该轮原donor并改变一维mask |
| 参数进度 | 零起点，以1999次非初始化轮数归一 | 一起点，以MaxFES/N=2000归一；越界不足FE时重复最后进度 |
| 随机调用顺序 | 逐维/逐粒子循环 | 两组矩阵随机数，与原源码一致 |

这不是依据胜负挑版本：本轮Reference事实上比SAQ-CSO更强。选作者源码是为复现身份清晰。

## 固定来源

P-N-Suganthan/CODES commit `4d7ce681d5121e5af1cffb21c5b79ce9df7de5b1`，`2015-SWEVO-HCLPSO.zip` SHA256 `1e984cb7a3b6496cb5cbceb04ff337bbcbff0f553775f504679b4eb529457acd`。

工作目录保留下载ZIP、未修改原始代码、作者运行脚本、来源JSON和机械oracle。作者原脚本用N40/D30/300k，这是原问题规模，不是CEC2017/D50规定。补跑使用此前已定的共同N50，按作者代码固定g1=15形成15/35；不冒称复现2005原论文表。

## 核验与补跑

- `src/HCLPSO_CEC_AuthorSource.m`：适配接口、种子、共享p0、硬FE和收敛轨迹。
- 搜索公式、边界、刷新、随机顺序保持作者profile。
- 原始末FE break在内部best更新之前；oracle通过独立目标包装记录包含末次评价的真实best，适配器也这样处理。
- `tests/test_HCLPSO_author_adapter.m`：32组独立机械oracle逐点目标输入、Best、全T、最终RNG和迭代数完全一致；含初始化终止、单FE、残余轮、D7/D50、Sphere、CEC F1/F6/F13；9192次越界跳过见证且域外真实调用为0。
- 仅重跑HCLPSO：D50、N50、100k、F1/F3–F30、seed3001–3030，870 run，4 worker、单线程。
- 与原批次共享精确相同initSeed/SearchSeed及p0。
- 原批次其它三算法可核验后缓存使用；旧HCLPSO Reference列单独保留，不能混称作者版。
- CPU运行时来自不同时间段，分别标记。误差与FE比较同格；不把时间小差归因算法。
