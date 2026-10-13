# Corrected partial-restart validation

This directory contains the valid rerun after fixing the restart-candidate write-back bug in `SAQ_CSO_RestartQ.m`.

## Protocol

- Dimension: 50
- Budget: 100,000 true objective evaluations
- Functions: F01, F06, F09, F12, F13, F21, F22, F30
- Seeds: 701--710
- Policies: Sparse-Base, Fixed-Restart, Random-Restart, Q-Restart
- Workers: 4
- Valid runs: 320/320

The previous pilot directories must not be used as evidence. Before this rerun, `makeRestartPlan` modified a local copy of the candidate pool without returning it to the caller. The restart rows were therefore not actually evaluated as intended.

## Corrected comparisons

| Comparison | Function-mean wins | Function-mean losses | Paired seed wins | Paired seed losses | Ties |
|---|---:|---:|---:|---:|---:|
| Fixed-Restart vs Sparse-Base | 1 | 7 | 27 | 40 | 13 |
| Random-Restart vs Sparse-Base | 4 | 4 | 32 | 35 | 13 |
| Q-Restart vs Sparse-Base | 4 | 4 | 37 | 43 | 0 |

See `restart_function_means_corrected.csv`, `restart_comparison_summary_corrected.csv`, and `restart_audit_summary.csv` for machine-readable details.

## Decision

The corrected data do not show a stable advantage for partial restart, random restart, or the current Q policy. The Q policy should remain exploratory and should not be presented as a validated contribution. Further restart-operator tuning is paused until a separate, pre-registered mechanism is defined.
