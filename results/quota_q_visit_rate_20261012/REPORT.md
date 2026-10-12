# 停滞Q按访问次数学习率结果（2026-10-12）

40新run/4MFE，原560质量cached不算新；40Best重查与2smoke单列。仅同Bonus10-100 setting的α由.1改为1/eligibleVisits，Qstate/table/action/reward/bone不变。

十五条件rank：{'500-gaterandom': 5.0, '100-gateeps6': 5.5, 'VisitRate-Bonus10-100': 6.25, '100-gaterandom': 6.625, 'Bonus10-100': 6.75, 'fixed6': 7.375, '500-gate4': 7.375, '500-gateeps6': 7.375, '500-gateq': 8.25, '100-gate4': 8.5, '100-gate2': 9.0, '500-gate2': 9.5, 'Bonus10-500': 10.0, '100-gateq': 10.375, 'alwaysQ': 12.125}。
预写联合强控制门：未通过。

所有actual RateLog按eligible visits独立重算并重放Q/terminal，默认fixedbranch逐点回归。门未过本轮停止，不继续reward/window/radius网格；报告修正局部收益但不称Q已修好。五seed是same-seed开发，非significance/noninferiority。
