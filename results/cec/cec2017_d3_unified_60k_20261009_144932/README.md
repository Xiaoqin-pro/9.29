# Unified D3 confirmation at 60k FE

- Functions: all CEC2017 functions except F2 (29 functions).
- Dimension: D=30; population: 50; budget: 60,000 FE.
- Repeats: 41:45 with paired initial populations for all three algorithms.
- D3-Both: tracing inertia decay plus virtual tracing with real-position rollback.
- D1-TracingDecay: tracing inertia decay without virtual tracing.
- CLPSO and L-SHADE are external same-budget references. L-SHADE uses the current 50-member interface configuration; its standard population-size setting will be reviewed before formal 30-run experiments.
- D3 and D1 use Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery and no RL.
- The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation.
- This is a development confirmation screen; it is not the final 30-run formal experiment.

## Result summary

All 580 runs completed successfully. The per-function comparison is in `unified_comparison.csv`.

- D3-Both vs D1-TracingDecay: 15/29 function-mean wins; 86/145 paired-run wins.
- D3-Both vs CLPSO: 28/29 function-mean wins; 133/145 paired-run wins. The only function-mean loss is F17.
- D3-Both vs L-SHADE: 3/29 function-mean wins; 19/145 paired-run wins.
- Mean rank across the 29 functions: L-SHADE 1.21, D3 2.41, D1 2.59, CLPSO 3.79.

The D3 versus CLPSO result is a strong same-budget 60k development signal. The D3 versus D1 result does not meet the earlier 18/29 screening target, so the virtual-tracing contribution is not uniformly better than tracing decay alone. L-SHADE remains substantially stronger in this screen.

L-SHADE used the repository's current 50-member interface configuration. Its standard population-size protocol still needs to be reviewed before any formal paper comparison. These results use 60,000 FE and five seeds per function; they are not the final 300k or 30-run statistical experiment.

