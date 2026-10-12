# FCS修复假设台账

|ID|问题|决定|类别|来源|
|---|---|---|---|---|
|FCS-A01|这轮改多少|仅计数与奇数尾配额执行修复；状态、reward、超参不改|semantic|用户确认修FCS及既有规划|
|FCS-A02|Switch含义|保留不同父代，不偷换为未访问父代Open|semantic|原源码；默认保持|
|FCS-A03|比较谁|共同FCS内核7策略，B10只作外部质量参照|semantic|源码核对|
|FCS-A04|是否移除几何|本轮保留，后续单因素检查独立性|semantic|用户前文关注与修复隔离|
|FCS-A05|Qfallback/nextstate|先保留旧语义并显式记录，不宣传长期信用已正确|semantic|最小修复默认|
|FCS-A06|新增接口|state.auditDecisions控制完整日志；info增加执行与条件统计|interface|默认|
|FCS-A07|开发协议|8函数5seed60kFE+3函数1seed12k动作诊断，4worker|semantic|既有授权、本轮冻结|

- FCS-A08（semantic，用户）：最终论文方法保持简单、易消融、可讲清机制，风格参照老师；阶段性代码和结果上传已指定GitHub仓库。
