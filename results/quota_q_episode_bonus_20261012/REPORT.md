# 停滞Q真实改善奖励倍率单因素结果（2026-10-12）

80新run/8MFE，原480duration/control质量缓存不算新；80Bestrecheck、四smoke单列。只将两种原窗口设置各自reward+1改+10（失败−1），其余方法和window不同时改变。

十四条件rank：{'500-gaterandom': 4.25, '100-gateeps6': 5.125, '100-gaterandom': 6.125, 'Bonus10-100': 6.25, '500-gateeps6': 6.75, 'fixed6': 6.875, '500-gate4': 7.0, '500-gateq': 7.625, '100-gate4': 7.875, '100-gate2': 8.25, '500-gate2': 8.75, 'Bonus10-500': 9.25, '100-gateq': 9.5, 'alwaysQ': 11.375}。

- Bonus10-100强对照门：未通过，rank6.250。
- Bonus10-500强对照门：未通过，rank9.250。

100/500两个候选各对应自己固定窗口全控制；不是先从两candidate择优再同一弱control比。五seed同格development非独立证据，不用倍率变化当成功。未过不扫更多奖励倍率，所有不利结果公开。
