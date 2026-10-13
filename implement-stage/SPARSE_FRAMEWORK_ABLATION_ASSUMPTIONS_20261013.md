# Sparse-framework ablation assumptions — 2026-10-13

| ID | Decision before code | Rationale/source |
|---|---|---|
| SF-01 | Main performance subset exactly SAQ-CSO,Original-CSO,CLPSO,HPSO-TVAC,SPSO-2011 as requested. Archive every earlier baseline/result, do not delete. Recompute subset ranks and Holm116 rather than relabel8-way metrics. | User explicit main-table scope |
| SF-02 | Record that five-method scope was selected after exploring other algorithms; conclusion applies to this reported comparison set, not SOTA/allPSO. Archive broader sensitivity accessible. | No post-hoc selection disguised as broad superiority |
| SF-03 | Primary ablation is sparse framework: Dense-AllEval-NoQ vs Sparse-Fixed6; full SAQ vs same-quota RandomScreen-Q; full SAQ vs NoVirtual-Q. Secondary onlyFixed4/Fixed6, no reward/state/alpha grids or Random/EpsQ sweep. | User correction emphasizes sparse framework |
| SF-04 | Full evaluation cannot retain pure sparse-quota Q actions, which become meaningless. Compare full-evaluation with sparseFixed6, both noQ; label this sparse-framework package including parent-cap/roundcost differences, not geometry-only causality. | Action semantics from frozen code |
| SF-05 | Dense mode preserves candidate generation SMP5/MR.4/inertia/radius/elite/acceptance; evaluates all tracing candidates and all4new Seeking candidates until exactremainingFE, parent baseline cost reused. Complete dense rounds≥50 newFE; partialterminal orderedtrace-thenSeeking. | Same search backbone, physical objective calls |
| SF-06 | Random screening keeps10FE/round, actual quota choice, cap2 and allacceptance; independently seeded screenRNG changes only selector; no surrogatefitness for skipped points. | Isolates geometric choice at fixed cost |
| SF-07 | NoVirtual-Q suppresses position propagation only for skippedTracing; predictionvelocity retained as in original; realpositionanchor/acceptance remains. Do not disable trusted fitness or rollback, which would create invalid x/f pairs. | Search validity and one mechanism change |
| SF-08 | Formal variant engine is a newcopy of immutable compact code with explicit flags. Geometry+sparse+virtual branch must exactly match originalpoint/T/Best/RNG and Q tables before launch. SourceSHA gates require freshtest after edits. | Existing frozen main algorithm remains unchanged |
| SF-09 | D50/100k/29functions/30seed3001–3030/N50/4worker; fullSAQ870 cached aftersource+p0 verification. New5 variants4350runs, no parameter tuning after seeing outcomes. | Shared current formal protocol |
| SF-10 | Core scientific contrasts preselected: Fixed6 vsDense, SAQ vsRandomScreenQ, SAQ vsNoVirtualQ; Qsupport SAQvsFixed4,SAQvsFixed6. Test all29 functions, report failures and negative outcomes; no promising-function-only table. | Matched per-seed inferential design |

## SF ablation simplification after reading user's provided advice

| ID | Final decision before results | Source |
|---|---|---|
| SF-11 | Replace formalRandomScreen-Q with RandomSparse-Fixed6 so primary geometry comparison has no adaptive-controller confound. NoVirtual remains a prepared optional branch, excluded from formal matrix. | User focus on sparse framework + supplied 6-version proposal |
| SF-12 | Keep only one inexpensive same-gate RandomQuota control for Q alongsideFixed4/Fixed6; no separate parameters/states/rewards. Final6 = Dense-NoQ,RandomSparse-Fixed6,Fixed4,Fixed6,RandomQuota,Full. | RandomQuota lets authors describe observed learning-vs-random honestly while keeping story compact |
| SF-13 | Formal primary contrasts: Fixed6vsDense; Fixed6vsRandomSparse. Secondary: FullvsFixed4/Fixed6/RandomQuota. Infer with paired30seed perfunction and Holm across145predefined tests. No stop at favorable significance, no posthoc removal. | Claimed mechanism-first design |
| SF-14 | Keep longer full100k correctness witness for all5newvariants, plus exact full-engine equivalence and independent fixed-budgetengine equivalence. Cache Full870 only aftersourcehash/p0/runrecord checks. | Same frozen backbone and correctness requirement |
