# Sparse ablation tracker

|Run|Purpose|Variant|Runs|Status|
|---|---|---|---:|---|
|S0|Exact frozen reference plus variantFE/semantics|all6|small+full100k witnesses|passed:33exact/192cases+5full100k|
|S1|Smoke integration|5new|12|passed|
|S2|Core framework|Dense-NoQ|870|running frozen protocol|
|S3|Core spatial selector|RandomSparse-Fixed6|870|running frozen protocol|
|S4|Originalfixedquota|Fixed4|870|running frozen protocol|
|S5|Strongfixed/coreanchor|Fixed6|870|running frozen protocol|
|S6|Minimal nonlearningquota|RandomQuota|870|running frozen protocol|
|S7|CachedFull comparison|Full|870|cached, partialchecks passed|

Formalrun: results/cec/saq_sparse_ablation_30seed_study_20261013_133122.
After completion: finite pipeline independently verifies allMATs andbest/p0 beforewriting ACCEPTED.json; pending performance data is not final evidence.
