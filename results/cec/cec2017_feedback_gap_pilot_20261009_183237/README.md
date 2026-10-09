# Feedback-gap pilot at 60k FE

- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.
- Repeats: 51:53; D=30; population=50; 60,000 FE.
- D3 search dynamics are unchanged: Range Seeking, tracing decay, virtual tracing and rollback.
- G3: standard Global-Cap2 (2 near-best + 1 far-center).
- G2Random: 1 near-best + 1 far-center + one random feedback candidate.
- G2Age: 1 near-best + 1 far-center + one candidate from the largest FE feedback age.
- G2Random and G2Age use the same candidate generation and parent-cap rule; only the compensation parent selection differs.
- The script checks exact FE accounting, 2 Tracing + 3 Seeking allocation and parent cap.
- A 6,000-FE logging audit passed with identical Best and T trajectories with logging disabled/enabled.
- Age threshold 50 FE is a fixed diagnostic bin (10 five-FE rounds), not a tuned decision threshold.


## Diagnostic conclusion

`feedback_comparison.csv` compares the three strategies on the same seed set.

- G3 vs G2Random: G3 wins 4/8 function means; paired final-error wins are 13 vs 11.
- G3 vs G2Age: G3 wins 6/8 function means; paired final-error wins are 16 vs 8.
- G2Random vs G2Age: random compensation wins 5/8 function means; paired final-error wins are 14 vs 10.
- Across all runs, the fixed old-feedback bin (age >= 50 FE) has lower Seeking success than the recent bin (age < 50 FE) for the three strategies on average.
- The pilot therefore does not support using feedback age as a compensation priority. Q-learning compensation was not implemented or trained after this negative gate.
