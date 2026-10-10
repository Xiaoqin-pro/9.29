# Four-way comparison execution status

## Requested comparison

The planned table contains four methods: the frozen ASE-CSO implementation,
CLPSO, NRLPSO, and RLPSO/RLAM. All four must use the same CEC objective,
initial population protocol, counted FE budget, and seed list before a result
is reported as a head-to-head comparison.

## Completed preflight

- MATLAB R2025b is available.
- The local CEC2017 MEX function loads successfully from the repository's
  `data/cec2017` directory.
- ASE-CSO and the archived CLPSO adapter completed a same-population F1 smoke
  run at seed 101 and 6,000 counted evaluations. Both FE assertions passed.
- This smoke run is only an execution check; its two endpoint values are not a
  published comparison result.

## Blocking items

### NRLPSO

The public MetaBox checkout is a third-party implementation. Its package-level
import currently requires optional `xgboost` and `tianshou` dependencies, and
it exposes MetaBox problem interfaces rather than the repository's CEC2017
MATLAB function. A CEC2017 adapter and dependency-isolated execution path are
still required. It must be labelled `third_party_reimplementation` unless an
author release is supplied.

### RLPSO/RLAM

The public RLAM checkout loads a DDPG actor from an external `.h5` path in its
example code. The checkout contains no actor checkpoint, and this machine has
no TensorFlow runtime compatible with that code. Training a new actor would be
a new experimental condition and cannot be silently substituted for the
published policy.

## No-invalid-results rule

Until these two blockers are resolved, do not create a four-way numeric table
by combining ASE-CSO/CLPSO runs with values copied from either paper. Once the
NRLPSO adapter and RLAM checkpoint provenance are available, run all four
methods together on the same smoke set before scaling to the full comparison.
