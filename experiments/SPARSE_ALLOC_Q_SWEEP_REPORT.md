# Sparse allocation Q-learning parameter sweep

Protocol: six functions (F1, F3, F6, F9, F12, F22), seeds 101--103,
D=30, N=50, 60,000 objective calls, 4 workers. The search kernel and the
four-state/two-action Q definition were fixed. Only alpha, gamma and epsilon
were changed.

The sweep covered:

- alpha: 0.1, 0.3;
- gamma: 0.7, 0.9, 0.99;
- epsilon: 0.05, 0.10.

This produced 12 configurations and 216 valid runs. Results are in:

`results/cec/sparse_alloc_q_sweep_20261011_193547/`

## Best configurations

By average rank across the six function means:

| alpha | gamma | epsilon | best-function count | average rank |
|---:|---:|---:|---:|---:|
| 0.3 | 0.9 | 0.10 | 2/6 | 4.50 |
| 0.3 | 0.7 | 0.10 | 1/6 | 4.83 |
| 0.1 | 0.99 | 0.05 | 1/6 | 5.00 |

The configuration 0.1/0.99/0.05 had the best paired result against the random
allocation control (12 wins versus 6 losses over the 18 paired runs), but it
still lost to fixed Continue (11:7) and fixed Switch (8:10).

The best-average-rank configuration 0.3/0.9/0.10 lost to fixed Continue 9:9
and to fixed Switch 8:10. None of the 12 configurations consistently beat
both fixed controls.

## Decision

Tuning alpha, gamma and epsilon changes Q behavior, but does not solve the
main problem. The current state and reward do not provide enough information
to decide whether a follow-up credit should remain with the current parent or
open a new parent. Further scalar hyperparameter sweeps are not justified.

If Q is retained, the next change should be to the feedback signal: use the
incremental value of a follow-up credit relative to the current parent's first
candidate, and keep a separate running estimate for opening a new parent. The
comparison must still include fixed Continue, fixed Switch and Random. If that
counterfactual-style reward fails, the paper should use the strongest fixed
rule and report Q-learning as an unsuccessful extension.
