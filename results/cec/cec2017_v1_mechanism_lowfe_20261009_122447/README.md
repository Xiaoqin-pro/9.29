# V1 mechanism ablation at 60k FE

This experiment separates the two changes included in V1-Elite:

- V1-A-TracingOnly: original gbest-based search, with Tracing accepting only an improvement over the parent.
- V1-B-EliteOnly: historical-elite guidance, with the original unconditional Tracing acceptance.
- The complete V1-Elite reference is retained in `cec2017_search_core_20261009_091923`.

All runs use D=30, population=50, 60,000 FE, Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery, and paired seeds 21:23 on F1, F3, F9, F12 and F22.

The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation for every run.

## Preliminary result

At 60,000 FE the strategy preference remains function-dependent. V1-A has the lower mean error on F1, F3 and F12; V1-B is better on F9 and F22. The paired A/B result is 10/15 versus 5/15, with A winning all three runs on F1, F3 and F12, and B winning all three runs on F9.

Against the newly run 60k CLPSO reference, both variants win 3/5 function means. The paired results are A: 9/15 wins and B: 11/15 wins. This is a low-budget development signal, not a final CEC conclusion.

Compared with the existing complete V1-Elite 60k rows, A wins 8/15 paired runs and loses 7; B wins 4 and loses 11. Thus the unconditional combination is not the best low-budget choice on this diagnostic set. A and B should remain separate candidates before any adaptive switching is introduced.

