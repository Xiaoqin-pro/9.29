# 小Q纯配额版vsCLPSO同规模完整CEC（2026-10-12）

D50/100k、F1/F3–F30、五相同seed2201–2205。新增145次Q运行/14.5M真实FE；此前CLPSO和Fixed6各145run缓存复用，三条件435质量记录，不重复算新run。完整真实T/Q/state/reward/terminal及290个cachedp0前缀匹配通过。

平均函数rank：{'CSO-Fixed6': 1.6896551724137931, 'CSO-QuotaQ-Stall1000': 1.8275862068965518, 'CLPSO-AuthorSource40': 2.4827586206896552}。

- Q vs CLPSO-AuthorSource40：函数均值21:8，seed96:49，中位数函数胜21:8；平均秒8.775:2.193。
- Q vs CSO-Fixed6：函数均值13:16，seed59:86，中位数函数胜12:17；平均秒8.775:7.968。

五seed精确双侧最小p=.0625，29Holm没有0.05显著函数；均值胜场不改写显著。CLPSO为作者公开codeprofileCEC适配/NP40（与2006paper文字参数不同），Q/Fixed6 NP50，shared初始化池prefix而非相同群体。

Q原样phase3×真实持续1000FE停滞bit6×3表、100FE块、±1奖励、alpha.1/gamma.9/eps.1，原B10搜索方程/半径完全不变。对CLPSO优势不直接证明Q增益，必须与同骨架Fixed6分别解读。

缓存时间来自前一批，新Q带div/state日志有开销，微小秒差不能单归学习。所有29函数和五seed完整报告，未据结果替换Q版本、调参或增seed。本批非全预算/其它维度/发表验收。
