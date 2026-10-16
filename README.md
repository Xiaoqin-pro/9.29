# SAQ-CSO

The current paper method is **SAQ-CSO (Sparse Adaptive-Quota Cat Swarm
Optimization)**. The frozen entry is [`src/SAQ_CSO.m`](src/SAQ_CSO.m), which calls
`ASE_CSO_QuotaQ_Candidate.m` and the audited compact implementation.

The primary mechanism is sparse true evaluation with geometric candidate
screening, virtual Tracing movement and trusted real-position anchors. A small
Q-learning scheduler reallocates Seeking/Tracing evaluation quotas during
persistent stagnation. The main entry is frozen; ablations use separate files.

## Frozen method

- Population50, search-mode MR=.4 (distinct from true-evaluation quota).
- Seeking SMP5/SRD.05/CDC.20, elite guidance; decaying Tracing inertia.
- Ten true evaluations per complete sparse round, geometric near-best/far-centre screening and Seeking parent cap2.
- Healthy search uses6T4S. After1000 trueFE without best improvement, a3×3
  Q-table chooses2T8S/4T6S/6T4S for100FE windows.
- Improvement reward+10, otherwise−1; alpha=.1/gamma=.9/epsilon=.1.
- No radius-restart, recovery, holding-window extension or extra learning mechanism.

Definition: [`docs/SAQ_CSO_FINAL_METHOD_PROTOCOL_20261013.md`](docs/SAQ_CSO_FINAL_METHOD_PROTOCOL_20261013.md).

## Main performance comparison

CEC2017, D50,100k actual evaluations including initialization,29 functions
(F1,F3–F30),30 seeds3001–3030. The five-method paper set is:
SAQ-CSO, OriginalCSO(MR=.2), CLPSO, HPSO-TVAC and SPSO-2011.
SPSO uses40 particles; the other four use50, sharing initial population prefixes.

- [Final five-method table](results/saq_cso_main_five_30seed_20261013/REPORT.md).
- [Earlier full eight-method comparison](results/saq_cso_eightway_30seed_20261013/REPORT.md).

The five-method set was chosen after the broader comparison. Its rank is a rank
within that set, not a claim of dominance over every tested PSO variant. Stronger
HCLPSO/HIDMS/DMS results remain archived. Compare families and scope explicitly.

## Sparse-framework ablation

The frozen six-version design is FullEval-CSO, RandomSparse-Fixed6,
SpatialSparse-Fixed4, SpatialSparse-Fixed6, SpatialSparse-RandomQuota and full
SAQ-CSO. Primary contrasts use the same noQ backbone: Fixed6vsFullEval and
Fixed6vsRandomSparse. Q has only three supporting comparisons; no parameter grid.

[Detailed ablation protocol](docs/SAQ_SPARSE_ABLATION_PROTOCOL_20261013.md).

[Completed six-version results](results/saq_sparse_framework_ablation_30seed_20261013/REPORT.md):
Fixed6 vs FullEval gives24/5 function mean wins/losses; Fixed6 vs random sparse
selection gives26/3. The Q variant has no significant advantage over fixed or
same-gate random quotas after the predefined145-test Holm correction. All5220
quality records passed independent artifact, final objective and population checks.

Run from the repository root:

```matlab
setup_project(true);
addpath(fullfile(pwd,'experiments'));
test_SAQ_framework_ablation;
run_saq_sparse_ablation_30seed('smoke');
run_saq_sparse_ablation_30seed('study');
```

Formal jobs require checksum-bound preflight. The complete SAQ results are
reused only after source/population/trajectory checks; five new variants require
4350 new runs. The completed batch and all rawMAT files are under the timestamped local `results/cec/saq_sparse_ablation_30seed_*` folder.

## ASC elite-probe development screening

A separate development line evaluates `ASC_NoFarness` with a small number of
protected elite probes under the same 100k real-evaluation budget. The frozen
10-seed A0–A3 screen used eight CEC2017 functions and 320 fresh runs. The
multi-elite Gaussian candidate did not pass the pre-specified gate: it did not
beat the original ASC overall or the variance-matched uniform control, with
clear regressions on F6 and F9. The original ASC remains the development
baseline; the negative result is retained in full rather than tuned away.

