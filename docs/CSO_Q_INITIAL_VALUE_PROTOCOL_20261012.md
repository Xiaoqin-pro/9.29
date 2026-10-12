# 纯配额Q统一初值单因素预试（2026-10-12）

## 精确行为诊断
原effQ40run/40000decision按原RandStream和更新顺序重放，actual actions与最后Q表/visits精确一致。epsilon探索9.94%，exploit同state重访switch63.81%，上次该state reward−1后的exploit switch75.73%，reward+1后2.90%。top两Q值gap<.1占72.19%，每run未访问optimistic选择仅~7次，故不能把全程轮换仅归零初值；稀疏±1反馈与value-gap也有关。

## 一项可手算改动
reward范围[−1,1]、gamma=.9，连续失败无限折扣回报下界−1/(1−.9)=−10。统一将六state三action全初始化−10，而非0；不按动作给不同prior、不指定6T4S。α=.1、γ=.9、ε=.1、phase×过去1000FE模式效率bit、三纯配额动作、100FE决策、原B10公式/半径均冻结。用于检验悲观而非乐观起点的学习稳定性；只有改善真实质量才有意义，减少switch本身不是优化成功。

## 开发范围
D50/100k八函数五原开发seed1801–1805，与efficiency440批InitSeed/SearchSeed严格同格。一个新候选40run/4MFE，原十一组440质量记录按实际源码指纹复用，明确不是独立新seed确认。四worker每worker单线程，先F1/F12×600FE两smoke。

初值0逐点Best/T/RNG/决策/Q表回归；fixed/random/规则的轨迹不得因未使用Q初值变化改变；−10表/terminal更新可逐步手工重放；flat reward−1与初值−10会按Bellman下界保持（终端除外），验证规则而非凭想象说有效。真实FE/state/history/mode/credit checks不变。

## 验收门
候选rank严格低于最佳统一fixed、Random、Phase、EpsFixed、effrule，各>=4/8函数均值不差、>=20/40seed不差、无双方>1e-8且mean>10倍退化。原effQ/previousQ/stallQ/reverseeff全体报告；若通过才冻结十新seed强控制确认。只试这个由回报范围推导的init，不扫−1/−5/−20等网格。若未过，说明初始化不足以补救，不把学得更偏固定6叫成功。开发重复不当新seed证据。

公开原choice replay40k、gap/visit/switch/真实exploration及全部run。变量改动不是执行bug修复；原实现ε-greedy和Q更新有效，原失败证据保留。
