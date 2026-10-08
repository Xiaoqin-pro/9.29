# Hybrid+DSS mode-scheduling comparison

Protocol: F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, new seeds 4--6, 4 MATLAB workers. All variants use the same Hybrid 2-classic + 2-range Seeking pool, DSS screening, mode-preserving five-evaluation rounds, and no Recovery.

| Variant | Action policy |
|---|---|
| `Hybrid-DSS-Q` | 27-state Q-learning, MR = 0.2/0.4/0.6 |
| `Hybrid-DSS-Random` | uniform random MR action |
| `Hybrid-DSS-FixedMR04` | fixed MR = 0.4 |
| `Hybrid-DSS-EpsFixed` | fixed greedy MR = 0.4 with the existing epsilon exploration rule |

## Mean error

| Function | Q | Random | Fixed 0.4 | EpsFixed |
|---|---:|---:|---:|---:|
| F03 | 12802.19 | 16162.16 | 2806.07 | 13616.63 |
| F05 | 171.96 | 186.37 | 182.66 | 167.67 |
| F13 | 24845.23 | 46350.84 | 24230.71 | 34137.42 |
| F15 | 1987.10 | 5309.08 | 430.70 | 3682.84 |
| F19 | 6179.20 | 2407.18 | 5307.66 | 3165.68 |
| F30 | 31794.41 | 23661.74 | 21780.45 | 8390.35 |

Q is better than Random on 4 of 6 function means, but better than fixed MR=0.4 on only F5. Across all 18 paired runs, this does not yet support a stable Q-learning gain over the simple fixed policy. The experiment is a new-seed development diagnostic; no Q parameters or rewards were changed.
