# 统一Q初值单因素结果（2026-10-12）

40新优化完成，D50/100k、八函数×五原开发seed；4M真实FE、40Best重查与两smoke单列。原十一组440控制缓存质量同格复用，不算新增独立证据。仅Q初值统一从0到−10，其余公式/状态/动作/reward/alpha/gamma/epsilon未改。

十二条件平均排名：{'epsfixed': 3.5, 'fixed6': 4.5, 'effrule': 4.625, 'effQ': 5.875, 'stallQ': 5.875, 'phase': 6.125, 'previousQ': 6.875, 'LowerInit-effQ': 7.0, 'fixed4': 7.375, 'random': 8.0, 'fixed2': 8.875, 'reverseeff': 9.375}。
预写五强对照门：未通过。

- LowerInit对effQ：函数4:4，seed18:22，误差比中位数0.9849，对照门未通过。
- LowerInit对effrule：函数3:5，seed16:24，误差比中位数1.172，对照门未通过。
- LowerInit对epsfixed：函数2:6，seed13:27，误差比中位数1.467，对照门未通过。
- LowerInit对fixed2：函数6:2，seed30:10，误差比中位数0.5854，对照门通过。
- LowerInit对fixed4：函数4:4，seed24:16，误差比中位数0.9158，对照门通过。
- LowerInit对fixed6：函数1:7，seed13:27，误差比中位数1.188，对照门未通过。
- LowerInit对phase：函数3:5，seed19:21，误差比中位数1.1，对照门未通过。
- LowerInit对previousQ：函数4:4，seed19:21，误差比中位数1.009，对照门未通过。
- LowerInit对random：函数3:5，seed20:20，误差比中位数1.017，对照门未通过。
- LowerInit对reverseeff：函数7:1，seed25:15，误差比中位数0.6911，对照门通过。
- LowerInit对stallQ：函数3:5，seed18:22，误差比中位数1.062，对照门未通过。

原40Q日志40000决策精确RNG重放：exploration~9.94%，greedy状态重访换动作~63.8%，上次负reward后~75.7%；零未访optimistic每run仅~7次，不能把全部轮换归零初始化。减少换动作不是成功标准，真实质量与同信号规则必须比较。

未过门不扫更多init，过门才独立新seed確認；全部不利条件公开，五seed开发不是显著/非劣或论文最终结论。
