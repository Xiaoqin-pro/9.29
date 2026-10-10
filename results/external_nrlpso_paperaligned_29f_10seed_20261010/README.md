# Corrected NRLPSO paper-aligned reproduction

This directory contains a corrected, independent MATLAB reproduction of the supplied NRLPSO method for the local CEC2017 restricted-budget comparison.

## Protocol

- CEC2017: F1 and F3-F30 (29 functions; F2 excluded)
- Dimension: 30
- Counted objective evaluations: 60,000, including initialization and mutation calls
- Seeds: 101-110 (10 runs per function)
- Population: `NP=40`
- Neighborhood size: `k=8`
- Coefficient: `c2=1.9`
- Four MATLAB workers

This is labelled **paper-aligned independent reproduction**, not an official author implementation. The previous exploratory adapter used `NP=50` and was not source-validated; its results remain in `external_threeway_29f_10seed_20261010` and must not be merged into a formal baseline table.

The tracked reusable adapter is `src/NRLPSO_CEC_PaperAligned.m`; the copy in
this result directory is the exact source snapshot used for the batch.

## Corrections applied

1. Implemented the paper's DOW inertia expression.
2. Used current population positions for the neighborhood velocity terms, matching the supplied MetaBox implementation.
3. Used the next particle's state for the Q-learning TD target.
4. Used the FE-aligned learning rate `max(0.1, 1 - 0.9*FE/maxFE)`.
5. Updated `Best.Cost`, `Best.Vector`, and the FE trace after every objective call, including mutation evaluations.
6. Enforced exactly 60,000 objective calls and checked a complete finite monotone trace.
7. Kept the pbest cost update consistent with the intended optimization rule.

## Validation

`nrlpso_paperaligned_smoke/smoke.csv` contains 24 smoke runs (8 functions x 3 seeds, 6,000 FE). All passed budget, finite-trace, monotonicity, and Best-vector re-evaluation checks.

The full run contains 290/290 `ok` records. The corrected adapter's mean runtime was 3.297 s per run on this machine. Existing ASE-CSO and CLPSO means are shown only as exploratory context; because this corrected reproduction uses `NP=40` while the earlier ASE/CLPSO batch used `NP=50`, those comparisons are not paired or a formal same-population claim.
