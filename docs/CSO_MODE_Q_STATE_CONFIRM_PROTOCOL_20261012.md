# 持续停滞1000FE小Q独立确认协议（2026-10-12）

## 选择来源与禁止混合
80同格状态开发中stag1000通过预写四强对照门，stag500未通过；全11条件排名stag1000=4.0，原BinaryQ=4.625。stag1000对Fixed6/Phase/EpsFixed/Random函数5:3/5:3/5:3/7:1，seed22:18/20:20/21:19/23:17。该选择仅开发，不证明正式性能。奖励仍原binary±1，alpha.1/gamma.9/eps.1、100FE决策、B10/SMP5及六状态三动作均不再修改。只phase3×真实gbest持续1000FE未改善bit。

## 独立批
D50/100k、八函数F1/F3/F6/F9/F12/F13/F22/F30、十新seed1501–1510，InitSeed=21201012+fid*10000+seed，SearchSeed+1M。八条件Fixed2/4/6、Random、Phase、EpsFixed、原BinaryQ、stag1000，新run640（64M真实FE），全部重新运行，不复用旧seed控制。四worker单线程，先F1/F12×八条件600FE共16smoke。源快照、完整MAT、TrendLog/RewardLog/StateLog/决策/Q更新、初始群体、环境全保存；额外Best重查单列。

原previous-state分支必须逐点复现旧ModeQ，固定策略不受状态定义影响。已完成59默认等价/168行为检查，源未改变时不重复广泛测试；同框架smoke保证并行配置和所有条件正确，独立Python从T重算stallFE并重放全部Q表。不能把原previous的初始noSuccess与新stag的健康标志混成同一标签。

## 先写确认选择
对Fixed6/Random/Phase/EpsFixed：平均函数排名严格更低、各>=4/8函数均值不差、各>=40/80配对seed不差，无双方>1e-8时均值>10倍退化；全满足才进入全29函数与标准预算/维度验证。原BinaryQ额外完整报告，用于解释状态替换效应，不删除其优势函数。平均排名、质量门和显著性分别报告。

逐函数精确条件符号秩（零差剔除，ties中秩，双侧符号翻转），每个比较的八函数Holm；跨四强对照另可对32检验Holm补充。十seed不能证明非劣，未显著不等效。所有函数和seed、不利结果公开；不按确认结果加seed、调整阈值或只取有利函数。开发与确认并列，不能合并当独立样本。

确认若通过，研究主张仅限低预算阶段与持续停滞反馈的评价资源分配；前期保护真实div、后期摆脱停滞要由TrendLog和真实gbest曲线支持，不写绝对逃出保证。若未过，报告边界并停止扩大当前网格；不会加新搜索算子救本批。
