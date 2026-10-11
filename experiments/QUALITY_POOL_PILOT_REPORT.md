# Quality candidate pilot report

Date: 2026-10-11  
Protocol: D=30, N=50, 60,000 objective calls, 4 workers, seeds 101--103, functions F1, F3, F6, F9, F12, F13, F22 and F30.

All 96 runs completed with status `ok`. Every run reached exactly 60,000 calls,
had a finite non-increasing convergence trace, zero final-best recheck error,
and respected the two-evaluations-per-parent cap. Raw output and diagnostics
are in the ignored result directory:

`results/cec/ase_quality_pool_pilot_20261011_185004/`

## Configurations

- `Quality-geometry`: current near-best/far-centre ordering.
- `Quality-random`: random eligible candidate selection under the same cap.
- `Quality-reserved`: one Range exploration candidate is reserved, and the remaining slots use geometry.
- `Quality-credit`: one Range candidate is reserved; the remaining slots use exponentially updated source credit with geometry tie-breaking.

The candidate sources are cognitive, elite, coordinate exemplar and Range.
No differential-evolution mutation, recovery, MR adaptation or Q-learning is
used.

## Development result

Function-level mean-error winners in this eight-function pilot:

| configuration | best-function count |
|---|---:|
| Quality-geometry | 1 |
| Quality-random | 3 |
| Quality-reserved | 3 |
| Quality-credit | 1 |

Paired seed wins over current B10 on the 24 runs for each configuration:

| configuration | wins | losses |
|---|---:|---:|
| Quality-geometry | 13 | 11 |
| Quality-random | 9 | 15 |
| Quality-reserved | 11 | 13 |
| Quality-credit | 12 | 12 |

The reserved version was strongest on the aggregate mean among the four new
selectors, but it did not yet beat B10 consistently. The credit version did
not show a reliable advantage and should not be promoted to a paper claim.

## Interpretation

The pilot does not support claiming that a learned source-credit ranking is
already effective. It does support continuing a narrower hypothesis: keeping a
mandatory exploration opportunity while using CSO/PSO-style cognitive, social,
coordinate-exemplar and Range candidates may be more robust than applying a
single geometric ranking to all Seeking slots.

The next comparison should therefore be a small causal test of the reservation
rule, not another credit formula:

1. B10 baseline;
2. geometry with no reservation;
3. geometry with one fixed exploration reservation;
4. fixed success-based continuation/switching after the first real Seeking evaluation.

Only if the fixed feedback rule beats both geometry and random controls should a
two-action Q-table be added.
