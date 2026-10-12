# 持续停滞配额Q vsCLPSO：同规模完整CEC结果（2026-10-12）

## 完成与可比性
用户要求带Q版本同规模对CLPSO。预先选择原B10骨架持续1000FE停滞state小Q，不根据新结果换版本。D50/100k、F1/F3–F30、相同seed2201–2205，NP50；新增145run/14.5M真实调用、145Bestrecheck、两smoke单列。旧CLPSO作者profileNP40与Fixed6各145run缓存同格，三条件共435质量记录，不算新增435。

Q源normalizedhash与640独立确认版一致；cachedCSO/CLPSO/objective/D50input五source checks通过。每份T/Best/真实modeFE/state/reward/terminal Q/回退mask独立检查通过，Q与145Fixed6实际p0全相同，与145CLPSO初始40前缀相同，共290prefix matches。四worker/单线程完成，当前无运行任务。

## 主结果

|比较|Q函数均值胜/负|Q配对seed胜/负|Q函数中位胜/负|
|---|---:|---:|---:|
|作者codeprofile CLPSO NP40|21/8|96/49|21/8|
|同骨架无Q Fixed6|13/16|59/86|12/17|

三方函数均值rank：Fixed6=1.690、Q=1.828、CLPSO=2.483。Q对CLPSO函数误差比中位数.811，几何均值.662；对Fixed6中位1.043、几何1.101。固定版上批22:7/102:43，Q本批21:8/96:49，两者都低预算胜CLPSO多数函数，但Q未增整体精度。

CLPSO均值胜Q的F6/F7/F10/F15/F17/F19/F26/F29。Q相对Fixed6更好的13函数F3/F8/F14/F16/F17/F18/F19/F20/F23/F24/F25/F27/F28；F27差距仅约0.05，不能把微小均值差吹成稳定胜。Q在F1/F6/F11/F12/F15/F22/F26/F30等退化影响不能藏。

20%FE对CLPSO函数27:2，到60%/80%22:7，终点21:8；对Fixed6则15:14、8:21、10:19、终点13:16。某些后段收益不是统一占优，更不能说Q保证跳出局部最优。

## 学习和时间边界
Q仍纯名额3action，6×3表，phase3×真实1000FEstall，100FE决策、binary±1、alpha.1/gamma.9/eps.1、zero init；原Seeking半径/Tracing/筛选/接受不变。Q平均三个动作占比30.46%/33.50%/36.04%，1000块约173.3正奖励。它没有广泛集中到强Fixed6，存在函数依赖收益但不证明整体必要。

平均时间Q8.775秒、Fixed6上批7.968秒、CLPSO上批2.193秒。cached控制时间在前一时段，且Q源带div/state诊断，不能把微小Q/Fixed6秒差严格归学习开销，但Q对CLPSO不是更快。真实工程昂贵目标或同质量FE效率要另做证据。

five seed精确双侧符号秩最小p=.0625，两个比较各29Holm无显著；21:8/13:16不是显著胜负，未显著不等效。NP40vs50是保留算法population选择、真实FE相同sharedprefix，不假说population相同。CLPSO公开codeprofile与2006paper文本参数不同，已明确adapter身份，不冒称paper table严格复现。

## 对论文的含义
可以说该小Q版保留了稀疏改进CSO对作者profileCLPSO的大部分低预算精度优势；不能说新增Q导致优于CLPSO，因为Fixed6也有更好优势。若当前冻结，Q应是尚未验证整体必要性的候选/补充，并保留Fixed6消融强控制。正式主张仍需新seed/多预算/维度确认，不能删Fixed6来做漂亮消融。

## 交付
results/quota_q_full_100k_20261012/：145newraw、435all_quality、29×3summary、两个比较290paired、function_comparison/p/Holm、overall/actualaction、cachehash/p0checks、fullQ核验、sourcehash、两smoke、全29误差比/三方convergence/actionshare图。完整Q MAT/source_snapshot results/cec/quota_q_full_100k_study_20261012_194957/；cached前290run原目录和hash完整记录。
