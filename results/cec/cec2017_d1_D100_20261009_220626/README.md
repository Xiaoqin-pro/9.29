# D1 versus D3 at D100, 60k FE

- D1 is D3 with virtual tracing disabled; tracing decay, elite guidance, Range Seeking, Global-Cap2, MR=0.4, SMP=5 and all FE controls are unchanged.
- Functions: F1, F3-F30 (29 functions); dimension: 100; population: 50; budget: 60,000 FE.
- Repeats: 101:103. Initial populations and search seeds are regenerated identically to the D3-vs-CLPSO experiment.
- `comparison.csv` pairs the new D1 runs with the existing D3 runs from `cec2017_d3_vs_clpso_D100_20261009_214003`.
- This is a mechanism ablation, not a new parameter search.

## Result summary

- D3 versus D1 mean-error wins: 15/29 functions for D3 and 14/29 for D1.
- Paired final-error results: D3 41 wins, D1 46 wins, 0 ties across 87 runs.
- The D100 result therefore does not support a stable independent benefit from virtual tracing over tracing decay alone.
- D3 remains the stronger external comparison candidate against CLPSO, but the virtual-tracing contribution must be described as conditional rather than universal.

