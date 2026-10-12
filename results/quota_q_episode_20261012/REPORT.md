# 停滞Q动作保持500FE结果（2026-10-12）

200新run/20MFE，D50/100k八函数五原seed，原280quality缓存不重复计新；200Bestrecheck/10smoke单列。100FE兼容、holding duration/discount/actualstate/action/terminal与真实FE全部独立核验。

十二条件平均排名：{'500-gaterandom': 3.75, '100-gateeps6': 4.5, '100-gaterandom': 5.5, 'fixed6': 5.75, '500-gateeps6': 5.875, '500-gate4': 6.125, '500-gateq': 6.375, '100-gate4': 6.875, '100-gate2': 7.25, '500-gate2': 7.875, '100-gateq': 8.25, 'alwaysQ': 9.875}。
预写强对照联合门：未通过。

- 500FE-Q vs 100-gate2：函数5:3，seed22:18，误差比中位数0.9641，对照门通过。
- 500FE-Q vs 100-gate4：函数4:4，seed21:19，误差比中位数1.022，对照门通过。
- 500FE-Q vs 100-gateeps6：函数2:6，seed19:21，误差比中位数1.085，对照门未通过。
- 500FE-Q vs 100-gateq：函数6:2，seed25:15，误差比中位数0.9379，对照门通过。
- 500FE-Q vs 100-gaterandom：函数3:5，seed15:25，误差比中位数1.057，对照门未通过。
- 500FE-Q vs 500-gate2：函数6:2，seed23:17，误差比中位数0.8683，对照门通过。
- 500FE-Q vs 500-gate4：函数4:4，seed21:19，误差比中位数1.016，对照门未通过。
- 500FE-Q vs 500-gateeps6：函数4:4，seed21:19，误差比中位数1.022，对照门未通过。
- 500FE-Q vs 500-gaterandom：函数2:6，seed18:22，误差比中位数1.113，对照门未通过。
- 500FE-Q vs alwaysQ：函数7:1，seed25:15，误差比中位数0.8219，对照门通过。
- 500FE-Q vs fixed6：函数2:6，seed22:18，误差比中位数1.092，对照门未通过。

只改free attempt保持时长，bootstrap按实际FE的gamma^(duration/100)，healthyFixed6，reward±1和所有搜索公式不变。相同holding提供给Random/规则，不能把holding收益自动归Q。

同seed开发非独立确认，五seed票数非显著/非劣。过门才新seed完整集确认，未过不扫更多holding时长或同时改reward/state。
