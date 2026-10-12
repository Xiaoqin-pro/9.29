# 两路线独立配对开发结果（2026-10-12）

520新run完成，D50/100k，八函数五新seed，52M真实预算内FE；520额外Best重查、A18/B8smoke单列。两路线共用InitSeed/SearchSeed，搜索轨迹可随方法分化。真实FE/状态/奖励/Q replay/半径与scale触发独立核验通过。

整体13条件平均排名：{'Rule-reset': 4.875, 'Random-reset': 5.5, 'Adapt-epsfixed': 5.625, 'Old-Q': 5.875, 'EpsFixed-reset': 6.25, 'Q-reset': 6.625, 'Adapt-fixed6': 6.875, 'Old-fixed6': 7.125, 'Adapt-phase': 7.25, 'Adapt-Q': 7.625, 'Adapt-random': 7.625, 'Adapt-fixed2': 9.75, 'Adapt-fixed4': 10.0}。

- 路线A：Adapt-Q，强控制开发门未通过，rank=7.625。
- 路线B：Q-reset，强控制开发门未通过，rank=6.625。

依预写门选定路线：无；统一适配中最强固定：Adapt-fixed6。

A中Q仅配额，半径公式所有控制相同；B中action1在停滞时同时触发恢复，不能把两路线混称同一机制。若简单规则更强，不能宣称Q必要。五seed不是显著/非劣结论，全部条件公开。

过门后可冻结一条做独立新seed确认；都未过则报告不确定和失败，不马上扩半径网格或加Tracing。原算法/Old-Q结果完整保留。
