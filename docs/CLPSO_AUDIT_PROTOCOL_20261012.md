# CLPSO实现与源码来源审计（2026-10-12）

## 用户问题
用户质疑CSO大幅超过CLPSO的真实性。只检查CLPSO基线，不修改CSO或把使基线输的配置当正确。旧CLPSO_CEC保持原样，新版独立审计入口。

## 第一手来源
Liang, Qin, Suganthan, Baskar, IEEE TEVC10(3):281–295,2006 DOI10.1109/TEVC.2005.857610。作者P-N-Suganthan/CODES提供2006-IEEE-TEC-CLPSO.zip，commit6336e45c7a3c06ed52fb2268d34fbef79eaa29d0，zip SHA256 e79250ea6a9fc18a5976e19906f58ea6b8418352aa5a173087ee28a4e29f11a9。源码和论文原PDF已下载，work/clpso_audit_20261012/source_provenance.json记录。论文及代码明确不同：paper Pc .05+.45 exp10/gap7/排除自身对手；代码Pc0+.5 exp5/gap5/随机包括自身且replacement/失败累加非consecutivereset/初速度和Vmax20%范围/惯性.9→.2。不能把作者包每个值当论文最终版。

## 当前匹配与偏离
仓库当前CLPSO_CEC与20261010两外部结果和20261012重跑源快照LF哈希均相同：1beef61d50ffa8bcfd05efbd06b65c7e63e8ab39fab501430357e192c52f5d41。逐维pbest索引、两非自身示范比较、至少一维外学、Pc公式、连续7未改善刷新正确符合论文文字。初速度1%范围、Vmax15%、惯性.9→.4为项目选择，原paper没有完整写这些数值，不能贴作者精确实现标签。

明确论文边界差异：paper只对合法域位置评价，越界pop保留并继续移动直到回来，不截边；当前clip后立即实评。该适配限制不能单凭方向认定削弱，需小诊断。新PaperBoundary只改此项，保留原FE进度惯性与其它设置，因此不是完整原论文复现。Init20只改初速度1→20%，原15%速度cap不变（初始化后首次update仍cap）。

## 开发小诊断
D30、F1/F6/F13、三新seed2101–2103、真实FE60000/300000。六条件：B10、Legacy、PaperBoundary、Init20、AuthorSource50、AuthorSource40，3×3×2×6=108新run。四worker单线程，六smoke600FE。InitSeed=21601012+fid*10000+seed、SearchSeed+1M；N50共用p0，作者原NP40额外按前40共同前缀，群体不同明确记录。

AuthorSource adapter保留作者包所有公式与RNG（含m=0的unused randperm与零gbest向量rand），消费原p0生成draw后用caller supplied p0覆盖，c1.49445、gap5、Pc0→.5 exp5、init/Vmax.2、w .9→.2按nominal generation而非FE，asyncpbest、不重置改善时failure count、合法点才实评。硬FE cap、完整T、deterministicseed、重复最后合法inertia与50*nominalgeneration移动guard是明确运行适配，不称原paper完全复现。超guard失败不能假充有效结果。

机械oracle从原作者m文件仅改function接口/随机seed/初始p0/硬FE/T/guard，逐点objective points、Best/T、finalRNG匹配，验证我们adapter没有另改策略。原作者源码保留不公开改成作者新版本。原始2006函数集benchmark与CEC2017不同，本轮不比论文表值、不声称复现其2006表。

所有真实调用含initialization严格计数，越界移动不调用目标也不吃FE，记录SkippedOutside/Iterations。同预算误差和时间分别报告，作者source50相同NP对照、NP40仅publishedNP敏感性。三func三seed是实现诊断，不是完整CEC正式基线验收。若结果仍远差说明不能只归边界或初速度；若作者版强则旧CLPSO比较需更正。作者codeprofile与paperprofile混合的结果不得用来挑使CSO更好者。
