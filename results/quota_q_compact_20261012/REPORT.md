# 有效3×2配额Q简化结果（2026-10-12）

160新run/16MFE，原320deletionquality cached不算新；160Best重查/8smoke单列。删正常state空行threequota精确等价，真正改变行为仅删2T8S action；Q只有phase3×twoaction，realstall detector与healthyFixed6保留一次。

十二条件rank：{'Compact-Eps6': 4.375, 'Gated-Q6-Bonus10': 4.875, 'Compact-Random': 5.0, 'Fixed6': 5.25, 'Phase': 5.375, 'Compact-Rule4': 6.5, 'Random': 6.625, 'Compact-Q': 6.875, 'Simple-Q6': 7.0, 'EpsFixed6': 8.0, 'Original-Q6-Bonus1': 8.625, 'Simple-Q3': 9.5}。
同两action强控制联合门：未通过。

- Compact-Q vs Compact-Eps6：函数2:6，seed18:22，误差比中位1.113，该控制门未通过。
- Compact-Q vs Compact-Random：函数2:6，seed15:25，误差比中位1.062，该控制门未通过。
- Compact-Q vs Compact-Rule4：函数3:5，seed21:19，误差比中位1.08，该控制门未通过。
- Compact-Q vs EpsFixed6：函数5:3，seed25:15，误差比中位0.9626，该控制门通过。
- Compact-Q vs Fixed6：函数4:4，seed15:25，误差比中位1.062，该控制门未通过。
- Compact-Q vs Gated-Q6-Bonus10：函数2:6，seed16:24，误差比中位1.071，该控制门未通过。
- Compact-Q vs Original-Q6-Bonus1：函数6:2，seed27:13，误差比中位0.9078，该控制门通过。
- Compact-Q vs Phase：函数3:5，seed21:19，误差比中位1.153，该控制门未通过。
- Compact-Q vs Random：函数4:4，seed21:19，误差比中位1.123，该控制门未通过。
- Compact-Q vs Simple-Q3：函数5:3，seed26:14，误差比中位0.8724，该控制门通过。
- Compact-Q vs Simple-Q6：函数5:3，seed22:18，误差比中位0.9515，该控制门通过。

Q only真实配额4T6S/6T4S，所有控制same2action/no search modifications。若门未过保留简洁候选不定版，不能只因容易画图就说学习有效。五seed同格开发非独立confirm/significant/noninferior，原弱/不利函数保留。
