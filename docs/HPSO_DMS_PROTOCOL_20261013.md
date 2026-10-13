# HPSO-TVAC和DMS-PSO身份、复现核验与正式协议（2026-10-13）

## 固定对比身份

- HPSO-TVAC：采用P-N-Suganthan/CODES公开2017-ASOC-EPSO.zip中的独立HPSO_TVAC.m。文献算法来源Ratnaweera/Halgamuge/Watson2004 Self-organizing hierarchical particle swarm optimizer with time-varying acceleration coefficients；本代码包是后来的独立baseline实现，不称2004原作者代码或复现2004论文表。
- DMS-PSO：采用Liang/Suganthan2005 SIS基础DMS-PSO论文定义，不混称DMS-L-PSO。下载的2005-IEEE-SIS-DMS_PSO_func.zip同时包含SIS-4a_02.pdf（基础版）和CEC_620.pdf（local-search extension），而DMS_PSO_func.m实际有Quasi-Newton和坐标混合。基础版依原SIS Figure2和实验设置重新构造，保留公开文件的标准PSO核心并做明确差异记录。

来源commit固定为4d7ce681d5121e5af1cffb21c5b79ce9df7de5b1。ZIP与原源文件不修改，SHA256记录于work/pso_baselines_audit_20261013/source_provenance.json并纳入运行快照。

## 方法细节与边界适配

### HPSO-TVAC

N50，无惯性项；c1 2.5→.5，c2 .5→2.5；每个速度坐标恰为0时按±U重初始化，重启尺度100→10。实际速度cap为100（[-100,100]上界），不错误使用初始化的20%range作为搜索速度cap。保留公开参考代码k从2起、先计算整群体速度后逐点评价，以及原初始化两个随机矩阵的消耗。

公开独立文件没有位置边界处理。CEC适配增加位置clip到[-100,100]再实评，并公开标注；没有将它冒称未改源码。所有目标输入合法，返回best包含最后一次评价，初始化和末轮均计FE。

### 基础DMS-PSO

依SIS原文使用N30、m3、10个子群、R5。初始随机分组，每5代重组，前90%计划代使用子群best、之后全群global-best PSO。计划代数ceil((maxFE-N)/N)，不能把论文的代比例改成实评FE比例而不披露。若原生越界skip导致实评未满预算，继续全局阶段直到FE用满，并设移动guard。

核心w按SIS原文从.9降至.2：w(t)=.9-.7*min(t,G)/G，额外全局填充代保持.2；c1=c2=1.49445、速度cap20%range、初速±20%range、子群内异步best更新、等值时更新pbest、越界移动不实评。源代码里的keep_d坐标混合和全部fminunc调用不属于本轮基础SIS版本。没有以禁用local-search而把它称为DMS-L-PSO。

这是论文定义的重建版本，机械剥离/调整oracle用于检验接口和实现等价；不能因为两份同源代码一致，就声称全部复现论文无误，所以另加独立手算与拓扑检查。

## 运行前验收（已经通过）

`test_HPSO_DMS_baselines.m`通过，两个方法各29组oracle对照：

- D7/D50、两个搜索seed、仅初始化/N+1/N+17/600/2000/6000FE；Sphere和常值目标。
- CEC F6/F13各600FE和100kFE；两个100k实例/方法。
- 每次目标输入、全T、返回Best、最终RNG和迭代数完全一致；独立合法域/FE/重查契约。
- HPSO首代独立计算见证验证无惯性、cap100、零速度重启；全边界常值群体验证强制重启和clip。
- DMS首代独立手算局部best/membership；所有初始及重组均为30粒子的精确置换，10×3无遗漏重复；R5及90%计划代转global严格检查。
- 全29个D50函数在共同点返回有限值。

验收记录work/pso_baselines_audit_20261013/preflight.json，快照中的source_provenance.json与原始文件锁定代码身份。

## 正式批次

CEC2017 F1/F3–F30，D50，100000次真实函数评价（含初始化），seed3001–3030。HPSO N50，DMS N30；同一50×50初始池，DMS取前30行；initSeed=261013000+fid*10000+seed，searchSeed=initSeed+1000000。

4个MATLAB process worker，每worker单线程。两方法×29函数×30种子=1740份有效质量记录；更正后本轮新增1204个优化run（120.4M真实调用），缓存有效HPSO536个run；每run结束的best重查和smoke单列。运行前source_snapshot及job_manifest、环境、progress、每run MAT与CSV保留。任一失败即停止该批，不把错误run纳入均值。

运行前所有核验通过后再启动正式run。已有五算法4350份数据不重跑、不改数值；只有在源码hash/初始池/FE/MAT核验通过后用于扩展七算法表。种群规模不同要公开，不能写相同population。主表加入新控制后重算全部排名及Holm比较族，不与旧五算法表的排名/显著胜场混用。尚无新结果时不声明性能优越。


## 惯性参数复核、更正和缓存策略

原参数核验遗漏基础SIS printed page127的w=.9→.2，沿用DMS-L源码常数.729。发现后停止混合批次；1072CSV质量记录保留并标为superseded，其中536个DMS不纳入基础版主表，536个HPSO经hash/p0核验可复用。正式重新启动只新增完整DMS870和缺失HPSO334（1204run），不得把缓存536run也算成本轮新优化。

已对六页原文及渲染参数页逐项检查：N30、m3、R5、90%计划代局部再全局、Vcap20%、w .9→.2都由原文支持；SIS论文未完整给c1/c2数值、初速和边界实现。c1=c2=1.49445、初速±20%和skip边界取相关作者代码的明确适配值，不声称复现SIS2005表值。核验已加入独立paperWeight首代见证；预检JSON还绑定当前算法sourceSHA以阻止旧验证记录被用于新代码。
