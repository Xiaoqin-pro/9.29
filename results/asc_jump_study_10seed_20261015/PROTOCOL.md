# ASC Jump强度单因素实验（2026-10-15，运行前）

目的：确定原ASC的频繁且较大规模Jump是否帮助恢复搜索，或同时干扰有效收敛。原文件ASC_NoFarness.m保持原样，只通过已存在state参数设置三条件：Original(useJump=true,jumpFraction=.50)、NoJump(useJump=false,jumpFraction=.50)、LightJump(useJump=true,jumpFraction=.10)。默认N50、eliteFraction=.20、jumpProtectElites=true；每个非空Jump分别选择20/4个非精英位置，NoJump不执行。pbest/globalBest保留，Jump自身不调用目标函数。

三个条件共享原几何sum评分、自适应概率/半径、Jump触发jumpGens20/jumpUnit generation（1000真实FE）、候选生成、位置更新、perOwnerCap2、所有默认参数，不增加pbest回退、不增加Q和新算子。后续轨迹因Jump随机抽样不同自然分歧，同初始种子不等于未来候选始终相同；这属于算法效果，不改变普通RNG实现。

D50/N50/100k实际目标调用（含初始化），F1/F6/F9/F13/F21/F22/F27/F30，种子5001–5010（现有公开config中未发现重叠），4worker。InitSeed=261013000+fid*10000+seed；SearchSeed=InitSeed+1000000。240次全新优化=24M实际调用，无缓存性能样本。函数集合已用于开发，本批是新的随机重复，不是未见函数泛化。

先做合成预算/边界/确定性/default-explicit等价/恒定目标触发/第一次Jump之前相同评价点、无Jump时不同jumpFraction中性、CEC预检。执行源文件、协议和依赖在启动前冻结哈希。每run用独立回调实际计数，并重建best-so-far轨迹逐点检查；优化后1次best重评独立计数。预检调用不算性能样本。无效运行停止，不丢掉错误后继续挑结果。

统计三组所有成对比较，共8×3=24项双侧配对Wilcoxon及Holm（30seed正式表不混入）；均值/标准差/中位数、配对胜负、rank-biserial、函数排名同时输出。总体比较不加总跨函数原始误差。每条件各80条，完整函数均值和阶段曲线保留。

预定进入独立确认的筛查条件（对NoJump和LightJump分别对原版检查）：至少5/8函数均值更好；函数均值比中位数<=.95；没有函数均值恶化超过20%；F6与F9各不恶化超过10%。只是稳健开发筛查，不是显著性保证或通用定理。若两者均过，按函数均值比中位数较小者作为候选；并列选更简单的NoJump。未通过则保留原参数，不在本批继续加配置或调整筛查条件。任何新种子或29函数扩展需报告本批结果后再计划。

诊断：读取原RoundLog的Jump事件、FE和自适应参数，报告每轮Jump频率、首次Jump、末轮无后续搜索的Jump，按代码受影响个体数计算位置重置总次数（非不同粒子数）。记录20/60/80/100k阶段误差及末20k各seed改善分布。Jump前后改善仅是描述；不将时序相关当作脱困的因果证据。

预计运行后结果目录results/asc_jump_study_10seed_20261015，原MAT/源码快照独立存results/cec。只在完整核验后输出结论，不覆盖既有实验或论文。
