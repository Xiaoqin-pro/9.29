# Fixed6-CSO与作者代码CLPSO：完整29函数100k结果（2026-10-12）

## 本轮完成
按用户请求：CEC2017 F1/F3–F30，D50，五新seed2201–2205，每次100000真实评价。CSO使用现有B10骨架固定6T4S/NP50，无Q；CLPSO使用刚取得并逐点核验的作者公开源码profileCEC适配/NP40。两方法共290新run、29M预算内真实FE、290Best重查单列；四smoke另列，四worker每worker单线程。全部已结束，无MATLAB实验进程。

运行前D50作者机械oracle24精确Best/T/RNG/外域skip见证，29函数有限值通过；原D30审计13源码oracle与10旧adapter回归已通过。全290MAT/CSV/真实FE/合法目标域/完整单调T/所有节点与共同初始40点前缀独立核验通过。D50官方60输入hash匹配，整个批次算法/协议未改。

## 结果（均值票数，非显著胜场）

|指标|CSO Fixed6|CLPSO作者profile|
|---|---:|---:|
|函数均值胜数|22|7|
|函数中位数胜数|22|7|
|145配对seed胜数|102|43|
|平均函数排名|1.241|1.759|
|平均时间秒/run|7.968|2.193|

20%FE节点均值胜27:2，到60%/80%/100%均为22:7。CSO早期误差下降更快，不能把100k结果推广到500k或声称CLPSO最终精度差。前D30诊断300k三函数各CLPSO版均胜B10，也说明预算依赖。

CLPSO均值胜的函数F6/F7/F10/F15/F17/F19/F29。F6 CSO约8.455、CLPSO.1521，CLPSO约55.6倍更低；F19 CSO26911、CLPSO7481。CSO强例F1误差约2008 vs1.9998e6、F12 5.402e6 vs2.918e7、F13 52758 vs291950、F14 68678 vs1.222e6。全部29均值/方差/中位/pair公开，不按成功例选结论。

五seed精确双侧符号秩最低p=.0625；29Holm检验无显著函数，这是样本分辨率所限，不能把22:7写成22个显著胜场，也不能把无显著说等效。此批是用户要求的完整集性能筛查，若用于正式论文按预先计划扩大独立重复数。

## 对先前CLPSO疑问的回答
旧CLPSO adapter确实有profile偏离（clip边界、初velocity和inertia等），不得继续以旧29:0大幅优势称忠实原版。换成作者codeprofile后，当前Fixed6在D50/100k仍22:7支持低预算精度优势，但CLPSO在7函数更好、CPU也更快，结论应收窄。

CLPSO作者public code与2006paper文本也有差异，见CLPSO_AUDIT_RESULTS：Pc/code exp5 vspaper exp10，gap5 vs7，代码失败累加与采样包含self等。该比较明确author-codeprofile，不称完全复现论文表。NP40由原D30论文population选择沿用到当前D50；它不是paper原D50规定。CSO N50，CLPSO N40，共同初始化池prefix，不假说population完全相同。

## 与论文主线的关系
这批证明基础CSO在该低预算配置有价值，不证明Q-learning创新有效；Fixed6没有Q。Q仍需在同骨架上超过Fixed6/其它强策略，不能只因Fixed6对CLPSO22胜就把功劳写给Q。CSO更高CPU开销也不支持“同FE更快”；资源效率要同质量FE/实测工程评价成本或明确跨预算补充。

## 交付
results/clpso_full_100k_20261012/：全部290raw、manifest、29×2mean/std/median summary、145paired、function_comparison精确p/Holm、overall、FE节点胜场、sourcehash/authorproof、preflight/independentartifact checks、四smoke、全29比值图/收敛曲线和runtime图。完整MAT/source_snapshot：results/cec/clpso_full_100k_study_20261012_193032/。

源码CLPSO_CEC_AuthorSource/ASE_CSO_ModeBudget、运行run_clpso_full_100k，分析analyze_clpso_full_100k/plot_clpso_full_100k。重复参数已先写CLPSO_FULL_100K_PROTOCOL，不按结果变baseline。旧CLPSO/sourceaudit数据保留。
