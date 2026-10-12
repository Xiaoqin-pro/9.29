# 配额Q机制删减：去触发与去停滞位（2026-10-12）

用户强调越简单越好、容易消融；本轮做删除实验，不添加恢复/holding/visit-rate模块。原B10 search/SMP5/MR.4/半径/screen/anchors不变，Q仅纯2T8S/4T6S/6T4S，每100FE决策，真实gbest改善+10/否则−1、alpha.1/gamma.9/eps.1、zero init。

两个候选同方法骨架：Simple-Q6去掉healthy固定6门，仅phase3×stall1000bit6×3表全程分配；Simple-Q3再去掉stallbit，仅phase3的3×3表（phaseOnly不使用stall控制，日志可留作验证）。无variableholding，无adaptivelearningrate，无reward幅度/多样性塑形，固定rewardBonus10为上轮较稳候选设置。

同原seed2201–2205、D50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30，InitSeed21701012+fid10000+seed、SearchSeed+1M。五组Simple-Q6/Simple-Q3/全程Random/Phase/全程EpsFixed6共200newrun/20MFE，10smoke另列。原Fixed6/原全程±1Q/上一较稳gate+10各40共120质量缓存，同snapshot/实际p0确认后复用，不算新或独立newseed。新增Random/Eps/Phase全程触发，与去门Q公平，不用旧gatedcontrol当同策略。

实现独立简洁入口ASE_CSO_QuotaQ_Simple，compatibility参数仅rewardBonus1/stateprevious或stagnation回归旧State；正式candidate固定10。phaseOnly的gamma bootstrap指实际nextphase，terminal0；fallback不训练，所有真实call含init严格计数。source snapshots/fullMAT/T/Q/state/reward/actual FE/p0保存，四worker单线程。

预检Q6+bonus1旧入口points/Best/T/RNG/QTable/DecisionLog精确回归，Q6+bonus10与EpisodeBonus nongate原branch一致；Q3固定/Random轨迹不因不用state改变，state3映射/Q terminal replay/tail/域正确，logneutral不影响轨迹。只在smoke全过后formal。

分析各候选对Fixed6/Random/Phase/Eps/旧Q/gate+10；删除stallbitSimple-Q3vsQ6同格比較。质量门各candidate rankstrict低于Fixed6/Random/Phase/Eps，各>=4/8均值不差、>=20/40seed不差、无双方>1e−8均值>10倍退化。两都过门优先3×3更简单；只有6过则保留6；都未过不包装简单=有效。删减可见局部tradeoff但不以学习平均rank跨不同集合比，所有条件同表。

五seed开发不是significance/noninferiority，更不是完整29确认；未过不按函数选择Q状态，不继续堆状态/半径或倍率扫描。后续若有可重复范围收益再锁一个入口、三种左右核心消融，先同骨架无Q强Fixed6及同chanceRandom/规则，不使用弱MR变动假归因。
