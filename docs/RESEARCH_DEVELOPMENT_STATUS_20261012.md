# 当前创新开发状态（2026-10-12）

用户方向：论文机制简单、易消融、效果接近导师目标；允许reward与参数开发；CEC2017主平台，UAV最后验证。不能仅故事漂亮就认定机制有效。

## 已执行并上传
|阶段|新增优化run|结果状态|提交|
|---|---:|---|---|
|FCS实际计数+尾预算修复|341|行为通过，原Q无稳定强基线收益|931e52a/2efb00c|
|reward/gamma有限开发|280|八条件无一过Batch+Random确认门|774b4f3/3eeabfb|
|首访质量状态位|160|不胜Batch/Random，没有确认|aa31f12|
|单保留FE控制|320|Q1-g0胜Random/Progress，但不胜Keep|afe67e3|
合计1101新增正式开发/诊断run（不计管线smoke及行为小例）；缓存对照不重复算新run。结果按阶段results/fcs_*_20261012/公开，main分批push成功。没有仍在运行的实验，也没有偷偷执行未过门候选确认。

## 方法复杂度
现在最小候选只是每轮4T6S中的最后1Seeking名额，Keep原batch或Explore未覆盖父代；6状态2动作，小Q表。Keep与强Batch逐点等价，政策随机流独立。Q1-g0即时global±1信用无需长期MDP解释；其对随机开发胜场不足以证明Q必要性，因为Keep更强。

## 关键效果边界
单名额Q1-g0：8函数5seed，对Random函数7:1/seed24:16，对Keep3:5/20:20。每run5995决策仅约3.65次即时global正奖励。仍未到论文主贡献验收；不能再用奖励倍率网格粉饰这一缺口。首访质量替换无稳定优势，先保留否定性证据。

## 下一项最小问题
先判断该有限Explore动作是否存在可重复的后续搜索收益，再设计一个合理的可观测信用信号；不增加搜索算子、不不断扩状态、不仅因提高reward数值而宣称学习有效。如果StrongKeep持续胜出，重新选择更适合学习的稀疏评价决策，而非强行将当前Q包装成论文创新。


## 用户重新收敛后的优先项
用户补充允许采用已有改进CSO；下一项优先捡起SMP3删候选与固定MR下的模式真实FE配额，暂停FCS进一步扩大。具体方法、旧quota与MR-Q证据、新骨架检查及三块验证见 docs/CSO_SIMPLIFICATION_PLAN_20261012.md；本次只做离线统计与规划，没有新增优化run。


## D50骨架删减已完成（按用户预算修订）
新增144开发run（另六smoke），100k/500k，43.2M真实预算内FE；86原B10等价、240行为和144独立MAT核验通过。SMP3函数均值5:3/6:2，seed11:13/13:11，配对时间少33.0%/33.6%；100k配对门未过，两预算未定版，但保留独立确认候选。删除Seeking精英偏移2:6/1:7，保留该项。原B10仍为锚点；没有仍在运行的实验。正式定位D50=100k/500k、D100=200k/1M，12k非主证据。详见docs/CEC2017_BUDGET_PLAN_20261012.md、CSO_SIMPLIFY_RESULTS_20261012.md及公开results/cso_simplify_20261012/。


## SMP3独立确认与固定配额继续
D50/100k十新seed共160run完成，16M真实FE。SMP3函数2:6/seed34:46，时间中位少30.3%，未过质量门，仍用B10骨架；八函数Holm双方无显著，非等效证明。公开results/cso_smp3_confirm_20261012/。下一阶段无Q固定MR，只比较2T8S/4T6S/6T4S（D50/100k八函数五新seed共120run），协议CSO_MODE_QUOTA_PROTOCOL_20261012.md。


