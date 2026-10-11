# Sparse Seeking allocation pilot

Protocol: D=30, N=50, 60,000 objective calls, 4 workers, eight functions
(F1, F3, F6, F9, F12, F13, F22 and F30), seeds 101--105.

The four methods keep the same B10 candidate generation and Tracing kernel. They
differ only in how the six Seeking credits are allocated after three first-visit
credits:

- `continue`: always spend a follow-up credit on the current parent;
- `switch`: always move the credit to another parent;
- `random`: randomly choose Continue or Switch;
- `q`: a four-state, two-action Q-table using phase and the previous candidate's
  success as state.

Results are in:

`results/cec/sparse_alloc_pilot_20261011_192322/`

All 160 runs reached exactly 60,000 evaluations and passed the finite trace,
monotonicity, parent-cap and best-value recheck assertions.

## Results

| policy | best mean functions | mean seconds | mean parent coverage |
|---|---:|---:|---:|
| Continue | 3/8 | 5.14 | 3.00 |
| Switch | 4/8 | 4.93 | 6.00 |
| Random | 0/8 | 5.08 | 4.22 |
| Q | 1/8 | 5.10 | 4.52 |

Paired seed wins:

| comparison | A wins | B wins |
|---|---:|---:|
| Q vs Continue | 19 | 21 |
| Q vs Switch | 20 | 20 |
| Q vs Random | 18 | 22 |
| Continue vs Random | 22 | 18 |
| Switch vs Random | 20 | 20 |

## Interpretation

The current Q table does not provide stable extra value. Its mixed Continue/Switch
behavior increases parent coverage relative to Continue, but that did not turn
into better final error. A global four-state table is too small to distinguish
the different landscapes in this pilot, while adding many state variables would
quickly recreate the mechanism-stacking problem.

The clean conclusion is therefore not “Q is effective”. The experiment supports
using fixed Continue and Switch as mechanism controls and keeping B10 as the
search baseline. If Q is revisited, the next change must address the missing
counterfactual signal (the value of spending the same credit on a new parent),
not merely retune alpha, gamma or epsilon.
