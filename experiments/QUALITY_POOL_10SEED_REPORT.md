# Quality candidate pool: 10-seed development report

This report combines the initial seeds 101--103 with the additional seeds
104--110. It covers eight diagnostic functions (F1, F3, F6, F9, F12, F13, F22,
F30), four candidate selectors and 320 valid runs in total. The two raw result
directories are:

- `results/cec/ase_quality_pool_pilot_20261011_185004/`
- `results/cec/ase_quality_pool_pilot_s104_110_20261011_190238/`

Every run reached 60,000 objective calls and passed the finite, monotone trace,
parent-cap and final-best recheck assertions.

## Function-level mean winners

| selector | best functions |
|---|---:|
| geometry | 1/8 |
| random | 3/8 |
| reserved exploration | 2/8 |
| source credit | 2/8 |

The mean errors show a stable landscape-dependent pattern:

- Random selection is strongest on F6 and F9.
- Reserved exploration is strongest on F3, F12 and F30 in the combined means,
  although the F3/F30 margins are not uniformly large across seeds.
- Credit selection is strongest on F1 and F13.
- Geometry is strongest on F22.

## Paired seed comparisons

Across all 80 paired runs per comparison:

| comparison | A wins | B wins |
|---|---:|---:|
| geometry vs random | 41 | 39 |
| reserved vs random | 40 | 40 |
| credit vs random | 44 | 36 |
| credit vs reserved | 42 | 38 |
| reserved vs geometry | 44 | 35 |

These are development statistics, not formal significance results. The small
overall margins and strong function-specific reversals do not support claiming
that a universal geometry or credit rule is better.

## Source diagnostics

The credit selector evaluated elite and coordinate-exemplar candidates most
often, while cognitive candidates were rarely selected. This indicates that a
single global source credit can collapse toward a few sources and does not by
itself provide a reliable quality estimate.

## Decision

The next mechanism should not be another source-weight formula. The evidence
supports a more local rule: after the first real Seeking evaluation of a parent,
use its observed improvement to decide whether the next credit stays with that
parent or moves to another parent, while reserving one exploration credit. This
is a CSO-specific sequential allocation question and can be compared directly
with fixed-continue, fixed-switch and random controls before introducing a
two-action Q table.
