# 配额Q反馈时长修正结果（2026-10-12）

## 新修正与验证
用户授权继续修当前小Q。原gate40run共14944停滞尝试观测：100FE正改善6.27%，后续累计500FE正改善26.42%，93.4%窗口换action；后续包含其他action，未给原action虚构credit。改为free窗口固定一个action500FE，healthy仍100FE/Fixed6；搜索/MR/state/三quota/reward±1不变，bootstrap按实际duration的.9^(FE/100)。

200newrun/20M预算内FE、八函数五原seed2201–2205，200Bestrecheck/10smoke另列；280旧质量记录cached，不算新seed证据。129 episode100精确旧trajectory/Q/RNG对、131时长/terminal/gatecase、7日志中性通过；全200独立MAT、actualduration/state/action/reward/discount/Q replay/FE核验通过。最初预检终端discount日志缺失补齐，不改terminalbootstrap0，正式run从成功预检后开始。

## 结果
500-gateQ相对100-gateQ函数6:2/seed25:15，相对alwaysQ7:1/25:15；对Fixed6函数2:6/seed22:18，方向混合；对同500Random2:6/18:22，对500EpsFixed4:4/21:19但rank更差，对500Fixed4也是4:4/21:19但rank更差。全部强控制门未过，不能说已修好。

12条件rank最低500Random3.75，100EpsFixed4.5；Fixed6=5.75，500Q6.375，100Q8.25，alwaysQ9.875。保持时长确有回收旧Q损失的信号，但同机会随机更强，学习未稳定正确分配。保持更久也使Qfree介入真实FE占比变化，必须FE权重分析而非decision counts误解为大量固定6。

## 后续有限检验
只再检查真改善+10/失败−1的奖励倍率，100/500两既有设置各单因素、80newrun，原控制cached不算新。导师稿件有+10值，但不是借它就保证效果；所有search/state/radius/alpha/gamma/epsilon不变。若未过不扩奖励网格，完整记录失败与新结果。

本轮候选保留，不覆盖原全29Q版，完整seed开发非独立确认，不降低strongcontrol门。公开results/quota_q_episode_20261012/全newraw/cachequality/pairs/gate/真实durationweighted份额/原delay诊断/图；MAT/source snapshot results/cec/quota_q_episode_study_20261012_210153/。
