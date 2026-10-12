# 单保留名额台账

|ID|决定|类别|依据|
|---|---|---|---|
|V01|只控制最后1Seeking FE，Keep精确复现强Batch|semantic|前几轮Batch稳定较强；用户要求简单|
|V02|未覆盖父代均匀抽样、原提案池、排除原末行|semantic|新增探索机会但不新增搜索算子|
|V03|6状态=阶段×前缀global进展，末FE独立reward|semantic|真实反馈与最终目标对齐|
|V04|实际下一决策pending更新、masked max、terminal0|semantic|避免错误信用/未执行动作|
|V05|独立policy随机流固定offset2000003|semantic|隔离策略随机抽样与搜索候选序列|
|V06|8条件新320格+缓存80，三控制门再独立seed|semantic|先开发再确认，全结果保留|
|V07|新入口ASE_CSO_ReservedEval，6策略与alpha/gamma/bonus|interface|保持历史实现与数据|