## 固定配额完成，单小Q开发启动
固定配额120run/12MFE：统一最佳6T4S（均值排名1.5），4T6S2.0、2T8S2.5；最优函数5/2/1，八函数节点最优改变，满足动作可调性预试门。已写单Q协议：100FE块、6×3表、global±1、alpha.1/gamma.9/eps.1，Fixed2/4/6、Random、Phase、EpsFixed、Q七组×八函数×五新seed=280run；测试111等价/238行为/7日志中性及14smoke通过，当前实验运行中。


## 本次继续执行已全部结束
三阶段560新run、56MFE完成（160 SMP3确认+120固定配额+280小Q），24smoke单列；全部独立轨迹核验通过，Q表可逐更新重放。SMP3质量未过，保留B10；固定6T4S暂最佳统一控制；小Q均值平均排名3.25最优、胜B10和Random，但对Fixed6函数4:4/seed19:21、EpsFixed函数3:5/seed22:18，强对照联合门未过。不扩大参数网格、未运行全29函数正式确认。没有仍在运行的优化任务。详见docs/CSO_MODE_Q_RESULTS_20261012.md及results/cso_mode_q_20261012/。


## 用户授权保持此版小Q后继续
32同seed中性div/停滞回放与原轨迹完全等价（3.2M诊断FE不算独立效果）；80奖励单因素均未过，保持binary。80持续停滞state实验中1000FE标记过四强控制开发门、500未过；仍6×3表、三配额、原搜索公式。已冻结1000并独立十新seed八条件确认640run（D50/100k），当前运行中，不宣称成功。结果与协议分别docs/CSO_MODE_Q_TREND_RESULTS、STATE_RESULTS、STATE_CONFIRM_PROTOCOL_20261012.md。


## 当前状态覆盖上文（纯配额Q主线）
640持续停滞Q独立确认已结束，联合强控制门未过；全部证据results/cso_mode_q_state_confirm_20261012/公开。用户明确Q只控制评价配额，绑定半径action的草案撤回，预检退出且未执行smoke或正式半径优化；runner禁止自动启动。后续半径只可所有对照共享的骨架改进。下一项优先检查真实模式相对收益反馈与配额决策，保持小表/纯动作，不运行未写新协议的批次。当前无MATLAB实验进程。详见docs/CSO_QUOTA_Q_ANCHOR_20261012.md。


## 用户授权比较两路线
用户保留Q配额主故事，同时允许比较原action1绑定半径候选。CSO_TWO_ROUTES_PROTOCOL_20261012.md已先写：A所有策略统一Seeking阶段幅度+后段真实停滞恢复，Q纯名额；B仅停滞且Seeking多动作恢复，Q/规则/随机同机会。同新seed1701–1705共520run（A360/B160），预检A59等价/63行为/flat238恢复轮、B59等价/171行为/flat9恢复块通过，A18/B8smoke通过，当前四worker运行。前次withdrawn runner不自动复用，新B入口独立授权。


## 两路线520run已完成
A360/B160共52MFE，26smoke单列；全artifact/cross40p0/22源码检查通过，无运行任务。A统一半径适配Q相对A-fixed6函数3:5/seed18:22，B动作绑定恢复Q相对同Rule2:6/19:21、同Random2:6/14:26，两路线均未过Q必要性门。B比A好但不是Q成功；保留原纯配额Q/B10锚点，搜索改进暂不定版。公开results/cso_two_routes_20261012/及docs/CSO_TWO_ROUTES_RESULTS_20261012.md。GitHub曾DNS失败，保存本地提交后再推。


## 纯配额相对模式效率状态开发启动
原random日志离线观察local常偏Seeking但随后Fixed6常更好，global模式增益反馈ties多。仅替换一个state bit=过去1000FE实际Trace gbset gain/FE > Seek gain/FE；搜索公式、半径、reward和6×3表不变。十一组含旧Q/stallQ/全部固定/Random/Phase/EpsFixed/同反馈直接和反向规则，五新seed1801–1805，440新run；230旧策略精确回归、66历史反馈case及22smoke通过。当前四worker运行，协议CSO_MODE_EFFICIENCY_PROTOCOL_20261012.md先写。
