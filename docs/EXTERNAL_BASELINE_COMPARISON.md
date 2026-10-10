# Four-way external baseline comparison

The repository contains two papers supplied for comparison:

- NRLPSO: *Reinforcement learning-based particle swarm optimization with
  neighborhood differential mutation strategy* (2023).
- RLPSO/RLAM: *Reinforcement-learning-based parameter adaptation method for
  particle swarm optimization* (2023).

Their published tables are not directly comparable with ASE-CSO results. The
papers use different benchmark suites, budgets, populations, training rules,
and repetition protocols.

## What each method tests

| Method | Search base | Learning component | Other mechanisms | Original benchmark protocol |
|---|---|---|---|---|
| ASE-CSO | Cat Swarm Optimization | None in the frozen version | Sparse real evaluations, trusted real-position anchors, virtual Tracing, Global-Cap2 | CEC2017, commonly 60,000 FE in our restricted-budget study |
| CLPSO | Comprehensive Learning PSO | None | Personal-best exemplar learning | CEC2017 adapter in the legacy repository |
| NRLPSO | PSO | Online Q-learning with four states/actions | Dynamic oscillating inertia, cosine-similarity velocity learning, neighborhood differential mutation | CEC2017/CEC2022, 30D/50D, original population and 51 independent runs |
| RLPSO/RLAM | PSO with CLPSO learning and mutation | DDPG actor/critic pretraining | Learned parameter groups and mutation | CEC2013, 28 functions, 10,000 FE in the paper |

## Source audit

The local `对照` folder contains the two papers only. The public RLPSO/RLAM
repository is a Python training/evaluation project and requires TensorFlow;
the checkout has no ready CEC2017 adapter or frozen actor checkpoint suitable
for an unseen CEC2017 test. The MetaBox NRLPSO implementation is explicitly a
third-party implementation and is integrated with MetaBox's own problem
interfaces rather than this repository's CEC2017 MATLAB wrapper.

Therefore a four-way numerical table will not be produced until NRLPSO and
RLPSO/RLAM pass a source and function-call audit. CLPSO is included as the
fourth executable comparator and is already available locally. A paper result
copied from either PDF would be labelled as historical reference, never as an
ASE-CSO head-to-head result.

## Required comparable protocol

Primary comparison:

- CEC2017 F1 and F3-F30, D=30.
- 60,000 counted objective evaluations, including initialization and any
  mutation or auxiliary evaluations.
- The same five or thirty new seeds for every method.
- ASE-CSO remains frozen; no parameter changes are made to improve this table.
- CLPSO is run in the same table, with the same initial population and counted
  FE protocol.
- Each baseline keeps its published population and algorithm parameters, with
  those differences reported explicitly.
- NRLPSO is marked `third_party_reimplementation` unless an author release is
  obtained.
- RLPSO is run with a frozen model trained without touching the CEC2017 test
  functions. Training evaluations, training time, model hash, and inference
  time are reported separately. A same-function training reproduction, if
  performed, is a separate non-comparable appendix experiment.

Secondary protocol:

- NRLPSO at its published CEC2017 D30 budget, using the published population
  and run count where the implementation can be verified.
- RLPSO on its published CEC2013 suite and 10,000-FE protocol, using the
  author-provided data and training/evaluation separation.

## Current status

The two public checkouts are kept outside the repository under
`work/external_baselines/` and are not copied into the paper source tree. A
MATLAB preflight has now run ASE-CSO and CLPSO on the same CEC2017 F1 initial
population and 6,000 counted evaluations (seed 101); both completed the FE
assertion. This is only an adapter smoke test, not a reported result. The next
executable milestone is an eight-function, three-seed four-way CEC2017 smoke
comparison after the NRLPSO adapter and RLAM model provenance are resolved.
Until then, the defensible conclusion is a mechanism-level comparison, not a
numerical claim that ASE-CSO beats either published method.
