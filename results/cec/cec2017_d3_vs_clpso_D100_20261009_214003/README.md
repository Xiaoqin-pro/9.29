# D3 versus CLPSO at D100, 60k FE

- Functions: F1, F3-F30 (29 functions); dimension: 100; population: 50.
- Budget: 60,000 FE including initialization; this is 6% of 10000D, a restricted-budget stress test.
- Repeats: 101:103; identical paired initial populations and search seeds.
- D3 is unchanged: elite guidance, Range Seeking, Global-Cap2, MR=0.4, SMP=5, tracing decay and virtual tracing with real-position rollback.
- D3 real evaluation allocation is fixed at 2 Tracing + 3 Seeking per round; parent cap is 2; RL and Recovery are disabled.
- Four workers; batches of four; CSV checkpoints are written after each batch.
- Official D100 data are from P-N-Suganthan/CEC2017-BoundContrained; source and hashes are in data/cec2017/D100_sources.md and D100_manifest.csv.
- Before optimization, all 29 MEX calls are checked for finite values and correct cost at their shifted optimum.
- Each run checks exact FE, finite nonincreasing convergence, and shared initialization. D3 also checks fixed quotas, budget fill and parent cap.
- This is a three-seed dimension-transfer pretest, not a formal 30-run statistical validation.

## Result summary

- D3 is better on 28/29 function means.
- Paired final-error results are D3 84 wins, CLPSO 3 wins and 0 ties across 87 paired runs.
- The only function where CLPSO has the lower D3-versus-CLPSO mean is F6.
- D3 uses substantially more wall-clock time than CLPSO in this inexpensive CEC setting; this pretest makes no runtime-superiority claim.
- F9's shifted-point diagnostic has a nonzero residual in the official MEX/data combination; the call is finite and the residual is recorded in `function_call_check.csv` rather than silently treated as an exact optimum.

