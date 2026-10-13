# Formal comparison protocol — SAQ-CSO vs CSO/CLPSO/HCLPSO (2026-10-13)

## Frozen methods

- `Original-CSO-MR02`: `archive/legacy/CSO_CEC.m`, original `MR=0.20`.
- `SAQ-CSO`: `src/SAQ_CSO.m`, sparse evaluation with stall-gated three-action quota Q-learning.
- `CLPSO-AuthorSource`: `src/CLPSO_CEC_AuthorSource.m`, public author-code profile adapted to CEC and exact FE cap.
- `HCLPSO-Reference`: `src/HCLPSO_CEC_Reference.m`, continuous MATLAB adapter anchored to the NEORL public implementation and its cited Lynn–Suganthan method.

EPSO is excluded from the formal comparison by decision on 2026-10-13.

## Common protocol

- Benchmark: CEC2017, F1 and F3–F30 (29 functions; F2 remains excluded under the repository's existing protocol).
- Dimension: D=50.
- Population: N=50 for every algorithm; HCLPSO uses g1=20 and g2=30.
- Budget: exactly 100,000 objective calls, including initialization and excluding one post-run audit call.
- Seeds: 30 independent seeds, fixed in the job manifest before launch.
- Initial population: same deterministic population pool for paired methods within each function/seed.
- Domain: CEC2017 bounds [-100,100]^50 and repository objective implementation.
- Parallelism: four MATLAB process workers, one BLAS thread per worker.
- Stored artifacts: raw run record, convergence trace, source snapshot, environment, job manifest, progress, and independent post-run checks.

## Main claims supported

1. Under an equal 100k FE budget, SAQ-CSO is a competitive sparse-evaluation CSO on CEC2017.
2. The Q scheduler adapts evaluation quotas after persistent stagnation; it is a supporting mechanism, not the sole source of the paper's performance claim.

## Required controls

The separate ablation batch includes SAQ-CSO-Fixed4, SAQ-CSO-Fixed6, and same-gate random quota. The formal four-way comparison must not remove the strongest fixed control from the ablation report.

## 2026-10-13核验后追加

- 原3480run完成并保留。HCLPSO-Reference不再作为正式主列；由作者MATLAB版15/35分组替换，详见HCLPSO_AUTHOR_CORRECTION_20261013.md。
- 用户授权增加2020 HIDMS-PSO。因为原生4成员单元约束，使用N40、共享50点初始池前40点；不再宣称所有算法人口规模相同。细节和一行best-slave索引修正见HIDMS_PSO_PROTOCOL_20261013.md。
- 30seed、29函数、D50、100k真实FE维持；所有补跑只用于基线身份核验，不按结果调整SAQ-CSO。
- 文中“Main claims supported”应理解为待检验目标，不能单凭外部主表证明Q必要或稀疏机制的独立因果贡献。
