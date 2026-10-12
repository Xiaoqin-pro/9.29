# FCS状态开发台账

|ID|决定|类别|依据|
|---|---|---|---|
|S01|保持6状态，仅把局部成功位换为首访候选质量位|semantic|实测局部/global脱节；用户要求简单|
|S02|首访candidate实际cost对当前真实fitness前20%阈值，并列纳入|semantic|已有eliteCount，不新加阈值参数|
|S03|global±1/gamma0/.1alpha/.1eps固定|semantic|最简目标对齐，避免旧nextstate未来假设|
|S04|quality Q、phase-only Q、quality固定及反向共4新条件|semantic|机制/学习必要性控制|
|S05|只Q-quality按三强控制门槛触发10新seed确认|semantic|先记录判据，不事后替换主张|
|S06|fcsState、signal policy、StateSignalLog新增|interface|保持老默认路径兼容|
