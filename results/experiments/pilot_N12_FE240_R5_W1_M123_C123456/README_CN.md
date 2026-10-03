# 历史实验说明（整理前版本）

本目录保留整理前的360次小预算原始结果。下面的原始说明描述当时版本，所列旧文件名、缓存和续跑接口不代表当前代码；当前运行方式以项目根目录README_CN.md为准。
本次没有重新执行这360次实验，也没有改动其MAT、CSV、图和JSON证据。

---

# 猫群CSO、PSO、CLPSO、GWO：三维配送对比实验

## 直接运行

MATLAB进入项目根目录，运行：
```matlab
RunExperiments
```
默认：3张地图×6组场景×4算法×5次独立运行，共360次；种群12，每次240次完整配送Fitness评价，含初始种群评价。结果目录：
`results/experiments/pilot_N12_FE240_R5_W1_M123_C123456`。

已经实际完成上述360次小预算试验，并经MATLAB逐解复算和Python独立核对。该批次用于实现、接口与搜索效果验证；5次重复、240次评价尚不足以作为论文最终性能结论。

正式实验参数已支持，以下命令会执行2160次运行：
```matlab
RunExperiments(struct('Profile','formal','Runs',30,'Population',20,'Evaluations',2020))
```
正式30次/2020评价版本本次没有执行。运行中断后用相同参数再次调用会续跑；代码、场景或参数改变时，不会复用不匹配的旧记录。
单场景检查：
```matlab
RunExperiments(struct('Profile','check','Runs',1,'MapIDs',2,'CaseIDs',6))
```
仅需统计、不导图，可另设`'Figures',false`。原main.m仍是单地图20点演示，默认多峰图；四算法批量对比入口是RunExperiments。

## 代码风格与文件

参照teacher胎儿心电代码：入口集中设置参数，for循环遍历重复与算法；每个算法独立函数，pop/V/pbest/gbest等用数值数组更新，评价函数独立。没有类、注册器或外部优化工具箱。teacher目录没有修改。

| 文件 | 用途 |
|---|---|
| RunExperiments.m | 参数、四层实验循环、逐次保存、续跑 |
| PSO.m / CSO.m / CLPSO.m / GWO.m | 四种算法各自更新公式 |
| DeliveryEncoding.m | 共同配送顺序排序键与三维控制点编码 |
| MakePopulation.m / SwarmStart.m | 相同初始种群与评价计数 |
| PrepareExperimentCases.m | 固定订单子集、时间窗、三图可行参考路线 |
| SummarizeExperiments.m | 汇总表、平均收敛、箱线图、代表路线 |
| ExperimentHash.m | 输入和代码指纹 |
| VerifyAlgorithms.m / VerifyDelivery.m | 算法预算/复现/模式、手算和安全边界验证 |

## 六组固定场景

| CaseIDs | 名称 | 站点数 | 时间窗宽度 |
|---:|---|---:|---:|
| 1 | N10_wide | 10 | 45 |
| 2 | N10_tight | 10 | 12 |
| 3 | N15_wide | 15 | 45 |
| 4 | N15_tight | 15 | 12 |
| 5 | N20_wide | 20 | 45 |
| 6 | N20_tight | 20 | 12 |

10点子集：S1、S3、S5、S7、S9、S11、S13、S15、S17、S20。
15点子集：S1、S2、S3、S5、S6、S7、S8、S9、S10、S11、S13、S14、S16、S18、S20。
20点使用全部内部站点。子集覆盖地图不同区域；CSV中的客户ID不因子集而重新编号。模型内部索引仅用于计算，导出的配送时间表保留S编号。

原data/delivery_stations.csv未改成实验时间窗；六组独立数据在data/experiment_cases/N*_*.csv，缓存与参考路线在data/experiment_cases.mat。
这六份CSV是固定场景的导出记录，运行入口读取MAT缓存。修改场景时应编辑PrepareExperimentCases.m中的子集或窗口宽度，再调用PrepareExperimentCases(true)；修改原站点CSV也会使缓存自动重建。CSV导出记录不用于直接覆盖缓存。
各组先按固定客户顺序构造安全参考航迹，用各航段跨三图的最长飞行时间累积得到保守到达时间，Ready=max(0,floor(保守到达)-3)，Due=Ready+45或12。服务时长3。时间窗在算法比较前固定，三图共用，生成过程不读取任何算法的比较成绩。每组通过参考路线可行性检查，避免随机生成无解时间窗。
这属于人工设计的静态仿真订单，不是RC101原始时间窗，也不是实测业务订单。

## 共同模型与公平条件

三张原DEM、parula配色、内部站点与6个有限圆柱体保持。速度6、净空4、服务高度8、爬升/下降角25°、航段内水平转向120°、最高高度42、仓库截止240。
各算法都优化配送顺序和每航段2个三维lambda/d/h控制点；同一重复使用逐元素相同的初始种群、种群数量、评价函数、实际评价预算和种子。宽/紧窗配对还使用相同初始化种子。

猫群搜索包含Seeking和Tracing，SMP=5、SRD=0.05、CDC=0.20、MR=0.20、SPC=true、追踪系数2；Seeking候选逐一计数，当前位置缓存不重复评价，预算耗尽可在候选组中结束，不会额外多跑评价。
PSO：c1=c2=1.5，w约0.9降到0.4。
CLPSO：逐维两粒子竞争选择pbest、Pc从0.05到0.5、刷新间隔7、学习系数1.49445，w约0.9降到0.4。
GWO：历史alpha/beta/delta领导者，a随预算进度由2趋近0。
速度上限统一0.15归一化单位；位置共同夹紧至[0,1]。控制点按lambda排序后解码。四算法采用共同的可行性优先档案；猫群候选概率选择也优先可行池。它们是针对同一配送表示和约束的应用实现，与原论文的无约束连续基准代码不完全一致。

