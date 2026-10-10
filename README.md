# ASE-CSO

This repository contains the frozen **Anchored Sparse-Evaluation Cat Swarm
Optimization (ASE-CSO)** implementation. The name describes the algorithm's
fixed mechanism: a sparse real-evaluation budget is combined with a trusted
real-position anchor while unevaluated Tracing positions may continue moving.

The formal implementation is [`src/ASE_CSO.m`](src/ASE_CSO.m). It has no
reinforcement-learning, recovery, or exploratory experiment switches. The
historical implementation and all exploratory drivers are kept under
[`archive/legacy`](archive/legacy) for reproducibility and are not the formal
entry point.

## Verification

Run MATLAB from the repository root:

```matlab
setup_project(true);
smoke_ASE_CSO
test_ASE_CSO_regression
```

The smoke test covers D=30 and D=100, including incomplete final rounds. The
exact regression compares the frozen implementation against the historical
reference on the same initial population and search seed. It checks every
objective-call position, the final solution, the complete convergence trace,
the final random-number state, FE accounting, and key per-round diagnostics.

The reference regression does not constitute a new performance experiment. It
only protects the frozen implementation during refactoring.

## Frozen protocol

- Range Seeking, SMP=5, SRD=0.05, CDC=0.20.
- MR=0.4 with two Tracing and three Seeking evaluations per full round.
- Global-Cap2 Seeking selection and top-20% historical-elite guidance.
- Decaying Tracing inertia and virtual Tracing with real-position rollback.
- No Q-learning and no Recovery.
- The caller supplies the initial population, bounds, objective, and FE budget.

Historical result folders retain their original experimental labels. They are
not renamed to ASE-CSO, so old evidence remains auditable.
