# V1 mechanism ablation at 60k FE

This experiment tests X1: A-style Tracing保优 plus a stagnation-triggered dimension-wise historical-exemplar Seeking candidate.

- X1-StagnationExemplar: normal A-style search, with one Seeking candidate replaced after 10 real evaluations without improvement.
- The complete V1-Elite reference is retained in `cec2017_search_core_20261009_091923`.

All runs use D=30, population=50, 60,000 FE, Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery, and paired seeds 21:23 on F1, F3, F9, F12 and F22.

The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation for every run.

## Result

X1 does not pass the predefined development gate. Relative to the paired 60k A reference, X1 wins 5/15 runs and loses 10/15. Relative to 60k CLPSO, X1 wins 9/15 runs; the function-mean result is 3/5, with F9 and F22 still clearly worse.

The stagnation candidate was generated often but selected rarely by Global-Cap2. Its mean evaluation success rates were approximately 9.5% (F1), 1.6% (F3), 0.8% (F9), 8.0% (F12), and 0.4% (F22). Thus the current candidate does not provide the intended stagnation recovery, especially on F9 and F22. The experiment should be treated as a negative development result; no threshold or formula tuning is applied afterward.

`x1_comparison.csv` contains the paired comparison and diagnostic rates.

