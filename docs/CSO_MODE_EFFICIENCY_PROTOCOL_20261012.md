# 纯配额Q：过去窗口模式效率状态预试（2026-10-12）

## 目的与已有观察
用户授权继续下一步。保留纯2T8S/4T6S/6T4S配额动作，原B10搜索骨架/半径/Tracing公式不变；之前两半径路线均未过学习必要性门。原120个random-run离线观察：局部接受率~87%窗口Seeking更高；随后总体6T4S常更好，说明简单“接受率高就多给”不等价全局有效。过去1000FE全局增益/实际模式FE：约51.5%窗口Seek更高、12.1%Trace更高、36.4%无差别。此为观察，分组还混搜索状态，不能当因果或保证可学；只支持一个有界检验。

## 唯一主改动
每100FE决策前，取最近100个已完成10FE轮（最多1000FE）RoundLog，G_T=sum(real trace gbest gain)、G_S=sum(real seek gbest gain)、n_T/n_S实际真实调用，e_T=G_T/max(1,n_T)、e_S=G_S/max(1,n_S)。状态仍phase3×bit六格，bit=1{e_T>e_S}，ties及无历史归0。三Q动作及reward±1、alpha.1/gamma.9/eps.1和所有candidate RNG均不变。History窗口只读已完成轮；不含初始化、不含当前动作回报、不读取CEC最优值或虚拟fitness。

顺序每轮先Tracing再Seeking，gbest增益归因可能有顺序偏差；因此只作可观测状态，不把e定义成反事实模式价值。Q不硬编码偏好，允许比直接跟随更灵活。

## 强对照与规则
十一组fixed2/4/6、Random、Phase、EpsFixed、原previousQ、stall1000Q、effQ、effrule、reverseeff。effrule：Trace高选6T4S、Seek高选2T8S、ties选4T6S；reverseeff相反。规则使用完全同过去窗口。Fixed和Random/Phase/EpsFixed也记录新state但策略不依赖它，轨迹需严格等价旧入口。三个Q版本由同一新入口处理，唯一状态不同。

D50/NP50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30，五新seed1801–1805，InitSeed=21501012+fid*10000+seed、SearchSeed+1M，共440新优化run/44MFE，全部控制重跑不缓存旧seed。四worker单线程，先F1/F12十一条件600FE共22smoke。初始化与真实调用全计，Best recheck单列，源快照/完整MAT/p0/T/round feedback/ModeFeedbackLog/Q transitions保存。

## 验证和验收
旧state previous/stagnation、固定所有policy逐点Best/T/RNG/Q表/决策一致；独立从过去RoundLog重算e和窗口边界，第一决策无history，ties明确；当前更新指向下一actual状态；终端无bootstrap，fallback块不训练。Python独立Q重放、FE/域/cap2/p0/真实gbest增益核验。

五seed开发工程门：effQ平均函数rank严格优于最佳统一固定（三个fixed按rank预选）、Random、Phase、EpsFixed、effrule，分别>=4/8均值不差、>=20/40seed不差，无双方>1e-8且均值>10倍退化。previousQ/stallQ/reverseeff全部报告，不挑最弱控制或删除不利F13。过门才冻结effQ十新seed确认；未过不扫更多window/状态或奖励网格。局部接受率作为offline阴性诊断不另外加Q候选。

三state仍6×3，不加入半径/重置，效率是状态信息而不是新目标。若直接/反向规则有效而Q不更好，保留规则发现但不能写学习成功；若全部弱，当前配额接口可能只需强固定，讨论主贡献定位而非不断增加机制。
