# FCS首访相对质量状态结果（2026-10-12）

## 结论
160新运行与全部执行审计有效，但Q-quality未通过确认门。保持6状态、2动作，只换质量信息位没有稳定超过Batch或Random。没有执行预备的480确认run，不把质量位写成已获支持的创新。

## 对照
D30/60000FE，8函数、seed901–905；4新条件（Q-quality/Q-phase/Rule-quality/反向质量规则）各40run。reward固定受控follow-up的global±1，gamma0，alpha/epsilon.1。Q-success来自上轮G1-g0的40格，固定策略来自S0。等价复用经19组严格回归验证。缓存时间不作速度结论。

|Q-quality对照|函数均值胜负|逐seed胜负|
|---|---:|---:|
|Batch|2:6|20:20|
|Random|3:5|17:23|
|匹配固定质量规则|5:3|22:18|
|原成功位Q|4:4|19:21|
|B10参考|4:4|17:23|
Q-success对去反馈Q-phase为函数8:0、seed29:11，提示原首访成功信息有作用；质量替换未提供稳定额外收益。开发重复数据不能作独立问题泛化证据，5seed不支持强显著性主张。

## 行为与接口
relativeQuality以首访实际cost和当前真实fitness前20%阈值比较，包含并列；不产生额外目标调用。80原reward/行为相关检查继续通过，36新状态归属配置、5手算fixture和19默认/固定控制精确回归通过。代码附有quality/phase Q只用gamma0的契约，未把不对应下一实际状态的bootstrapping宣传为长期MDP。

## 下一步收窄
当前每轮可调整3个后续名额，强静态batch尚是可靠参考。下一轮只让Q控制最后1个Seeking名额：保留原batch最后候选，或探索前缀尚未覆盖的父代。先验证固定保留动作与Batch逐点等价，再比较固定探索/随机/反馈规则/Q；正文机制进一步收窄，而非继续扩参数和状态。

## 证据
results/fcs_state_20261012含完整160新raw、480条合并质量记录、全部函数表、三强控制门与source manifest。完整MAT在本地results/cec/fcs_state_study_20261012_113217/runs/。所有不利结果保留。
