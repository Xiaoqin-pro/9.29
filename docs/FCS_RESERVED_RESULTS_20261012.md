# 单保留评价名额开发结果（2026-10-12）

## 目标与本轮结论
把反馈控制进一步收窄为每轮最后1个Seeking FE，两动作Keep/Explore，小6状态Q表，不加搜索算子。固定Keep逐点嵌入较强Batch；其他随机政策使用独立流。
新增320run全部有效，但四Q候选均未同时超过Keep/Random/Progress的预定门槛，没有触发560独立seed确认。当前只能支持Q相对随机/固定探索有开发信号，不能支持Q相对强静态分配的必要性。

## 质量结果
D30/60000FE，8函数、seed901–905；4固定控制+4Q各40run，复用Batch=Keep和B10共80格，400条质量记录全部公开。
最简单Q1-g0（最后FE global改善+1，否则-1，gamma0）：
|对照|函数均值胜负|逐seed胜负|
|---|---:|---:|
|Keep（原Batch）|3:5|20:20|
|Explore|7:1|25:15|
|Random|7:1|24:16|
|Progress（前缀进展则Keep否则Explore）|7:1|25:15|
|Reverse|7:1|26:14|
|B10外部质量参考|5:3|18:22|
平均函数rank（10条件）Keep3.5，Q1-g0 3.75，其余Q4.375–5.25，Random6.75。均值胜场非显著胜场，5seed/8函数是开发不是定稿实验，缓存时间不作新旧速度主张。

## 行为验证
40组Keep与Batch的实际目标位置/Best/T/global RNG精确等价；351行为配置、9诊断开关中性重放及masked/terminal手算通过。不同策略global搜索随机流一致，策略选择不通过多抽随机数改变提案生成。实际下一决策s'信用与终止0bootstrap可逐条重放。
新320run独立FE=19200000，域/Best/T/网格与初始种群40组hash核对通过。父代最多2，所有执行动作合法。完整轨迹、Q表和policy seed存MAT。

## 奖励稀疏性的事实
每run5995个末名额决策，Q1-g0平均只有3.65次即时global改善；真实动作约47.5%探索，Random约50%。这说明当前即时奖励大部分为失败且Q仍混合两动作；不证明探索无长期价值，也不证明所有Q分配都无效。给稀少事件提高正奖励至10、加入gamma.9都没有过强基线门，不能靠更大倍率宣布学习有效。

## 当前停止与后续边界
本轮不再扩奖励倍率/学习率/折扣网格。应先核对“该类探索动作是否有可重复的后续收益”和“决策反馈是否足够”，再设计最多一个小机制；保留两动作和小Q表，不拼入复杂算子。若收益只来自既有几何batch，就不能把Q模块写成主贡献。未来奖励若用跨轮收益，须有真实动作归属/机会成本对照，不能把无关Tracing整体进步套到探索动作。

## GitHub与复现
source_manifest记录实际执行和LF归一源码指纹；public results/fcs_reserved_20261012含全部新raw、400合并质量记录、选择门、行为验收及解释。完整MAT在本地results/cec/fcs_reserved_study_20261012_121438/runs/。
代码入口src/ASE_CSO_ReservedEval.m，实验experiments/run_fcs_reserved_study.m，分析experiments/analyze_fcs_reserved_study.py。源协议docs/FCS_RESERVED_STUDY_PROTOCOL_20261012.md先于运行保存。固定Keep严格等价使缓存来源清楚；没有删除不利配置。
