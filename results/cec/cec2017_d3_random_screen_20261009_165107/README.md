# D3 random opportunity screen at 60k FE

- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.
- Repeats: 41:45; D=30; population=50; 60,000 FE.
- D3 search dynamics are unchanged: tracing decay plus virtual tracing with rollback.
- Only Seeking candidate selection changes from Global-Cap2 to random sampling with the same 2-candidate parent cap.
- The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation.


## Paired comparison with D3

`random_screen_comparison.csv` compares the same initialization/search seeds against `D3-Both` from `cec2017_d3_unified_60k_20261009_144932`.

- D3 and random same-budget selection use 60,000 FE, 2 Tracing + 3 Seeking evaluations per round, and a maximum of two evaluated candidates per parent.
- D3 wins the function mean on 4/8 functions; random selection wins 4/8.
- Paired final-error wins across 40 runs are D3 21, random 19, ties 0.
- The result does not support attributing all D3 gains to the parent-cap alone. It provides a balanced control for the spatial candidate-screening claim.
- The random selector consumes its own selection randomness, so this is a stochastic same-budget control rather than a bitwise trajectory reproduction.
