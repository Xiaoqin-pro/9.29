# Candidate-family DSS ablation

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, new seeds 7--9, fixed MR=0.4, no Recovery, 4 MATLAB workers. All variants use the same DSS screening and paired initial/search seeds.

| Variant | Candidate policy |
|---|---|
| `DSS-Classic` | four classic candidates |
| `DSS-Range` | four range-normalized candidates |
| `DSS-Hybrid` | two classic + two range candidates |
| `DSS-RandomFamily` | random choice among the three pools each round |
| `DSS-QFamily` | 27-state Q-learning chooses the pool |
| `DSS-QFamily9State` | 9-state Q-learning without candidate-performance state |

## Mean error

| Function | Classic | Range | Hybrid | RandomFamily | QFamily | QFamily9State |
|---|---:|---:|---:|---:|---:|---:|
| F03 | 7358.88 | 10972.34 | 3627.10 | 6190.34 | 10546.85 | 11858.69 |
| F05 | 294.08 | 198.54 | 206.99 | 216.65 | 166.47 | 204.89 |
| F13 | 33919.42 | 14811.40 | 21652.21 | 50188.47 | 25946.91 | 19664.31 |
| F15 | 7488.20 | 7527.15 | 11748.80 | 451.21 | 496.62 | 899.39 |
| F19 | 11707.53 | 12769.26 | 1628.63 | 2160.86 | 4246.57 | 2356.82 |
| F30 | 73549.50 | 23046.81 | 18614.46 | 18670.25 | 43228.62 | 25672.18 |

QFamily is better than fixed Range on 4/6 functions, but better than fixed Hybrid on only 2/6 and better than RandomFamily on 2/6. QFamily and QFamily9State are tied 3/3 by function means. The action diagnostics show nearly identical 27-state and 9-state behavior: about 27.5% exploration and action shares near 0.32/0.33/0.36. This development run does not establish an additional Q-learning gain over fixed candidate pools.

The result supports keeping DSS as the main mechanism. Candidate-family Q scheduling remains a documented diagnostic result unless a separately justified reward redesign is tested; no reward or Q parameter was changed in this experiment.
