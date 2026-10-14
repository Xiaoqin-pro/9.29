# Teacher-inspired reward pilot, 2026-10-14

Prespecified before performance runs. One reward candidate; no reward sweep.

- Backbone: archived SAQ_CSO_EliteProbe, fixed 6T/4S, existing geometric screening, low-progress gate, protected single-coordinate elite probe and replace acceptance. Quota Q is absent.
- Candidate: effective window improvement +10; otherwise an actually executed probe in a low-progress window +0.5; otherwise -1. The effective-improvement threshold is retained from the previous engine, unlike the teacher's any-improvement condition.
- All search equations, RNG seeds/streams, states, 100FE decisions, 1000FE gate, alpha .1/gamma .9/epsilon .1 remain unchanged. Original engine is preserved.
- D50, N50, 100k actual optimization calls, F1/F6/F9/F13/F21/F22/F27/F30, seeds8101-8110; four local MATLAB workers. This reuses known development functions/seeds and is not independent confirmation.
- One new method, 80 new optimization runs /8M evaluations. Existing Fixed6, rule, random, old-Q development results are cached references; verify matching configurations and RNG columns, and old/new engine legacy trajectory equivalence before use.
- Compare final per-function mean errors and paired seeds, retaining all functions. Report Holm-adjusted paired Wilcoxon across all 8x4 candidate-control comparisons as exploratory statistics. Do not infer equivalence from NS.
- Development gate: versus Fixed6 at least5/8 mean wins and median function-mean error ratio<=.95; versus BOTH rule and random at least5/8 mean wins and median ratio<=1; at least2/3 F1/F13/F30 not worse than Fixed6 and no >20% regression among these three. Improvement over old Q alone is insufficient.
- If passed, run a genuinely new-seed confirmation before paper claims or expansion. If failed, retain the result and stop this candidate without tuning thresholds/rewards in this batch.
- +0.5 is shaping reward, not observed fitness improvement. It can induce a policy close to the rule baseline; action shares cannot establish learning value.
- Every new run counts actual objective calls and reevaluates final best, all real positions/pbests and probe points separately; these audit calls are outside the optimization budget and explicitly totaled.

No manuscript or frozen algorithm changes.
