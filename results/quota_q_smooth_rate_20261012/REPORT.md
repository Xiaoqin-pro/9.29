# 停滞Q保守首更新计数学习率结果（2026-10-12）

40新run/4MFE，原600质量cached不算新；40Best重查与2smoke单列。仅同Bonus10-100 setting的α由固定.1改为.1/(1+.1*eligibleVisits)，Qstate/table/action/reward/bone不变。

十六条件rank：{'500-gaterandom': 5.125, '100-gateeps6': 5.75, 'VisitRate-Bonus10-100': 6.625, '100-gaterandom': 7.0, 'Bonus10-100': 7.0, 'fixed6': 7.75, '500-gate4': 7.75, '500-gateeps6': 8.0, '500-gateq': 8.75, '100-gate4': 9.0, 'SmoothRate-Bonus10-100': 9.375, '100-gate2': 9.5, '500-gate2': 10.0, 'Bonus10-500': 10.625, '100-gateq': 10.875, 'alwaysQ': 12.875}。
预写联合强控制门：未通过。

所有actual RateLog按eligible visits独立重算并重放Q/terminal，默认fixedbranch逐点回归。门未过本轮停止，不继续reward/window/radius网格；报告修正局部收益但不称Q已修好。五seed是same-seed开发，非significance/noninferiority。
