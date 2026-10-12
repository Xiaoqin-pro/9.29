# 持续停滞才启用纯配额Q：单因素预试（2026-10-12）

全29×5 matched诊断：healthy约65.5%decision，healthyFixed6占~36.4%；Q从20%FE15:14到60%8:21相对Fixed6开始较广落后。F11/F30等退化时多数块healthy。该观测非counterfactual，不预设6总是最佳。

原phase3×stall1000bit6×3表、纯名额2T8S/4T6S/6T4S、100FEdecision、±1reward、alpha.1/gamma.9/eps.1、zero初始化/原搜索公式/半径不变。唯一主改变：signal0强制action3固定6；signal1才启用Q选择。健康块不是Q动作，不训练；stall块只领取自己控制100FE奖励，nexthealthy Q值0（unusedhealthyrows），terminal0，fallback不训练。明确Fixed6fallback来自已开发强基准，不把fallback收益独归学习。

五条件gateq、gaterandom、gate2、gate4、gateeps6，所有healthy固定6；stall分别Q、uniformRandom、fixed2、fixed4、epsilon.1利用fixed6。原alwaysQ和Fixed6同格质量缓存，sourcehash/p0一致才复用。D50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30，原seed2201–2205，InitSeed=21701012+fid10000+seed、SearchSeed+1M。5×8×5=200新run/20MFE，80cached不算新；另F1/F13五条件600FE10smoke，四worker单线程。development已知2201数据不当独立确认。

非gate policy逐点State原Best/T/RNG/Q回归；forcedaction==3、realstallstate从T独立算、free==stall、训练free且fallback合法；nextstate/terminal重放，flat验证forced/free边界。全源快照/MAT/p0/GateLog/T/div/更新保存。

开发门：gateq平均rank严格优于Fixed6/alwaysQ/gaterandom/gate2/gate4/gateeps6，各>=4/8函数均值不差、>=20/40pair不差，无双方>1e−8均值>10倍退化，才新seed完整29验证。gate若random/rule相同有效，不认定Q必要。未过不扫描stallthreshold或epsilon，不把fixed6fallback当成功创新。五seed非显著/非劣。
