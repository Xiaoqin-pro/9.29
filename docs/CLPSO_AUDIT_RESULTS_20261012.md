# CLPSO实现审计结论（2026-10-12）

## 结论
旧CLPSO_CEC逐维综合学习实现不是明显索引/计数错误，但不是作者精确版：边界clip并实评不同于论文skip越界移动；初速度/惯性/速度限幅等是本仓库适配选择。作者公开代码与原论文在Pc/gap/stay计数等也不同，需分别标注。旧“远超CLPSO”只能针对旧adapter，不应推广作者代码或完整论文。

作者包第一手source P-N-Suganthan/CODES，2006-IEEE-TEC-CLPSO.zip，commit6336e45c7a3c06ed52fb2268d34fbef79eaa29d0，SHA256 e79250ea6a9fc18a5976e19906f58ea6b8418352aa5a173087ee28a4e29f11a9。original paper pdf随包保存，视觉核对Eq10、综合学习、refresh7、boundary和原D30NP40/200k。旧作者源码原样保存在work，不覆盖它来称作者新版本。

## 对齐表
|项|旧仓库适配|论文/公开代码|判断|
|---|---|---|---|
|速度公式|逐维pbest exemplar，c1.49445，无gbest项|论文Eq5相同|基本符合|
|Pc|.05+.45 exp10|论文相同；作者代码0+.5 exp5|旧符合论文，不符合code|
|刷新|连续7次未改善，改善reset|论文gap7；code gap5且累计失败直到refresh|原paper合规，code不同|
|示范采样|排除自己、两个不同对手|论文文字排除自己；code有放回含自己|旧符合文字，code不同|
|强制外学|全self时选一维他人|论文文字相同；code强制dimension但donor仍可能self|旧基本符合|
|边界|clip且立即FE|论文与code越界不FE、pop继续移动|明确偏离|
|初速度|范围1%|公开code20%，paper未完整给此值|项目选择，不说忠实作者|
|惯性/cap|.9→.4按realFE/15%|code .9→.2按nominalgeneration/20%|适配差异|
|真实FE|每点含初始化计数|本轮独立核对零漏计|执行计数正常|

几批旧comparison的CLPSO源normalized哈希均1beef61d50ffa8bcfd05efbd06b65c7e63e8ab39fab501430357e192c52f5d41，确认同adapter，未混版本。旧detailed_summary有F1 valid_n=590而其raw实际10/组，这是历史汇总异常，本轮不使用该summary排名；当前20261012重跑raw29×10完整独立，不因旧汇总异常撤销所有新raw。

## 108小诊断
D30 F1/F6/F13、3新seed、60k/300k、B10/Legacy/PaperBoundary/Init20/AuthorSource50/AuthorSource40六组108run，19.44M真实FE，108Bestrecheck/6smoke单列。旧adapter10逐点回归，作者机械oracle13精确points/T/Best/RNG对，31行为case通过；全108MAT独立核验通过。

60k作者sourceNP50对旧adapter函数3:0/seed9:0，NP40亦3:0/9:0；作者code改善不是单独大初速度：Init20两个预算均0:3，对旧版更差；只换论文边界两档2:1/5:4，部分变化但解释不了作者profile整体提升。

B10对旧adapter60k函数2:1/seed8:1，对source50=2:1/6:3，对source40=2:1/5:4；在300k所有CLPSO版本对B10均3:0/9:0。作者source40均值F1约3.97、F6约1.52e−13、F13约411，B10约3902/.258/16487。低预算收敛与足额性能有明确差异，本批3func/3seed不作完整泛化。

作者adapter通过mechanicaloriginaloracle（只seed/p0/cap/T/guard接口变化）但CEC2017与2006原函数不同，不说已复现论文表。source所有参数一起变化，不能把整体改进单归边界或Pc。正式外部选择不因让CSO输赢选：用户下一轮固定作者profileNP40，CLPSO与CSO各自群体设置明确。

## 当前主比较
用户授权F1/F3–F30、5新seed、D50/100k，CSO最可信诊断版本固定6T4S/NP50 vs作者源码CLPSO/NP40，总290run。协议CLPSO_FULL_100K_PROTOCOL_20261012.md先写，初始化共享50点池prefix，不假称相同种群。whole-suite结果单独分析，不把旧adapter弱分数混入新CLPSO。

公开108诊断results/clpso_audit_20261012/：raw/summary/comparison/paired/behavior/sourceproof/independent核验。download原zip/pdf/oracle源在work/clpso_audit_20261012/。旧代码和结果不删除，后续论文引用要准确标注profile与FE预算。
