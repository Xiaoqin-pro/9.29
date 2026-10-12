# Fixed6-CSO vs 作者源码CLPSO：29函数五种子100k（2026-10-12）

## 用户请求与预先选择
用户明确运行29CEC2017函数、五seed、100000真实评价、“我最好的算法版本”对CLPSO。沿用前述主预算D50，F1/F3–F30，F2按既有协议排除。本次不选看结果后最优方法：CSO用已多批D50诊断较强的B10骨架固定6T4S（无Q/SMP5）；不是宣布全维度全预算最优。作者源码CLPSO选NP40，来源与审计中AuthorSource40一致，NP50敏感性已在小诊断保留但本轮不额外扩网格。两方法×29×5=290新优化run/29MFE，额外290次Best重查单列，四worker每worker单线程。

## 方法身份和公平性
CSO入口ASE_CSO_ModeBudget.m，modeTraceQuota=6，NP50，MR=.4、Tracing/Seeking公式、所有筛选/锚点/回滚完全保持；full round6Tracing+4Seeking，initialization50FE计预算。没有Q、恢复/认知/半径适配或按函数选参。

CLPSO入口CLPSO_CEC_AuthorSource.m，NP40：作者公开包CLPSO_new_func.m Pc0→.5 exp5、gap5、c1.49445、20%init/Vmax、.9→.2 nominalgeneration惯性、stay失败累加/不因改善reset、源示范采样（含自身replacement）、越界移动不真实评价。原论文文字Pc.05→.5 exp10/gap7等与作者公开包不同，故标签明确作者代码profile的CEC适配，不能称完整原论文2006表复现。源archive commit6336e45c7a3c06ed52fb2268d34fbef79eaa29d0，SHA256 e79250ea6a9fc18a5976e19906f58ea6b8418352aa5a173087ee28a4e29f11a9。

适配仅共同caller supplied初始种群、deterministicseed、硬实际FE cap、trace、movementguard和重复最后合法inertia；保留原unused RNG draw。Mechanical source oracle完整逐点Best/T/RNG回归，并补D50 N40/N50边界预算/CEC见证；原CLPSO_CEC不覆盖。NP40为作者论文D30群体设置沿用到本D50比较，不说它是原论文D50指定值。

Seed标签2201–2205，InitSeed=21701012+fid*10000+seed，SearchSeed+1000000。两方法从同50点uniform池开始，CLPSO取前40共同前缀，不能写相同population。真实调用预算相同，所有越界CLPSO移动只记录skip不计FE（不调用objective）。guard50*nominalgen未满足预算则fail，不能把未满的结果写valid。

## 保存与运行
先D50作者oracle48cases、29function有限值检查（检查调用不算优化run），然后F1/F13两方法600FE四smoke，才正式290run。每12个checkpoint，存jobmanifest、environment、实际运行源码快照、全MAT（T/Best/info/p0）。FE/Evaluations/trace length=100000，零域外真实调用，Best重查1单列。运行clock不含MAT存盘、额外Bestrecheck；CLPSO跳过域外移动仍算CPU时间。输入D50全60rotation/shuffle核对官方hash。

## 分析
全29函数均值/标准差/中位数、five paired seed误差、函数均值/中位胜负、全rank、每次FE/first improvement/CPU/skip/iteration记录；逐节点20/60/80/100%曲线按实际FE。Independent Python核对每份MAT/CSV、shared p0 prefix、T单调、每节点、Best/域、模式FE账。精确条件符号秩（zeros剔除/tie中秩/双侧所有sign flips），29函数Holm校正；five seed最小双侧p=.0625，0.05不能检出，均值胜场不得写significant。

最终报告不预设CSO胜：若作者CLPSO强于旧适配，明确旧baseline结果需以新版/身份说明替换。5seed完整集是用户要求的性能筛查，不能宣称全维度/标准预算/SOTA或NRL复现结论；不追加有利seed/变baseline参数。完整raw与sourceproof/输入hash公开，作者原zip/PDF与oracle在work保存。旧数据不删。
