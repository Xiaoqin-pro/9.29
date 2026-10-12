# 持续停滞配额Q vsCLPSO：同格29函数100k（2026-10-12）

## 用户请求与预先算法选择
用户要求“带qlearning最好的版本与CLPSO，相同规模”。选现有原B10骨架/phase3×真实1000FE持续停滞bit小Q（ASE_CSO_ModeQ_State），Q仅选择2T8S/4T6S/6T4S，不改搜索算子或半径，SMP5、MR.4、6×3表、100FE块、binary±1、alpha.1/gamma.9/epsilon.1、zero init均原样。该版机制简单且有独立确认记录，不声称已稳定胜Fixed6；效益state/半径/init候选未达到强门，不能看新batch结果后挑Q。

## 同规模与缓存
沿上一批CEC2017 F1/F3–F30、D50、100000真实评价、种群50、seed2201–2205。InitSeed=21701012+fid*10000+seed，SearchSeed+1M与前290run严格相同。新增仅29×5=145次Q运行/14.5MFE，145Best重查单列；CLPSO作者profileNP40和Fixed6 NP50各145旧运行缓存比较，不是新增290。总质量记录435。两方法共享50点池prefix，Q与Fixed6全部p0相同，CLPSO前40相同；不将population40vs50写相同population。

CLPSO配置与前CLPSO_FULL_100K_PROTOCOL一致，作者代码非paper参数配置的CEC适配。复用之前独立验收sourcehash/输入hash/actualFE/完整MAT；若cachedsource和当前objective/同骨架哈希不一致立即fail不继续缓存。只质量比较共用来源，缓存时间与新时段差异明确，Q多div/state日志成本也可能影响计时，不把跨批微小秒差归Q。

## 正确性和运行
前已有State默认59等价/168cases、640独立Q replay验收，本次源码normalizedhash保持一致不重复广泛测试。四worker每worker单线程，F1/F13各600FE两smoke通过后正式145run。源快照/manifest/environment/完整T/info/Q transitions/StateLog/RewardLog/TrendLog/p0均保存。100000真实调用含init，域外0，Bestcheck1单列，cap2、模式FE、state/奖励/真实nextstate/terminal与fallbackmask独立核验。

## 分析
完整29均值/标准差/中位数、145配对种子胜负、全curve节点、actualaction占比、Q状态学习；与CLPSO及Fixed6都比较，不能只用胜CLPSO证明Q必要。三条件全排名+pairwise，两比较都精确条件符号秩双侧29Holm；5seed最低p=.0625，不能在0.05显著，均值票数非显著。所有函数/seed公开，包括CLPSO/Q/Fixed6各自优势；不事后改参数、替换Q或补有利种子。

本批是完整函数低预算筛查，非全预算/维度/SOTA结论；Q如不胜Fixed6只能说明对外精度而不是学习增益。无新增搜索机制，源条件在运行前冻结。
