# FCS首访相对质量状态验证（2026-10-12，运行前记录）

## 根据与最小变化
奖励开发280新run没有条件通过同时胜Batch/Random的门槛，停止扩大同类参数网格。新假设针对信息定义：首访是否改善自己的父代，不能区分“8→9仍较优”与“100→90仍较差”。用首访真实候选代价与当前可信fitness的前20%阈值比较，更新同一个二值状态。状态数量仍3阶段×2=6，动作仍Continue/Switch，搜索算子和稀疏预算不增加。
阈值复用现有eliteCount=max(2,ceil(.2N))，在首访真实评价及可信锚点更新后计算；并列全部按<=阈值纳入。未评价虚拟位置不赋予真实fitness，不增加目标调用，不引用未来结果。

## 固定配置与控制
reward固定最简单的global_binary +1/-1、gamma0、alpha.1、epsilon.1；选择它是为了匹配最终目标并删除旧即时nextState的未来回传解释，不把奖励开发未过门包装成成功。几何、Tracing、候选、Switch不同父代语义全部保持。
4个新条件：Q-quality（相对质量状态）；Q-phase（只阶段，二值位恒真）；Rule-quality（较优Continue否则Switch）；Rule-reverse-quality（反向）。旧Q-success（G1-g0）40格来自774b4f3奖励实验，默认状态等价必须回归通过。Batch/Random/Continue/Switch/B10等固定对照来自S0，同搜索与种群；缓存时长不作速度结论。

## 运行计划与确认门
开发：8函数F1/F3/F6/F9/F12/F13/F22/F30，D30/60000真实FE，seed901–905，4新条件×40=160run，4worker。这是开发数据，不是独立测试。
只允许Q-quality作为本假设主候选；若它在函数均值和逐seed两口径都同时严格胜Batch、Random、Rule-quality，再固定版本以seed1001–1010确认（8函数×10seed×6条件B10/Batch/Random/Rule-quality/Q-success/Q-quality=480run）。Q-phase与反向规则检验信息与Q必要性，不凭哪个最优就替换“质量状态有效”主张。未过门则不触发确认，不扩大组合扫描。

## 新接口
state.fcsState=success(default)/quality/phase；policy signal/reverse_signal用于按当前状态位的固定控制；原success/reverse仍按首访局部改善。新增StateSignalLog可选记录状态位与质量阈值，原DecisionLog和RewardLog不改。signal排序只使用真实已评价信息。
