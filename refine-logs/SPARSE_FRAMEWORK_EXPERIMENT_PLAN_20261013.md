# Experiment Plan — Sparse evaluation framework

Date: 2026-10-13. Method is frozen SAQ-CSO.

|Claim|Minimum evidence|Contrast|
|---|---|---|
|C1 sparse framework improves same100k quality|same search formulas, noQ on both sides, realFE counted|Fixed6 vsDense-NoQ|
|C2 geometry improves random selection at same sparse cost|same10FE/quota/cap2/anchor|Fixed6 vsRandomSparse-Fixed6|
|Supporting adaptive scheduling|show full vs fixed4/fixed6 and same-gate random; report negative cases|Full vs3policies|

Must-run:5new variants×29functions×30seeds=4350runs; cache870Full. D50/100k/4workers. NoVirtual、reward/stateQgrids cut. Parameters do not change after results.

Order: correctness andfull100k witnesses → smoke2functions×1seed×5variants → formalimmutable snapshots → independentMAT/best/p0checks →145testsHolm/figures →UAV remains subsequent work.

Detailed run protocol: docs/SAQ_SPARSE_ABLATION_PROTOCOL_20261013.md. Main comparator subset deliberately selected by user after earlier eight-method exploration; include scope caveat and retain broader data.
