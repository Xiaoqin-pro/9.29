# ASC位置评分改进及8算法比较（2026-10-15，运行前）

用户提供ASC_NoFarness.m作为最新算法，要求29函数30种子比较、MATLAB4worker，排除HIDMS和原始CSO，并加入旧冻结SAQ-CSO。

## 固定比较对象

ASC-NoFarness（原文件默认参数）、ASC-PositionRank（本次改进默认参数）、SAQ-CSO（原30seed冻结配额Q）、CLPSO作者实现、HCLPSO作者实现、HPSO-TVAC、SPSO2011官方C、DMS-SIS2005。保留所有29函数F1/F3–F30，D50，100k真实评价包含初始化，3001–3030。InitSeed=261013000+fid*10000+seed，SearchSeed=InitSeed+1000000；共享50点池前缀，SPSO40、DMS30，其余50。

## 改进范围

原文件保持只读。独立文件ASC_NoFarness_PositionRank.m仅将geometryScreen中决定每个粒子下一位置的rankNear+rankFar改为min(rankNear,rankFar)。真实评价集合sel的近gbest/远中心两阶段筛选不变。这一变化解决特定几何配置下排名完全抵消的退化，不保证总体精度改善。默认positionRankRule='either'；设为'sum'应与原默认单群体逐评价等价。

同时修复useGroup=true时generateGroupCandidates未返回vel的实现问题；默认分组关闭，因此修复不影响本批轨迹。增加Tracing/Seeking实评次数与实评候选不等于下一位置的计数，诊断不抽额外随机数。半径/概率/Jump/位置接受/参数均沿用原版；不添加pbest保护或半径恢复，避免多项改动一起归因。

## 运行顺序和预算

先执行合成预算/确定性/边界/最优档案/排名退化fixture及sum默认等价检查，再真实CEC预检。全部新优化仅原ASC与改进ASC各870次=1740次，174M真实调用；另外六方法可复用同设置已核验261013种子结果5220条。复用前逐条核对来源、预算、源码指纹、初始种群、初始T、最终Best，额外核验调用单列。复用失败则停止，不能跳过失败记录。完整源/CEC数据/hash在启动前冻结；4worker并行，小批增量保存CSV与MAT，可断点复核后继续。

## 输出与统计

全部6960条质量记录合并，按函数输出mean/std/median及所有逐seed结果、29函数曲线和阶段FE误差。各函数用30配对种子双侧Wilcoxon（近似法，ties与连续性校正），主族为原ASC和改进ASC各对其它7方法去重=13对×29=377项Holm。改进vs原ASC另报告29项Holm作为预定机制对照族，不混用两族显著票数。Friedman以29函数均值为block，种子不是独立问题。平均排名只在此8算法集合内有效。

本批是已经开发过CEC2017问题的30重复比较，不能称未见问题泛化。原ASC和改进ASC均不预设必须获胜；真实成本、效果大小、胜负和全部不利函数都保留。缓存与新运行CPU时间仅描述，native-C与MATLAB差异不归算法本身。原CSV/论文及ASC原文件不覆盖。