- [Result diagnosis](results/asc_gaussian_10seed_20261015/DIAGNOSIS.md)
- [Frozen screening protocol](docs/ASC_ELITE_GAUSSIAN_PROTOCOL_20261015.md)
- [Public result folder](results/asc_gaussian_10seed_20261015/REPORT.md)

## ASC verified-exemplar learning screening

A second development line on the frozen `ASC_NoFarness` core replaces the
Tracing social direction with a dual verified-exemplar direction: the particle's
own evaluated personal best plus an evaluated elite. B1 uses that split for the
whole swarm, B2 additionally lets a fixed 30% of the particles compose their
social direction dimension by dimension from several evaluated elites. Both
modes keep the sparse geometry screening, the Seeking model, the adaptive
probability/radius control, Jump and the 100k budget unchanged, and B0 is
pointwise identical to the original algorithm.

The frozen screen used 12 CEC2017 functions (8 previously developed plus 4
cross-check functions), 10 new seeds and 360 fresh runs. It **did not pass the
pre-specified gate**: the dual direction improved 6/8 functions on the developed
set (median error ratio 0.573, F1 error falling from 5.59e6 to 2.97e3) but
regressed on all 4 cross-check functions (median 1.277) and on F27 by 38.9%.
The diagnostics show the mechanism clearly — Tracing evaluations improved the
particle's own record 2.1x more often — while the advantage decays after the
mid-run and the largest gap between two evaluations of the same particle grows
from 94 to 811 rounds. The original ASC remains the development baseline; the
negative result is retained in full and the coefficients were not re-tuned.

- [Mechanism diagnosis](results/asc_verified_learning_10seed_20261015/DIAGNOSIS.md)
- [Run report](results/asc_verified_learning_10seed_20261015/REPORT.md)
- [Frozen screening protocol](docs/ASC_VERIFIED_LEARNING_PROTOCOL_20261015.md)

## ASC stage-scheduled learning screening

A third development line asks *when* the verified cognitive direction should be
active, rather than how strong it should be. C00 is the original social update,
C11 is cognitive + social for the whole budget, C01 is social first and
cognitive after 50% of the real-evaluation budget, C10 is the reverse. The
cognitive coefficient is drawn from a dedicated RandStream while the social draw
keeps the original global-stream position, so C01 is bit-identical to C00 before
the switch and C10 is bit-identical to C11, which the audit test verifies.

The frozen screen used 12 CEC2017 functions, 10 new seeds and 480 fresh runs. It
**did not pass the pre-specified gate**, but it explains why a fixed schedule
cannot: F27 only punishes *early* cognition (C11 1.460 and C10 1.453 against C01
1.001), while F6 and F9 only gain from *late* cognition (C01 0.770 and 0.575
against C11 1.228/1.292 and C10 1.355/1.614), and F3/F13/F29 prefer early
cognition. No single switch point can satisfy both groups, so the protocol's
stop rule applies and no further switch fractions were scanned. The new coverage
diagnostics also show the cognitive direction degrades evaluation coverage: the
share of particles more than 100 rounds without a real evaluation rises from
0.001% to 2.41% and the largest evaluation gap from 94 to 842 rounds.

- [Mechanism diagnosis](results/asc_stage_learning_10seed_20261015/DIAGNOSIS.md)
- [Run report](results/asc_stage_learning_10seed_20261015/REPORT.md)
- [Frozen screening protocol](docs/ASC_STAGE_LEARNING_PROTOCOL_20261015.md)

## ASC evaluation starvation guard screening

The stage-scheduled screen showed that the cognitive direction also degrades how
evenly real evaluations cover the population: particles waiting more than 100
rounds rise from 0.001% to 2.41% and the largest evaluation gap from 94 to 842
rounds. This 2x2 screen asks whether spending one of the existing ten
evaluation slots on the longest-starved particle repairs that, and whether it
changes performance. Method names read `G<guard><cognition>`, so G11 is
cognitive learning plus a guard with K=100 rounds.

