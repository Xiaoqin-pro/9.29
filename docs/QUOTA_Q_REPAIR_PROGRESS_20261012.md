# 配额Q继续修正：时长、奖励、计数更新（2026-10-12）

## 已完成与范围
本轮用户授权修好当前Q，不承诺通过参数修改保证成功。三组有界单因素开发：free保持500FE五控制200新run（20M真实FE）、同100/500窗口真改善reward+10两candidate80（8M）、短窗+10下按访问计数学习率40（4M）。合计320新run、32M预算内FE，320Best重查与10+4+2=16smoke另列；已有同格质量缓存不重复算新seed。D50/100k八函数原seed2201–2205，属于开发不是独立确认。

初始episode预检终端discount未记补日志，bonus初次语法分隔错误均在正式run前修正。129 episode100精确旧轨迹回归/131cases/7logneutral、bonus60默认/60cases、visitrate25默认/25cases通过；全三批独立MAT/actualwindows/gate/state/reward/nextstate/terminal/折扣/实际访问学习率逐更新重放通过。当前无运行任务。

## 诊断与因果边界
原gate40run14944停滞trial，当前100FE改善6.27%，后续含其它action的500FE改善26.42%，93.4%后续窗口换action；不能给原action追加后续其它action信用。持有500FE是单因素检验整个区间为同action，而非改写旧reward。

500FE保持版对原alwaysQ函数7:1/seed25:15，对100gateQ6:2/25:15，但对同500Random2:6/18:22，Fixed6仅2:6/22:18；保持本身有局部开发改善，未说明学习有效。reward+10（真gain才奖，失败−1）短窗对Fixed6=5:3/20:20、alwaysQ6:2/27:13；仍败同Random/Eps，长窗+10更差。不扫倍率。

## 最新保留候选（不是成功冻结）
B10骨架、SMP5、MR.4、Searching/Tracing方程及半径不变。正常(stall<1000FE)保持Fixed6；停滞才纯quotaQ，100FE决策、phase3×stallbit6×3表、reward真gbest改善+10否则−1、gamma.9/epsilon.1、zero init。学习率仅由state-action真实eligible更新次数α=1/(1+visits)，phase分组不跨stage混平均。Healthyforced动作不训练Q；fallback不训练；terminal无bootstrap；adaptive rate虽降低采样噪声也可能加重非平稳oldsamplebias，需实证，不理论保证。

|最新visitrateQ相对控制|函数均值胜/负|seed胜/负|
|---|---:|---:|
|原全程Q|6/2|25/15|
|上一版100gateQ|7/1|27/13|
|同窗+10 fixedalpha Q|4/4|17/21（2平）|
|强Fixed6|4/4|24/16|
|同100gateRandom|4/4|24/16|
|同100gateFixed2|6/2|20/20|
|同100gateFixed4|5/3|24/16|
|同100gateEpsFixed6|3/5|21/19|
|同500gateRandom|6/2|20/20，但整体rank更差|

十五条件平均rank最新6.25，原alwaysQ12.125/100gateQ10.375/Fixed6=7.375/100Random6.625；更强500Random5.0、100EpsFixed5.5仍在前。相对Fixed6函数误差比中位.947、几何1.029，部分大退化不能用seed胜掩盖。相对原Q中位.633、几何.798，说明当前修正比原版有积极开发信号。联合预写强门仍未过，不将本批称修好Q，也不按结果降门。

## 下一步
保留这版作为有希望的开发候选、原全29Q和Fixed6强控制不删；不覆盖正式入口、不继续本轮window/threshold/reward/alpha网格。若下一次推进，优先原样完整29同格补漏或独立newseed同gateEps/Random/Fixed6/旧Q确认，分别报告学习增益与触发规则增益，不仅和CLPSO对比。当前五seed八函数数据不推广到完整集，更不能按函数定制reward/threshold。

重要：全局改变触发机制与reward/rate叠加的最终候选不代表三个模块各自已构成SCI创新；论文主贡献仍真实评价资源的学习调度，额外规则是实现安排。需要严格同机制规则对照证明Q超出少量探索本身，当前缺口仍存在。

## 交付
results/quota_q_episode_20261012/、quota_q_episode_bonus_20261012/、quota_q_visit_rate_20261012/分别保存新raw/全缓存quality、完整比较/规则门/源hash/检查、actualdurationweighted share/真实curve及最新修正progress图。完整MAT各results/cec对应目录。所有失败版本保留，cached记录Origin清楚；不凭GitHub未推状态说已上传。


## 最终完整检查补注（覆盖上文候选优先级）
VisitRate在F30两seed退化，mean为Fixed6约4.06倍；Smooth首α.1的40run又未过强门，F30仍有失败seed。本轮合计360new/36MFE、18smoke，最终保留较稳Bonus10-100固定α.1为开发候选，visit/smooth不定版。它仍未通过同Random/Eps强门，不能说Q已修好。详见QUOTA_Q_REPAIR_FINAL_20261012.md。
