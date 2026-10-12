# 有效3×2表：保留停滞、删除空行和低Tracing动作（2026-10-12）

用户偏好简单易消融。200去gate/去stallbits实验都未过强门：去gateQ6对较稳gatedQ2:6/16:24；只phaseQ3对6state1:7/15:25，不能只追表小丢有效信号。本轮删的是无需训练行与较弱action，不添加新mechanism。

保留原healthyFixed6/stall1000才Q、100FE决策、truegain+10/否则−1、α.1γ.9ε.1/zeroinit、B10/SMP5/MR.4/原半径/search不变。Q仅自由停滞state训练，healthy3rows原来一直0可精确删除，Q实际state只phase1/2/3三行；遇到nexthealthybootstrap显式0，terminal0。候选action仅4T6S/6T4S两列，删除2T8S；健康固定6仍有真实反馈统计但不训练Q。动作编号1=4T6S、2=6T4S，不能错用2*action；info.TraceQuotaOptions明确。

旧compact=false/threequota默认branch逐点复现EpisodeBonus；compact=true/threequota与默认trajectory/Q rows2/4/6相同（healthybootstrap0），证明删空行无行为变化；再删action2T是唯一会改变行为的主因素。四条件Compact-Q/Random/Eps6/Rule4，所有同healthyFixed6/free持有100FE，相同actionset；Eps利用6且epsilon同为.1，Rule停滞切4。旧Fixed6/原alwaysQ/较稳gated+10三组quality各40缓存同p0。不用三action随机作两actionQ必要性主对照。

D50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30、原seed2201–2205、InitSeed21701012+fid10000+seed、search+1M，160新run/16MFE，8smoke600FE，四worker单线程。全source/MAT/T/state/gate/真实actionquota/fallback/Qnext/terminal/真实p0保存。actualQ3×2与所有trace quota账重放。

开发门CompactQrankstrict胜Fixed6/同CompactRandom/Eps/Rule4，分别>=4/8函数均值不差、>=20/40pair不差、双方>1e−8无mean>10倍退化；旧gatedQ和SimpleQ3/Q6完整报告，但门不强求每历史版普胜。过门才newseed完整集confirm；未过不继续删更多action或改state阈值。本轮最多两stage删减，总新360run/36MFE，18smoke单列，五seed开发非显著/非劣。


## 实现预检补充
首正式批12run中6个遇到badsubscript：两个Q/epsilon分支仍随机抽第三个动作；该批自动停止、保留失败记录，不并入结果。修正所有randi为actionCount，加入5051FE持续flatstall见证强制探索两动作，旧三动作保持原行为；成功预检后重跑全160而非拼接不同源码。
