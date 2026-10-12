# 持续停滞状态独立确认结果（2026-10-12）

640新优化完成：D50/100k、八函数×十新seed×八条件，64M预算内真实FE、640次Best重查、16smoke单列。全部独立MAT核验及Q重放通过；状态、奖励、搜索公式在确认内冻结。

stag1000相对旧BinaryQ函数5:3/seed40:40，相对固定4T6S函数5:3/45:35；但相对统一强Fixed6仅2:6/29:51，对Random3:5/44:36，对Phase5:3/40:40且平均rank更差。八条件rank：Fixed6=3.0、Random3.375、Phase4.0、stag1000=4.25、Fixed4=4.875、EpsFixed5.125、BinaryQ5.25、Fixed2=6.125。联合确认门未过，不能把开发过门当成功。

Holm比较内八函数校正，仅相对Fixed2有一个候选优势函数；对Fixed6/Phase/Random/旧Q未检出0.05显著函数，有限seed不等效。全部函数与seed、均值/标准差/中位数和校正p公开。原Q及不利结果未删。

真实群体与轨迹示例：F22后段div仍约初始.59但改善缓慢，不能统一归为塌缩；F1后段div约.0066而仍持续改善；F13的stag比Fixed6更收缩且长stall更多。真实多样性和停滞信号必须联合解释，而非“后期一定加大探索”。目前三Q动作都只改名额，Seeking扰动仍随1−progress缩至零，动作无法修复对应搜索尺度。

用户随后明确保持Q只控制评价配额。曾起草将半径恢复绑定action1的方案，现已撤回，预检退出，未执行任何smoke/正式半径优化。原640run保持原版。下一步先检查反馈能否告诉Q两模式的相对评价价值；半径若以后改变，应由所有控制共用，不改变动作定义。

公开results/cso_mode_q_state_confirm_20261012/：640raw、全部配对、逐函数统计、开发/确认并列、动作分布及真实div/stall所有八函数图。完整MAT/source_snapshot在results/cec/cso_mode_q_state_confirmation_study_20261012_150741/。已完成无残留该批MATLAB进程。
