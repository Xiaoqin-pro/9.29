# 简洁优先：机制删除与最后保留的研究候选（2026-10-12）

## 执行范围
删除gate/再删stallbit200有效run/20MFE，压缩空行+两动作160有效run/16MFE，共360用于质量比较的正式开发run/36M预算内FE；18smoke和360Best重查单列。两动作首次正式启动12run包含6个badsubscript失败与6个已完整run，自动停止、不进入性能集，消耗与原记录单列failed_attempt.csv。两个错误分支从randi3修正为actionCount，增加flat5051FE强制探索见证，重跑全160，旧三动作行为未改。

## 删除结果
|删除项目|配对结果|判断|
|---|---|---|
|去healthyFixed6触发gate，全程6×3 +10Q|对gated候选2:6/seed16:24|删后质量不足|
|进一步去stallbit，只phase3×3全程Q|对全程Q6=1:7/15:25|phase-only信息不足|
|删健康Q的恒零空行，保持threequota|59组压缩Default/CEC回归、轨迹/Best/RNG和Q自由行完全一致|可无损压缩为有效3×3|
|继续删2T8S，三phase×2actions|对gated3action2:6/16:24，同两actionRandom2:6/15:25、Eps2:6/18:22|不能因更小就采用|

完整compact160run独立Q映射/realFE/forcedfree/actualquotas/nexthealthybootstrap0/terminal检查通过；cache120p0匹配。56默认old等价、59compressed等价、60twoactioncases（含longflat探索）、4logneutral通过。三个动作须保留，未按函数选择删action。

## 当前最简单且没有降低已有候选质量的形式
研究入口src/ASE_CSO_QuotaQ_Candidate.m：
1. 真实stall<1000FE时保持6T4S。
2. 达阈值才从当前phase的Q三行之一选2T8S/4T6S/6T4S，持有100FE。
3. 区间内真实gbest改善+10，否则−1，alpha.1/gamma.9/eps.1/zeroInit更新；healthyforced动作不训练。

Q有效3×3表，stall检测只作为一个开关，不再同时存三条始终不训练的healthy行。phase作为三行索引，nexthealthy目标值明确0，与原6×3 healthy恒0数学等价。MR=.4、Searching/Tracing/半径/筛选/真实锚点/accept均原B10，没有恢复/held500/visit-rate/radius模块。

该入口固定参数，不把历次开发switch暴露为方法参数；底层Compact兼容分支为复现历史与fixed/random ablation保留。原正式ASE-CSO文件未覆盖，此处是research候选，不宣称已冻结paper性能。候选额外入口与原较稳gate+10逐点Best/T/RNG及自由Q行一致检查执行，结果candidate_entry_checks单列，不是新增效果证据。

## 如何简单消融
保留同骨架：fixed6（删Q的强固定）、同stall机会Random（去学习但留触发）、同epsilon利用fixed6（探索本身）、原fullQ（触发删减），三action与FE条件完全相同。核心三个机制只应是稀疏评价/可信状态管理、小Q真实配额；stall/phase/reward是Q的简单定义，不每个都包装独立创新。不要机械做全评价+quotaQ无意义四格。

## 尚未达成
较稳gated+10对Fixed6开发5:3/20:20，但对同triggerRandom4:4/16:24、同Eps3:5/18:22，强必要性仍未过；本次空行压缩不会凭空创造新的性能提升。简单只是更清楚更可审查，不等于成功。full29带Q21:8对CLPSO优势主要有B10骨架基础，不能归Q。

下一项更合适是将这个单一入口与同stallRandom/Eps/Fixed6做完整函数/新seed范围验证，不继续更多模块/动作/learningrate网格。若Q不额外有效，必须缩小学习主张或重新考虑配额反馈对象，不能为漂亮消融换弱MR。

公开results/quota_q_simplicity_20261012/与quota_q_compact_20261012/保存全部有效/失败记录分开、sourcehash、检查、图、120/320cached记录origin。所有优化已结束、无后台MATLAB。
