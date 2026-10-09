# D3 extension validation at 60k FE

- Functions: F4, F5, F7, F8, F11, F13, F14, F16, F17, F18, F20, F21, F23, F24, F25, F27, F28, F29 and F30.
- Dimension: D=30; population: 50; budget: 60,000 FE.
- Repeats: 31:33 with paired initial populations for all four algorithms.
- V1-Reference: tracing decay off and virtual tracing off.
- D1-TracingDecay: tracing inertia decreases from 0.9 to 0.4.
- D3-Both: D1 plus virtual tracing with real-position rollback after rejected evaluations.
- CLPSO is the external same-budget reference.
- All DSS variants use Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery and no RL.
- The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation.

## Result summary

All 228 runs completed successfully. The per-function comparison is in `extension_comparison.csv`.

- D3-Both vs V1-Reference: 16/19 function-mean wins; 41/57 paired-run wins.
- D3-Both vs D1-TracingDecay: 15/19 function-mean wins; 36/57 paired-run wins.
- D3-Both vs CLPSO: 19/19 function-mean wins; 52/57 paired-run wins.
- Mean rank across the 19 functions: D3 1.37, D1 2.21, V1 2.79, CLPSO 3.63.

The result passes the predeclared development screen for continuing D3 validation. It is not a final CEC2017 claim: all runs use 60,000 FE, each function has three seeds, and these are development functions held out from the six-function D3 diagnostic but not a formal independent test set. The formal entry point remains unchanged.

