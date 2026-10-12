# 停滞配额Q真实改善奖励倍率检验（2026-10-12）

用户授权修好当前Q，前两层改动（健康Fixed6保护、free500FE保持）相对原alwaysQ都有开发改善但未胜同Random。保持Q6×3、纯配额、原搜索、MR.4和半径不变。只将真gbestgain>0奖励由1改10，失败−1。100FEgate与500FEheld各一个candidate，reward变化是已有两个设置各单因素，不同时改窗口来归因bonus。

正改善倍率10借导师稿件使用值，仍仅对实测gain记奖励，不因选择探寻动作就奖励。仿射reward理论上不自动改变无限平稳最优策略，但有限时间初始化/探索和值差会变，不能凭倍率变大声称修复。对两个窗口均保留原bonus1同格轨迹对照；同windowRandom/固定2/4/Eps及Fixed6/alwaysQ质量全缓存。reward对未学policy不影响action，因此规则无需重跑；若原source/seed/p0不同不得缓存。

D50/100k八函数五seed2201–2205，InitSeed21701012+fid10000+seed、SearchSeed+1M，80新run/8MFE；480旧质量缓存不算新seed确认。四worker单线程，先F1/F13两condition600FE四smoke。参数α.1γ.9/100FEε.1、init0、stall1000等原样，500FEbootstrapγ^5。bonus1默认精确回归、真gain与reward/terminal重放、forced不训练和预算合法独立核验。

每个候选需平均rankstrict胜Fixed6/alwaysQ/相同durationRandom/2/4/Eps和原同durationQ，各>=4/8均值不差、>=20/40seed不差，无双方>1e−8mean>10倍退化才新seed确认。全部80及cached都报告，未过不加50/100bonus倍率网格，不看结果后降低门。80run是同格开发，非论文成功。
