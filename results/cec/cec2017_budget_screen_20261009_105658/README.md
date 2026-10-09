# CEC2017 budget screen

- Functions: F1, F3, F9, F12, F22.
- Dimension: D=30; population: 50.
- Budgets: 60,000, 150,000, and 300,000 FE.
- Repeats: 21:23, paired initial populations.
- V1-Elite uses Global-Cap2, Range Seeking, MR=0.4, SMP=5, and no recovery/RL.
- V1-Elite is newly run at 60k and 150k. The 300k V1 reference is retained in the previous search-core experiment.
- CLPSO is run at all three budgets.
- Every run checks exact FE accounting; DSS checks the 2 Tracing + 3 Seeking allocation.

A shorter budget is an independent run: the Range step scale uses the run-specific progress value, so a 60k run is not treated as the first 60k evaluations of a 300k run.

## Preliminary result

The new runs give a clear efficiency/quality trade-off on these five diagnostic functions.

- At the same 60k FE, V1-Elite wins the function means 3/5 and the paired runs 12/15. Its mean time is 8.71 s versus 0.60 s for CLPSO.
- At the same 150k FE, V1-Elite again wins the function means 3/5 and the paired runs 11/15. Its mean time is 21.30 s versus 1.45 s for CLPSO.
- At the same 300k FE, using the existing paired V1-Elite reference, V1 wins 2/5 function means and 6/15 runs. Its mean time is 49.83 s versus 2.85 s for CLPSO.
- Against full-budget CLPSO, the 60k V1 run wins 2/5 function means and the 150k V1 run wins 1/5. Therefore the reduced-budget version should not be presented as a general replacement for a full-budget optimizer.

The 300k V1 rows are reused from `cec2017_search_core_20261009_091923`; all 60k and 150k rows and all CLPSO rows were generated in this experiment. The combined files make this source distinction explicit.

These results support using the budget screen as an efficiency study, not as evidence that fewer FE are universally better. The V1 search core still benefits from late evaluations on some functions, while its MATLAB candidate-screening overhead remains much larger than CLPSO's.

