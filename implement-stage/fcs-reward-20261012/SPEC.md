# FCS奖励开发对照（2026-10-12，运行前冻结）

用户明确允许调整奖励与学习参数；之前的“固定”只约束已完成修复基线，不限制本轮开发。论文目标保持一个顺序评价主机制、两个动作、小Q表，机制与消融由实际结果支撑。

## 依据
S0已通过341-run执行审计。Q对Random逐seed23:17/函数4:4，对同内核Batch17:23/函数3:5。三函数12k诊断Q有2963次父代改善但只有89次即时global改善；同时F1的Switch少量global事件幅度更大，说明仅局部成功和仅global次数均可能不充分。这不是局部收益无长期价值的证明。

## 保持与变量
候选、几何排序、random Tracing、4T6S、starter计数、Switch不同父代语义、6状态、alpha=.1、epsilon=.1均不变。只开发reward模式、正奖励权重以及gamma。旧即时followup nextState保留；gamma0组消除未来回传，用来检验这个粗状态下是否需要discounted bootstrap，不宣传完整MDP最优性。

4奖励设计×2gamma（0/.9），8条件：
- P：parent_binary，当前父代实测改善+1，否则-1（S0基线）。
- G1：global_binary，该次follow-up真实改善gbest+1，否则-1。和P仅换奖励事件。
- G10：global_binary，同事件+10，否则-1。和G1只换奖励权重。
- M10：global_gain，若g=max(0,BestBefore-BestAfter)>0，r=10*min(1,g/s)，否则-1；s为此前正global gain的EMA，首次正gain奖励10；收到gain后才更新s，beta=.1。和G10只改变正奖励幅度形状。
所有g只来自动作实际控制的唯一follow-up FE，不含Tracing和首访，不增加目标调用、不使用未评价动作的未知收益；gain尺度来自历史观测，对函数常数偏置和正比例缩放不敏感（不以bias后的绝对fitness除）。

## 新接口与诊断
state.rewardMode=parent_binary/global_binary/global_gain；rewardBonus默认1；gainScaleDecay默认.1；gamma沿现有接口。可选RewardLog记录Best前/后、gain、scale更新前/后、模式，与DecisionLog逐行对齐；原DecisionLog21列保持。
source默认P/.9/bonus1必须与archive/fcs_reward_20261012基线逐点/trace/RNG等价；既有FCS行为/预算检查仍通过。全局reward对应T followFE前后，anchor局部比较仍正确。

## 预先规定的试验
沿S0的8函数F1/F3/F6/F9/F12/F13/F22/F30、D30/60000FE、seed901–905、4worker，8条件共320格；P/.9的40格复用S0完整原数据（经默认等价回归），新执行其余7×40=280run。这是继续开发，不称独立测试。
固定控制（Batch/Continue/Switch/Random/Success/Reverse）与B10全部来自S0同问题种群/seed/搜索核，保留对照身份。时长只作新组内参考，不用缓存组时长宣传速度。
若某候选在函数均值与逐seed两种口径下都同时超过Batch和Random，再固定一个最小候选用独立seed确认；优先满足效果，其次选更简单设计，不因仅平均rank最好就宣布成功。若没有，停止扩大参数网格，回查机制必要性。全条件与失败结果上传，正式论文参数在确认前另行冻结。
