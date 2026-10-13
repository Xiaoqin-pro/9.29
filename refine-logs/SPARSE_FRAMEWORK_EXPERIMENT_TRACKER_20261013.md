# Sparse ablation tracker

|Run|Purpose|Variant|Runs|Status|
|---|---|---|---:|---|
|S0|Exact frozen reference plus variantFE/semantics|all6|small+full100k witnesses|passed:33exact/192cases+5full100k|
|S1|Smoke integration|5new|12|passed|
|S2|Core framework|Dense-NoQ|870|completed870, verified|
|S3|Core spatial selector|RandomSparse-Fixed6|870|completed870, verified|
|S4|Originalfixedquota|Fixed4|870|completed870, verified|
|S5|Strongfixed/coreanchor|Fixed6|870|completed870, verified|
|S6|Minimal nonlearningquota|RandomQuota|870|completed870, verified|
|S7|CachedFull comparison|Full|870|cached870, allchecks passed|

Formalrun: results/cec/saq_sparse_ablation_30seed_study_20261013_133122.
After completion: finite pipeline independently verifies allMATs andbest/p0 beforewriting ACCEPTED.json; pending performance data is not final evidence.

Batch finished2026-10-13 16:19:38. FinalMAT checks5220 passed, independentbest rechecks5220 maxdiff0, seed-regenerated populations5220 exact. Results: results/saq_sparse_framework_ablation_30seed_20261013/REPORT.md. Accepted, no new developmentruns launched.
