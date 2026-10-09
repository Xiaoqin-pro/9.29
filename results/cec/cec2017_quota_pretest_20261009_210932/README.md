# Fixed Seeking/Tracing evaluation-quota pretest at 60k FE

- Functions: F1, F10, F14, F16, F19, F22, F24 and F27.
- Repeats: 91:93; D=30; population=50; 60,000 FE.
- All runs use D3 dynamics, Global-Cap2, Range Seeking, MR=0.4, SMP=5, no Recovery and no RL.
- Fixed-T1S4: 1 Tracing + 4 Seeking evaluations per round.
- Fixed-T2S3: 2 Tracing + 3 Seeking evaluations per round.
- Fixed-T3S2: 3 Tracing + 2 Seeking evaluations per round.
- The only changed quantity is the fixed real-evaluation quota; total FE remains 60,000.
- The script checks exact FE accounting, per-round quota and parent cap.

## Pretest summary

`quota_comparison.csv` compares the three fixed quotas.

- Best mean quota by function: 1T+4S on 2/8 functions, 2T+3S on 3/8, and 3T+2S on 3/8.
- Mean ranks: 2T+3S = 1.75, 1T+4S = 2.00, 3T+2S = 2.25.
- Against fixed 2T+3S, paired wins/losses are 13/11 for 1T+4S and 12/12 for 3T+2S.
- The fixed-quota differences are useful for diagnosis but do not yet justify a feedback controller or Q-learning.

