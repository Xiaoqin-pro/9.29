# 两路线比较结果与下一步（2026-10-12）

## 本轮完成
A统一Seeking阶段适配360新run+B配额动作绑定停滞半径160新run，D50/100k八函数五新seed1701–1705，520run/52M真实FE，520额外Best重查和A18/B8 smoke分开列。四worker完成，当前无MATLAB实验进程。两路线40格实际p0相同、22源快照与运行前版本一致；完整T/状态/奖励/Q转移/terminal/实际尺度/触发独立检查通过。

A无改动入口59组逐点等价、63行为和flat238轮触发见证；B59等价、171行为和flat9块触发见证。此前未执行草案测试Sphere无触发而停止，现修正flat见证计数，不修改算法Sphere轨迹来凑通过。原withdrawn runner仍保护，新B入口依用户后续明确授权运行。

## 核心结果（均值/配对票数，非显著性）

|比较|函数胜/负|seed胜/负|结论|
|---|---:|---:|---|
|A-Q vsA-fixed6|3/5|18/22|未胜强固定|
|A-Q vsA-random|4/4|20/20|整体rank相同，未显示学习必要|
|A-Q vsA-Phase|3/5|18/22|规则更好|
|A-Q vsA-EpsFixed|3/5|14/26|同探索率固定更好|
|A-Q vsOld-Q|1/7|17/23|统一适配没有保住原Q效果|
|A-fixed6 vsOld-fixed6|3/5|18/22|模式适配本身也未稳定改善|
|B-Q vsB-Rule|2/6|19/21|半径规则更好，非Q必要证据|
|B-Q vsB-Random|2/6|14/26|未超过同机会随机|
|B-Q vsB-EpsFixed|4/4|18/22|未稳定改善|
|B-Q vsOld-Q|5/3|22/18|局部票数改善，需看退化幅度|
|B-Q vsOld-fixed6|4/4|18/22|未胜统一强控制|
|B-Q vsA-Q|5/3|24/16|B比A更好，不等于B成立|

13条件rank最低Rule-reset4.875，Random-reset5.5，Adapt-EpsFixed5.625，Old-Q5.875，B-Q6.625，A-Q7.625；A最强统一固定=Adapt-fixed6 rank6.875。两路线均未过预写Q必要性联合门，SelectedRoute=null。五seed只是开发，不运行未过门新seed确认，也不事后改规则选择一条说成功。

B-Q虽比Old-Q函数5:3，但几何平均误差比1.166，几个退化函数幅度不小，不能只用票数写总体优越。全函数、seed、幅度与图公开。A的前中期大半径不应预设“保持多样性=更好”：它改变了原骨架精细搜索与有效接受；B的直接恢复规则虽在本批rank最好，也未独立确认。

## 简洁与学习的取舍
为了符合用户Q配额主故事，保留原纯配额入口ASE_CSO_ModeQ_State.m及B10强固定作为主锚点；A/B均为开发分支，暂不放入论文正式方法。B恢复可以留作搜索机制备选，但其作用目前更像规则收益，不能把Q名义挂在规则效果上。

下一项更聚焦的问题应是Q输入/反馈是否能分辨两模式的真实评价效率，而不是继续扩大半径或加Tracing算子。phase/stall描述什么时候困难，不直接告诉哪种配额更合适；两个Q候选动作占比仍约均匀。可先用现有RoundLog离线检查过去窗口的真实模式接受/gbest单位FE收益与随后改进的关联，再决定单个状态或单个奖励试验。保持动作纯2T8S/4T6S/6T4S、原搜索公式、强固定/随机/同信号规则，门前不宣称成功。

用户允许多路线探索不等于应把所有机制合并。当前两路线各增加一项已够诊断，不做更多reset/floor/spread网格。本轮目标是选更合适路线；结果是尚无适合定版的新增搜索路线，保留原锚点和全部证据。

## 交付
results/cso_two_routes_20261012/全部520raw、13×8汇总、所有配对、route gate、独立artifact/cross checks、smoke、源码哈希、真实div/stall轨迹图。MAT和源快照本地A=results/cec/cso_search_adapt_study_20261012_163808，B=results/cec/cso_linked_radius_study_20261012_165015。协议CSO_TWO_ROUTES_PROTOCOL_20261012.md先于启动保存。
