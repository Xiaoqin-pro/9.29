# CSO模式统一适配 × 纯评价配额Q（2026-10-12）

用户明确两个层次：Q只分配真实评价配额；Seeking/Tracing公式适应前中期多样性和后段停滞，对所有控制统一。前次action1绑定半径草案已撤回，未执行正式优化。

## 一个模式改动
原B10 Seeking保留0.25精英引导、SRD=.05、CDC=.2、SMP5与全部其它公式。原扰动半径scale=1−p，改为健康scale=min(1,3(1−p))，即前2/3保持初始幅度、后1/3线性缩小；后1/3若距离上次真实gbest改善>=1000FE则scale=1，下一轮改善后恢复健康缩小。每轮在生成候选前以已发生的FE、lastImprovementFE计算，不读取Q动作、不用CEC最优值、虚拟fitness或事后奖励。Tracing、MR=.4、筛选、真实锚点和接受不变。当前只是一个待验假说，不称已保多样性或能保证逃逸；不把两个阶段各称一个独立创新。

## Q与公平控制
Q仍phase3×真实1000FE持续停滞bit的6×3表，每100FE选2T8S/4T6S/6T4S，binary±1，alpha.1/gamma.9/eps.1、独立策略随机流。所有Adapt条件共享完全同一半径函数；Q不控制半径或额外搜索算子。Old开关=false逐点恢复原State入口，Shared kernel只是增加独立可删模式公式。

九条件：Old-fixed6、Old-Q、Adapt-fixed2/4/6、Adapt-Random、Adapt-Phase（前2/3固定4，后1/3固定6）、Adapt-EpsFixed（利用固定6）、Adapt-Q。D50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30五新seed1701–1705。InitSeed=21401012+fid*10000+seed，SearchSeed+1M。共360新run、36MFE，初始化全计，Best重查单列；四process worker每worker单线程。18smoke：F1/F12九条件600FE。公式、协议、源快照/全MAT/初始群体/决策/Q更新/div/stall/每轮scale日志保存。

## 预检与验收
Adapt=false Best/T/RNG/决策/Q表默认逐点回归；scale日志独立用T重算stall并核对exact p、阈值与公式；健康前中期=1、健康晚期收缩、停滞晚期恢复，动作不在公式输入。固定策略、Q真实预算/域/cap2/terminal重放核验。初始数据与全部控制相同。

两个问题分开：Adapt-fixed6 vsOld-fixed6检验骨架改动；Adapt-Q vsOld-Q检验组合效果，不能归因仅Q。Q必要性需Adapt-Q在同Adapt骨架上rank严格优于最强统一固定（按八函数rank选）、Random、Phase、EpsFixed，各>=4/8均值不差、>=20/40配对不差、无双方>1e-8均值>10倍退化。模式改动候选自身若旧fixed6明显更强，也不能只靠Q故事定版。全部均值/标准差/配对/真实div与stall公开。

若过开发门才独立新seed确认；若仅Adapt固定更好而Q无优势，保留模式候选但不称Q成功。五seed不是显著/非劣结论。无按函数设置scale、奖励或阈值，Tracing暂不动，避免同时改两模式或不断扩大机制。
