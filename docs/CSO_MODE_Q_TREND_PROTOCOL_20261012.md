# 小Q趋势诊断协议（2026-10-12）

用户希望保留此版小Q，并借鉴导师前期多样性、后期停滞思路。本轮先记录事实，不把Tracing/Seeking预先贴探索/开发标签。

回放原ModeQ同seed同公式，D50/100k，F1/F6/F9/F13，原seed1401–1402，Fixed2/4/6/Q，32次诊断run。使用上一轮相同InitSeed=21101012+fid*10000+seed与SearchSeed+1M，必须与已保存原run的Best/T/决策/Q表完全相同；不是32次独立新seed效果复验。多样性日志仅每100FE读取，不加真实评价、不消耗RNG。

记录真实锚点种群与虚拟种群的范围归一RMS坐标离散度、真实fitness范围、距离上次真实gbest改善的FE数、Best。定义div=sqrt(mean(((population-mean(population))./(ub-lb))^2))；用realPop用于解释真实搜索覆盖，虚拟div仅诊断，不能冒充已有真实fitness的多样性。初始div、state/action和真实增益同步保存。中性检查含日志开关、CEC回放、停滞FE对照T。

离线分析原280run所有phase/state/action收益与正奖励率；32run新增div曲线/停滞分布，按前、中、后三阶段拆开。当前回放成本统计单列，不能加到“新增独立效果run”或用重放作为又一次支持。

在诊断完成后才确定单因素反馈实验；优先保持6×3表、原三配额和所有强固定/规则对照，不增加搜索算子。前期div保护、后期escape仅在真实观测支持相应控制作用时定义，不承诺通过任意设置必获胜。
