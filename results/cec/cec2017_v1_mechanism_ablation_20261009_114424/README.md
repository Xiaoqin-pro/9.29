# V1 mechanism ablation

This experiment separates the two changes included in V1-Elite:

- V1-A-TracingOnly: original gbest-based search, with Tracing accepting only an improvement over the parent.
- V1-B-EliteOnly: historical-elite guidance, with the original unconditional Tracing acceptance.
- The complete V1-Elite reference is retained in `cec2017_search_core_20261009_091923`.

All runs use D=30, population=50, 300,000 FE, Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery, and paired seeds 21:23 on F1, F3, F9, F12 and F22.

The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation for every run.

## Preliminary result

The two V1 components are complementary rather than uniformly dominant. Across the five diagnostic functions, V1-A is better on F3 and F12, while V1-B is better on F1, F9 and F22. The complete V1 reference is not uniformly best either: it is better than V1-A on F1, F9 and F22, and better than V1-B on F3 and F12.

This means the current evidence supports keeping both mechanisms in the V1 search core, but it does not support claiming that either component alone explains the improvement. The function-level comparison is recorded in `mechanism_comparison.csv`; the V0 and complete V1 rows come from the paired `cec2017_search_core_20261009_091923` reference runs.

The experiment also confirms that the two component variants are materially different: V1-A is faster (about 42.8 s on average) than V1-B (about 50.7 s), while their quality strengths depend on the function. No new Recovery or Q-learning module was introduced.

