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
4350 new runs. A launch is not a completed result. Status and all rawMAT files
are under the timestamped local `results/cec/saq_sparse_ablation_30seed_*` folder.

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
