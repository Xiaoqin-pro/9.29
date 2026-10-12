# 正常固定6、停滞才介入Q的开发结果（2026-10-12）

200新run/20M真实FE，D50/100k八函数五原完整集seed。80Fixed6/alwaysQ同格质量缓存、200Bestrecheck和10smoke单列。默认原版回归及forced/free/真实state/action/reward/nextstate/terminal重放通过，80cachedp0实际一致。

七条件平均排名：{'gateeps6': 2.75, 'gaterandom': 3.25, 'fixed6': 3.375, 'gate2': 4.0, 'gate4': 4.25, 'gateq': 4.625, 'alwaysQ': 5.75}。
预写全部强控制联合门：未通过。

- gateQ vs fixed6：函数3:5，seed15:25，误差比中位数1.16，该控制门未通过。
- gateQ vs alwaysQ：函数7:1，seed23:17，误差比中位数0.75，该控制门通过。
- gateQ vs gaterandom：函数3:5，seed16:24，误差比中位数1.099，该控制门未通过。
- gateQ vs gate2：函数4:4，seed22:18，误差比中位数1.022，该控制门未通过。
- gateQ vs gate4：函数2:6，seed16:24，误差比中位数1.036，该控制门未通过。
- gateQ vs gateeps6：函数0:8，seed16:24，误差比中位数1.127，该控制门未通过。

Q表/奖励/动作/搜索方程不变，只将learning触发集中于真实停滞，healthy强制Fixed6。固定fallback是已开发先验，若random/rule同样好，不能把gate作用当学习贡献。

五seed开发非显著/非劣，未按失败改变门或删除函数。过门才新seed完整29确认；未过不扫stallthreshold或增加机制。
