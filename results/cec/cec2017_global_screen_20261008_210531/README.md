# DSS versus global Seeking-candidate screening

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, new paired seeds 10--12, pure Range Seeking, fixed MR=0.4, no Recovery, and 4 MATLAB workers. Each round has exactly 2 Tracing and 3 Seeking evaluations.

All three variants use the same round-start gbest and population center and the same near-best/far-center rule. The 3 Seeking slots are allocated as two near-best candidates and one far-center candidate, with duplicate candidates removed and the quota filled.

- `DSS`: first selects Seeking parents, then selects at most two candidates per selected parent.
- `Global`: all Seeking candidates compete globally; no additional parent cap.
- `Global-Cap2`: all Seeking candidates compete globally, with at most two evaluated candidates per parent.

## Mean final error

| Function | DSS | Global | Global-Cap2 |
|---|---:|---:|---:|
| F03 | 5854.80 | 13.61 | 13.85 |
| F05 | 197.06 | 133.53 | 133.53 |
| F13 | 20546.63 | 9851.49 | 5278.30 |
| F15 | 7264.08 | 6802.09 | 6802.09 |
| F19 | 14720.58 | 6424.03 | 3666.60 |
| F30 | 13018.24 | 23894.37 | 17438.13 |

Global is better than DSS on 5/6 function means; DSS is better only on F30. Global-Cap2 is better than DSS on 5/6 and improves over unconstrained Global on F13, F19 and F30. Global and Global-Cap2 are identical on F05 and F15 in this development batch.

## Parent-allocation diagnostics

| Variant | Mean distinct Seeking parents | Mean concentration H | Max parent evaluations |
|---|---:|---:|---:|
| DSS | 2.00 | 0.556 | 2 |
| Global | 2.02 | 0.552 | 3 |
| Global-Cap2 | 2.02 | 0.552 | 2 |

The global selectors usually involve two parents, so the cap is rarely active in this batch. Their performance advantage therefore cannot be explained only by preventing extreme 3-on-1 concentration. The result directly challenges the current parent-first restriction and should be treated as a decision experiment, not as evidence that DSS is universally inferior.

Convergence checkpoints at 30%, 60% and 100% FE, paired raw runs, parent coverage, concentration, success rates and global-improvement counts are included in the CSV files.