默认WarmStart=true：四算法共享构造出来的可行参考解，周围小扰动初始化，同时保留部分随机顺序个体。共同InitialControl中可能使用局部PSO修复参考航段，这一步在比较前完成，所有算法使用同一份结果；搜索过程中不会暗中调用PSO修复候选解。
因此本批次考察“从共同可行初值继续改善”的表现，最终可行率100%不能解释为从零找到可行解的能力。另统计CandidateFeasibleRate、ImproveRate、RouteChangeRate与初始最优值改善比例。
若需从随机初值开始，设置`'WarmStart',false`，四算法仍共享同一随机种群；此协议需要独立运行，不能与有可行初值的结果混成一组。

## 评价与时间统计

目标=三维总航程+0.05×等待时间+2×航迹平滑项；不可行解附约束罚项，可行解优先。
到达、等待、服务开始与离开时间逐站传递，Due约束服务开始，最后必须按时返仓。圆柱与安全边界接触也算碰撞；地形用双线性网格内极值检查。
T按实际Fitness评价次数记录，初始种群也计数，收敛图从初始种群全部评价完成处开始。
每次搜索完会再做1次结果复算，此次是验证开销，不计为搜索预算，raw_runs.csv单独记录VerificationEvaluations。

SharedSetupSeconds与SetupPathEvaluations单列共同参考航迹构造开销；SetupRepairPSOEvaluations记录其中局部PSO的航段评价次数。航段几何评价与完整配送Fitness不是同一种工作量，不能直接相加冒充统一评价次数。
SearchSeconds包含初始种群的Fitness计算与算法搜索，PopulationSeconds另记生成共同位置的时间。结果按同一程序顺序运行，运行时间包含本机MATLAB/JIT状态影响，正式计时可加入预热并平衡执行顺序。

## 已完成的试验

360次搜索全部完成；360次独立核对通过，全部保存解可行。以下是每种算法在90个小预算运行中，相对于该次初始种群最优值实际改善的次数：

| 算法 | 运行数 | 有实际搜索改善的次数 |
|---|---:|---:|
| PSO | 90 | 90 |
| CSO | 90 | 10 |
| CLPSO | 90 | 75 |
| GWO | 90 | 2 |

上述数字不代表算法的普遍优劣；下一阶段应增加预算与重复次数，并保留固定场景。原PSO保留初值的问题已在新共同编码的真实地形试跑中出现实际改善，但并非每种算法、每次运行都改善。
单地图main.m另实际运行新PSO 20粒子、2020次评价，初始最优目标624.974降低至599.153，航程574.015，返仓163.643，逾期0；该单图使用原20点时间窗，不能与六组实验的数据混算。

## 保存结果

- raw_runs.csv：360次原始记录，包含预算、初值、最终目标、可行性、候选可行率、航程/时间、安全指标、运行时间、原始MAT路径。
- summary.csv：72个组合的均值、标准差、最好值、可行率、改善率、时间统计。质量统计仅使用可行解；没有可行解的组合保留NaN，不用罚项数值混算航程。
- runs/地图/场景/算法_rXX.mat：Best、完整收敛历史T、info、模型、初始状态和输入/代码指纹。
- *_convergence.png / .pdf：每图6场景、四算法平均收敛，另存矢量PDF。
- *_boxplot.png / .pdf：每图6场景、可行解目标值分布，另存矢量PDF。
- routes/地图/算法.png和_debug.png：20点紧窗场景中各算法最佳可行运行的原图叠加路线；_source.csv标明选中运行，_schedule.csv保存配送时刻。
- run_manifest.json：配置、版本、源文件指纹、预期与完成数量。
- independent_checks.csv / independent_validation.json：独立复核的全部记录与结论。

## 验证内容

VerifyDelivery覆盖距离/等待/返仓手算、服务时刻、订单覆盖、净空格内极值、圆柱穿越/上方飞越/相切与高度安全距离。
VerifyAlgorithms用MATLAB profiler核对四算法真实Fitness调用数，含猫群模式与部分候选组预算截止，检查同初值、固定种子复现、最优档案不退化，并验证非最优小案例能实际改善。
Python独立重建排序键、控制点、每段XYZ、航程、平滑项、目标值、全部配送时刻；以≤0.05空间间隔复查地形净空，圆柱采用独立的“高度截取线段后求XY最近点”解析方法；同时检查90组配对初值、输入CSV与代码哈希。

## 算法来源

- CSO：Chu, Tsai & Pan (2006), [Cat Swarm Optimization](https://link.springer.com/chapter/10.1007/978-3-540-36668-3_94)。本项目CSO明确为猫群。
- CLPSO：Liang, Qin, Suganthan & Baskar (2006), [Comprehensive learning particle swarm optimizer for global optimization of multimodal functions](https://doi.org/10.1109/TEVC.2005.857610)。
- GWO：Mirjalili, Mirjalili & Lewis (2014), [Grey Wolf Optimizer](https://doi.org/10.1016/j.advengsoft.2013.12.007)。

距离、高度、时间仍为标准化仿真单位；地形来源见TERRAIN_README_CN.md。
