# 纯配额Q相对模式效率状态结果（2026-10-12）

## 完成范围
440新run，D50/100k、八函数×五新seed1801–1805×十一条件，44M真实预算内目标调用，440额外Best重查、22smoke单列。4process worker单线程。230旧策略精确Best/T/RNG/Q回归、66窗口/规则case通过；全部440MAT完整轨迹、实际FE、过去1000FE窗口、state/action/reward/下一状态/terminal Q独立核验通过。当前无运行任务。

## 主结果
Q动作仍纯2T8S/4T6S/6T4S；原B10骨架、Seeking半径、Tracing、reward±1、alpha.1/gamma.9/epsilon.1、6×3表不变，唯一主变为phase3×过去Trace实际global gain/FE高于Seek的bit。

|effQ相对控制|函数均值胜/负|seed胜/负|控制rank|
|---|---:|---:|---:|
|原固定4T6S|7/1|25/15|6.875|
|最强固定6T4S|1/7|18/22|4.375|
|Random|5/3|25/15|7.625|
|Phase|3/5|20/20|5.75|
|EpsFixed|3/5|18/22|3.25|
|同反馈effrule|2/6|16/24|4.25|
|反向规则|8/0|25/15|8.5|
|原previousQ|6/2|18/22|6.375|
|stallQ|4/4|19/21|5.5|

effQ整体rank5.375，联合开发门未过。effrule对Fixed6函数5:3/seed22:18，对Phase5:3/26:14，但对EpsFixed3:5/18:22；规则有部分可用信息，不证明普适最佳。五seed非显著/非劣，全部控制/不利结果公开。

## 反馈与学习诊断
原120random-run离线：local接受率~87%窗口Seek更高而下一块Fixed6常更好；global signal Seek高~51.5%、Trace高~12.1%、tie~36.4%。观测分组混合真实搜索状态和轮内Trace先Seek后的归因顺序，不能当反事实最优。

本轮effQ动作仍30.3%/32.1%/37.6%，没有像effrule那样强响应信号（53.3%/36.8%/9.9%）。许多Q状态动作值接近，相对稀少Trace高state访问较少。当前负奖励、零初始化、折扣与非平稳收益共同作用，不能仅因epsilon=.1就断言只有10%在探索；零值/并列也会影响选择。未发现实际执行或信用计数错误。

因此改变state信息还没有解决学习必要性。当前不补效益window长度网格或新搜索机制，保留原纯配额Q锚点、Fixed6/EpsFixed/effrule作为强控制。下一项可考虑学习行为单因素：先用已保存Q更新日志诊断零初始化/负奖励下的值差和贪婪动作切换，再决定有界初始化或反馈方案；不可用只学固定6来假装状态学习，不把过拟合开发均值写论文结论。需要新协议和独立证据。

## 交付和来源
公开results/cso_mode_efficiency_20261012/：全部440raw、11×8summary、所有比较/配对、state-action feedback、final Q tables、lagged offline诊断、完整gate与两种checks、源码哈希、全八函数真实div/stall曲线。MAT/source_snapshot results/cec/cso_mode_efficiency_study_20261012_171424/。offline lagged_random_blocks为原120run衍生，不算新增run。

GitHub曾持续DNS失败，本地所有代码与结果提交保留。不会宣称未成功推送已上传。
