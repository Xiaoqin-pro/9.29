# Frozen ASE-CSO protocol

## Scope

This is the implementation freeze for the paper evidence phase. No parameter
search, Q-learning branch, Recovery branch, or new search operator belongs in
the formal implementation.

## State model

`realPop` is the last accepted, truly evaluated position for each cat, and
`fitness` refers to that position. `pop` may contain an unevaluated virtual
Tracing position. Virtual positions can guide the next round but cannot update
personal bests or the global best until their objective value is measured.
Rejected evaluated trials restore the corresponding real anchor.

## Exact-equivalence evidence

The regression harness compares the formal implementation with the historical
reference using identical initial populations and search seeds. Passing means
the objective-call sequence, final result, full FE-indexed convergence trace,
random-number state, FE accounting, and frozen diagnostic fields agree.

The historical reference is retained in `archive/legacy/DSS_RLCSO.m`; the
formal entry point is `src/ASE_CSO.m`.

## Naming rule

Exploration labels are retained only inside `archive/legacy` and historical
result folders. Formal source, tests, and documentation use ASE-CSO.
