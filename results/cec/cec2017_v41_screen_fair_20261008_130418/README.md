# V4.1 fair screening ablation

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, 3 seeds, 4 MATLAB workers.
All variants use the same initial population, search seed, fixed MR=0.4, no Recovery, and the same per-round budget of 5 real evaluations.

The ablation differs only in how the five opportunities are selected:

- `NoScreen`: random cats and random two Seeking candidates.
- `SS-CSO`: space screening at the cat level; two Seeking candidates are random.
- `DSS-CSO`: cat-level screening plus near-best/far-center candidate screening.

## Mean error

| Function | NoScreen | SS-CSO | DSS-CSO |
|---|---:|---:|---:|
| F03 | 86561.29 | 15276.87 | 11683.33 |
| F05 | 306.59 | 222.66 | 175.26 |
| F13 | 211576661.29 | 46284.93 | 31320.85 |
| F15 | 28686273.98 | 463904.68 | 19049.60 |
| F19 | 110214625.74 | 127569.77 | 13779.08 |
| F30 | 43685548.28 | 99533.96 | 18480.38 |

DSS-CSO improves over SS-CSO on 5 of 6 functions and is better than NoScreen on all 6. The experiment is now a fair screening comparison: every run uses exactly 300000 evaluations, the average budget fill rate is 1, and the mode allocation error is 0.

The single-layer baseline is deliberately random at the candidate level so the second-layer gain is not mixed with a larger candidate-evaluation quota. Results are development evidence from three seeds, not final CEC2017 claims.
