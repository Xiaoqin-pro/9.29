# Hybrid Seeking candidate generation

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, 3 seeds, fixed MR=0.4, no Recovery, and DSS screening.

Each Seeking cat generates four candidates: two classic coordinate-multiplicative candidates and two range-normalized additive candidates. DSS still evaluates at most two candidates per selected cat.

## Mean error

| Function | Classic Seeking | Range Seeking | Hybrid 2C2R |
|---|---:|---:|---:|
| F03 | 11683.33 | 6928.88 | 10969.94 |
| F05 | 175.26 | 193.57 | 237.44 |
| F13 | 31320.85 | 35056.70 | 38988.31 |
| F15 | 19049.60 | 14135.84 | 608.17 |
| F19 | 13779.08 | 2364.51 | 741.13 |
| F30 | 18480.38 | 19873.41 | 10697.36 |

The hybrid improves the classic version on F03, F15, F19 and F30, but is worse on F05 and F13. Both candidate types receive real evaluations: across runs, classic candidates account for about 53%--54% of Seeking evaluations and range candidates about 46%--47%. This is a mechanism diagnostic, not a final formula selection; the frozen default remains classic Seeking until broader validation.
