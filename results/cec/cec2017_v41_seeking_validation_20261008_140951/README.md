# Broader Seeking validation

This is a pre-specified validation on the 23 CEC2017 functions not used in the recent Seeking and DSS design decisions: F01, F04, F06--F12, F14, F16--F18, F20--F29. Protocol: D=30, population=50, 300000 FE, 3 paired seeds, fixed MR=0.4, no Recovery, and the same DSS screening for both variants.

- `DSS-ClassicSeeking`: traditional coordinate-multiplicative candidates.
- `DSS-Hybrid2C2R`: two classic and two range-normalized candidates per Seeking cat.

## Function mean comparison

| Function | Classic | Hybrid |
|---|---:|---:|
| F01 | 50632597.30 | 121867.74 |
| F04 | 94.08 | 85.91 |
| F06 | 56.45 | 58.98 |
| F07 | 537.64 | 508.91 |
| F08 | 216.74 | 155.43 |
| F09 | 7994.70 | 4807.61 |
| F10 | 4443.92 | 3676.63 |
| F11 | 334.53 | 132.28 |
| F12 | 3345501.15 | 1068756.90 |
| F14 | 21136.76 | 14004.45 |
| F16 | 963.41 | 936.92 |
| F17 | 212.10 | 331.55 |
| F18 | 198675.51 | 288918.75 |
| F20 | 625.80 | 600.20 |
| F21 | 369.43 | 344.12 |
| F22 | 4696.18 | 4209.93 |
| F23 | 535.19 | 559.45 |
| F24 | 642.88 | 634.03 |
| F25 | 420.26 | 389.02 |
| F26 | 3739.38 | 2307.03 |
| F27 | 537.87 | 565.68 |
| F28 | 452.24 | 431.56 |
| F29 | 1176.41 | 932.02 |

Hybrid wins on 18 of 23 function means and has 45 paired-seed wins versus 24 losses across 69 runs. It is not uniformly better: F17, F18, F23 and F27 favor Classic, and runtime is higher (about 46.7 s versus 39.2 s per run on average). This is broader validation evidence, not the final CEC2017 benchmark.
