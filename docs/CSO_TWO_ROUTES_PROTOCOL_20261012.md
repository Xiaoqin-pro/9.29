# 两条简洁路线公平比较（2026-10-12）

## 用户授权与优先级
用户明确主要贡献Q-learning分配真实评价名额；模式自身可按前中期多样性/后期停滞现象统一改进。又明确允许尝试此前“stall且选Seeking多的动作恢复半径”作为另一候选，路线依据实验选择。本轮只比两条最简单路线，不先扫更多半径。不将未执行草案当实验，也不为了成功改强对照或隐藏失败。

共同骨架B10/SMP5、MR=.4、Tracing公式、Seeking精英项/SRD/CDC、空间筛选/cap2、真实锚点/接受完全一样。Q仍phase3×真实1000FE停滞bit 6×3表，100FE决策、±1奖励、alpha.1/gamma.9/eps.1。

## 路线A：模式统一适配，Q纯配额
所有Adapt固定/随机/规则/Q同一公式。Seeking scale=min(1,3*(1−p))，前2/3保持初始范围、后1/3细化；后1/3且真实持续1000FE无gbest改善时scale=1。每轮只读已发生FE和lastImprovementFE，不读Q动作。动作只分配2T8S/4T6S/6T4S真实名额。Tracing暂不改，多样性只记录。

九组Old-fixed6、Old-Q、Adapt-fixed2/4/6、Adapt-random/phase/epsfixed/Q，各40格=360新run。Old改进开关=false逐点复现State入口。Adapt-phase原规则前2/3固定4后1/3固定6，EpsFixed利用固定6，所有control同半径适配。分析A-Q是否超过A最强统一固定、Random、Phase、EpsFixed，骨架增益Old-fixed6 vsAdapt-fixed6分开，不将共同模式收益归于Q。

## 路线B：配额动作绑定停滞恢复
只测试reset，不运行floor/spread。每个100FE块决策时若真实stall>=1000且action1(2T8S)，该块Seeking范围恢复初始baseWidth=.05*(ub−lb)/2；其它动作/健康块沿原(1−p)。Q动作在此包含配额+搜索强度，是路线B与A的实质不同，文章不能称严格纯配额。

四组Q-reset、Rule-reset、Random-reset、EpsFixed-reset，各40格=160新run。Rule在健康固定6、停滞直接action1；Random/EpsFixed同动作/触发规则，EpsFixed利用固定6。B四组共享候选行为映射，不让Q独享恢复。A中的Old-Q/Old-fixed6是B无恢复强对照（同格、同seed/目标/公式，源码回归后可作缓存对照，不算新增run）。若规则同样好，不能说Q必要。

## 环境和总量
两路线同新seed1701–1705、D50/NP50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30。InitSeed=21401012+fid*10000+seed，SearchSeed+1M，两个runner完全一致；总520新run、52M预算内调用。初始化全计，Best重查单列。四worker单线程，A18/B8smoke后正式，分批持久化，所有源快照、初始p0、全T、round/modeFE、Q更新、真实div/stall/scale/恢复记录。

预检A/B无改动开关逐点Best/T/RNG/动作/Q表等价、真实stall由T独立重算、A scale所有控制同函数、B trigger按真实state/action，width与所有实际FE匹配、回退mask不能给未执行action信用、Q转移/terminal重放。此前reheat测试Sphere样本未触发，active witness应由flat objective确定触发；修正测试见证，不修改Sphere outcome或算法来通过。

## 先于结果的选择
全部13组质量同表与配对公开。路线A完整Q需rank严格优于本路线三固定中最佳统一配额、Random、Phase、EpsFixed，各>=4/8函数均值不差、>=20/40seed配对不差，双方>1e-8时无均值>10倍退化；此外相对Old-Q/Old-fixed6完整报告。路线B Q需对本路线Rule/Random/EpsFixed及Old-fixed6各同门，不能只胜Old-Q。

两条都过门，优先确认rank更低且公式更简洁者；rank接近(差<=.25)优先纯配额A。开发门不等于显著/非劣，五seed不写SCI最终主张。只一条过则十新seed确认该条全部强对照；都未过先报告失败/局部权衡，不立刻扩大半径网格或加Tracing新机制。

预写范围随用户最新授权：绑定半径此前已撤回，现仅在新协议授权下独立B runner重新启用，旧withdrawn runner保护保留。文献讨论保留在撤回草案仅作背景，不把设计当完整文献复现。照片及老师趋势作为动机，不单凭平滑均值曲线证明局部最优/逃逸。