The frozen screen used 12 CEC2017 functions, 10 new seeds and 480 fresh runs. The
guard does exactly what it was designed to do — with the cognitive schedule the
share of particles waiting more than 100 rounds falls from 2.36% to 0%, the
largest gap from 802 to 101 rounds and the window coverage recovers to 99.999%
from 97.60% — while spending only 0.132% of the evaluation budget. It also stays
silent when coverage is healthy: against the baseline it fires 0.21 times per
run and leaves 10 of 12 functions bit-identical. But **repairing coverage did not
change performance**: G11 vs G01 is 4/4 function means on the developed set
(median ratio 1.0004) and 0/4 on the cross-check set (1.0948). Guard evaluations
improved a particle's own record 36.8% of the time and the global best never.
The gate is not passed, K is not re-tuned, and no further evaluation-allocation
mechanism is added to ASC.

- [Mechanism diagnosis](results/asc_starvation_guard_10seed_20261015/DIAGNOSIS.md)
- [Run report](results/asc_starvation_guard_10seed_20261015/REPORT.md)
- [Frozen screening protocol](docs/ASC_STARVATION_GUARD_PROTOCOL_20261015.md)

## ASC seeking-candidate screening

The first three development lines all changed the Tracing learning rule and all
traded a large gain on F1/F12/F13 for a regression on F27 and the cross-check
functions. This screen moves the change to the Seeking side: each Seeking
particle keeps its first two candidates and replaces the last two, either with an
elite-guided displacement (A1), a perturbation centred on the particle's own
verified `pbest` (A2), or both (A3). Tracing, Jump, screening, adaptive control
and the budget are untouched, and A0 is pointwise identical to `ASC_NoFarness`.

The frozen screen used 12 CEC2017 functions, 10 new seeds and 480 fresh runs. No
variant passed the gate, but the candidate-level diagnostics explain why, and
the screen produced the most useful lead of the five batches so far. The refined
candidates really are better — they improve a particle's own record 2.0–2.7x
more often and sit 25–50% closer to the current best — but they also crowd out
the original candidates, and performance only improves where the particle's
`pbest` already sits in a promising basin. F3 is the only function whose refined
candidates average more than 0.1 of the search range from the global best, and
it is A2's worst regression (1.332). A2 improves F6 (0.666), F9 (0.481), F24
(0.912) and is the **first mechanism of any batch that does not degrade F27**
(0.979), which makes it complementary to the cognitive direction rather than a
variant of it.

- [Mechanism diagnosis](results/asc_seeking_candidates_10seed_20261015/DIAGNOSIS.md)
- [Run report](results/asc_seeking_candidates_10seed_20261015/REPORT.md)
- [Frozen screening protocol](docs/ASC_SEEKING_CANDIDATES_PROTOCOL_20261015.md)

## ASC hybrid formal evaluation

Two further development rounds combined the two mechanisms that turned out to
improve different function families: the cognitive Tracing direction scheduled
for the second half of the budget, plus Seeking candidates centred on the
particle\'s own evaluated pbest. On 12 developed functions this reached 7/1
function means; on the full 29-function benchmark with 30 paired seeds it **ties
the baseline** (14 wins / 15 losses, median ratio 1.0087, average rank 4.345
against 4.103). The F1 error falls from 5.67e6 to 6.42e3, which is a factor of
883 and lands in the HCLPSO/DMS-PSO range, but mixed-class functions (F13-F15,
F18-F20) regress and cancel the gain. A CLPSO-style dimension-wise exemplar was
then tested as the fix for the mixed-class failure and made things worse
(average rank 5.483), so that hypothesis is rejected.

- [29-function formal comparison](results/asc_hybrid_formal_29f_30seed_20261015/REPORT.md)
- [Why the screening gains did not transfer](results/asc_hybrid_formal_29f_30seed_20261015/DIAGNOSIS.md)
- [Dimension-wise exemplar evaluation](results/asc_dimwise_formal_29f_30seed_20261015/REPORT.md)

## Historical entry

[`src/ASE_CSO.m`](src/ASE_CSO.m) is the earlier frozen **Anchored
Sparse-Evaluation CSO**, with5 evaluations/round and noQ. It remains available
for exact historical regression and is not the current paper entry:

```matlab
setup_project(true);
smoke_ASE_CSO;
test_ASE_CSO_regression;
```

Historical experiments keep their original identities. Full localMAT archives
and running source snapshots are retained; publishedCSV statistics and integrity
records are not renamed to disguise earlier algorithms or settings.
