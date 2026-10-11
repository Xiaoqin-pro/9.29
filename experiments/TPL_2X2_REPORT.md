# TPL 2x2 causal pilot report

本报告拆分两个机制因素：提案是否跨轮复用，以及候选集合是否使用边际覆盖。

## 协议

- 8 个函数：F3、F6、F9、F12、F13、F22、F28、F30
- 5 个配对 seed：201–205；D=30；N=50；60,000 FE
- 参考组：B10-Reference；TPL 四个 2×2 组合
- 200/200 次运行有效，FE 与收敛检查通过。

## 版本说明

- `TPL-NoReuse-NoMarginal`：每轮重新生成候选，不使用集合边际覆盖。
- `TPL-Reuse-NoMarginal`：跨轮复用候选，不使用集合边际覆盖。
- `TPL-NoReuse-Marginal`：每轮重新生成候选，使用边际覆盖。
- `TPL-Reuse-Marginal`：跨轮复用候选，并使用边际覆盖。

## 函数均值

Method    B10-Reference  TPL-NoReuse-Marginal  TPL-NoReuse-NoMarginal  TPL-Reuse-Marginal  TPL-Reuse-NoMarginal
Function                                                                                                       
F03        9.102489e+03          13653.870375            12880.591705        1.301901e+04          1.328016e+04
F06        2.731567e+00              0.905193                1.211154        8.732425e-01          7.553757e-01
F09        3.755999e+01              3.113073                3.809171        1.564289e+00          8.265345e+00
F12        1.075148e+06         868546.266127           975435.382715        1.051391e+06          1.008884e+06
F13        2.810653e+04          26175.665857            38256.339724        7.809692e+04          9.452709e+04
F22        5.893463e+02            100.377958              100.337769        1.009036e+02          1.004834e+03
F28        4.214186e+02            429.230677              416.776199        4.157531e+02          4.341296e+02
F30        9.870147e+04         256765.636446           306168.979767        1.047405e+05          1.717770e+05

## 逐 seed 配对胜负

- `B10-Reference` vs `TPL-NoReuse-Marginal`：21:19，平局 0
- `B10-Reference` vs `TPL-NoReuse-NoMarginal`：22:18，平局 0
- `B10-Reference` vs `TPL-Reuse-Marginal`：21:19，平局 0
- `B10-Reference` vs `TPL-Reuse-NoMarginal`：24:16，平局 0
- `TPL-NoReuse-Marginal` vs `TPL-NoReuse-NoMarginal`：22:18，平局 0
- `TPL-NoReuse-Marginal` vs `TPL-Reuse-Marginal`：22:18，平局 0
- `TPL-NoReuse-Marginal` vs `TPL-Reuse-NoMarginal`：23:17，平局 0
- `TPL-NoReuse-NoMarginal` vs `TPL-Reuse-Marginal`：21:19，平局 0
- `TPL-NoReuse-NoMarginal` vs `TPL-Reuse-NoMarginal`：18:22，平局 0
- `TPL-Reuse-Marginal` vs `TPL-Reuse-NoMarginal`：21:19，平局 0

## 结论

1. `TPL-NoReuse-Marginal` 的总体均值低于 B10，并在 8 个函数中有 5 个函数均值更低，但逐 seed 仅为 21:19，属于有方向性的开发信号，不是稳定胜利。
2. 提案跨轮复用没有带来稳定收益；在本轮中，`NoReuse-Marginal` 明显优于 `Reuse-Marginal` 的逐 seed 比较为 22:18。
3. 不使用边际覆盖时，两个版本都没有形成优势，说明当前最值得保留的是候选集合层面的边际覆盖，而不是持久化提案。
4. 这组结果还不足以宣称几何覆盖选择是普适创新；下一步应先做更简单、可解释的固定覆盖机制验证，不再叠加 Q。