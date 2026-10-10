# D3 hierarchy selection shadow audit

Gate 1: D30, 60,000 FE, N50, seed 141, F3/F6/F9/F12/F13/F20/F28/F30; four workers.

Original D3 and a generated diagnostic copy run with identical initialization and search seeds. Every real objective call, complete T, Best, production diagnostic fields and final RNG state must agree. Shadow selectors do not call Fitness. Baseline and replay each use 60,000 real FE; the audit is not a zero-cost rerun.

All shadow plans use the same already-generated D3 pool and round-start best/center. They call the production SelectCats, CandidateScreen and GlobalCandidateScreen functions. Old uses the production ID fallback and a separate, seeded stream to shuffle its two parents. K2 and K8 use joint Global-Cap2 selection within the production cat shortlist. Equality/overlap ignore execution ordering but retain both parent ID and candidate ID.

ExplorerFarEvaluatedFrozen measures whether the far-role parent's representative far candidate receives a slot. PostTrace metrics use the actual D3 best after its Tracing evaluations; they isolate reference drift, not the complete legacy Seeking execution, which can update best again after its first parent. The shadow trajectories never execute alternative selections. Results diagnose selection structure, not optimizer quality.

shadow_summary.csv averages every round; shadow_samples.csv retains every 200th round and the final round. Audit-copy runtimes include logging and extra sorting and must not be interpreted as alternative algorithm costs.
