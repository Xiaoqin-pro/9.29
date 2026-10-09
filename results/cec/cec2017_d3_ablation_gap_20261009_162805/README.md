# D3 2x2 ablation completion at 60k FE

- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.
- Dimension: D=30; population: 50; budget: 60,000 FE.
- Repeats: 41:45 with paired initial populations.
- V1-Reference and D2-VirtualTracing are the two missing cells; D1 and D3 are reused from the unified 60k validation.
- All runs use Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery and no RL.
- The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation.

## Result summary

The 80 missing cells completed successfully. `ablation_2x2_comparison.csv` merges these rows with the previously completed D1 and D3 runs using the same seeds.

- D3 beats D1 on 3/8 function means and 21/40 paired runs in this deliberately mixed diagnostic set.
- D2 alone is unstable and is not a useful standalone strategy.
- The log-scale interaction
  `I = [log10(1+D3)-log10(1+D1)] - [log10(1+D2)-log10(1+V1)]`
  is negative on all 8 functions. This indicates that enabling decay changes the effect of virtual tracing in a consistently favorable interaction direction on this diagnostic set, even when D3 is not the best absolute method on every function.

This is mechanism evidence, not a generalization claim: the functions were selected because earlier runs showed both D3-favorable and D1-favorable behavior. The full 29-function result still shows that virtual tracing has function-dependent value.

