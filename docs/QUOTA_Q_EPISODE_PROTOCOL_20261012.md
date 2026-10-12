# 停滞纯配额Q持有500FE：反馈时长单因素预试（2026-10-12）

## 用户请求与假说
用户授权继续修该小Q，不宣称保证成功。原gate40run共14944停滞尝试离线：当前100FE改善6.27%、随后包含其它动作的500FE改善26.42%，93.40%窗口换action，20.15%100失败后500改善。这是观测诊断，不是原action延迟credit，不能把其它action收益补回。

## 唯一主改变
healthy仍100FE检查/Fixed6；真实stall>=1000开始的free尝试选择三配额之一，连续保持500FE（50个10FE轮）后再更新Q及下一实际状态。尾窗口用实际剩余FE，Q reward整个已持有窗口gbest有无改善±1，仅属于该action controlled FE，不加额外objective。若窗口中改善仍保持至预定结束，之后才返回healthy强制Fixed6。正常/停滞触发、phase3×bit6×3表、alpha.1、gamma.9 per100FE、epsilon.1、zero init、三纯配额、原半径/search/screen/anchors均冻结。

由于窗口真实时长不同，bootstrap discount=gamma^(actualDurationFE/100)（500FE=.9^5）；healthynext Q rows未训练为0，terminalbootstrap0。reward是区间整体event score，不自称经典逐FE累计reward等价。100FE兼容分支必须逐点复现StallGate，避免默认control变弱。

## 同窗口Q必要性
episode500 gateq/gaterandom/gate2/gate4/gateeps6五组，所有healthy相同Fixed6/free持有相同500FE，直接rule和Random享有同保持机会。D50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30，原开发seed2201–2205同p0/search seed（InitSeed21701012+fid10000+seed,SearchSeed+1M），200新run/20MFE，10smoke600FE。缓存原gate100五组200与Fixed6/alwaysQ80质量同格，cache共280，不算新或独立confirm。四worker单线程，全MAT/T/p0/actualwindow/gate/state/Qupdates/discount源码保存。

## correctness与选择
episode100原trajectory/Best/RNG/state/Qtable严格回归，healthyhold100/freehold500、closedtimelines、tail、actualreward/T anchors、nextstate/terminal、discount不同真实时长精确核验；logneutral不影响trajectory。Q只训练free无fallback。固定6及非gate策略不受episodeFE影响，flat witness持有时不因停滞延长自动换action。

episodeQ平均函数rank严格低于Fixed6/alwaysQ/gate100Q、所有同episodeRandom/2/4/Eps，各>=4/8函数均值不差、>=20/40pair不差，无双方>1e−8mean>10倍退化，才新seed完整29confirm。其它gate100control全部报告，门未过不扫更多100/200/1000FE时长、不同时调整reward/radius。五seed开发非显著/非劣。若保持本身改善而Q未胜Random/rule，不能称修好Q。
