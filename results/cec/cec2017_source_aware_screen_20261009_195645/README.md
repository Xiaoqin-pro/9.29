# Source-aware sparse screening at 60k FE

- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.
- Repeats: 71:73; D=30; population=50; 60,000 FE.
- All runs use Range Seeking, Seeking elite guidance, tracing decay, virtual tracing with rollback, MR=0.4, SMP=5, 2 Tracing + 3 Seeking FE, no Recovery and no RL.
- E-G: standard Global-Cap2 (2 near-gbest + 1 far-center).
- E-S: 1 near-gbest + 1 source-aware candidate + 1 far-center. The source-aware candidate maximizes normalized progress toward the actual elite sampled for that parent in the current round.
- The source-aware candidate is selected from the existing candidate pool; no extra Fitness evaluations or new candidate formulas are used.
- The script checks exact FE accounting, mode allocation and parent cap.


## Source-aware comparison

`source_comparison.csv` compares E-S with the same-seed E-G baseline.

- E-S wins 7/8 function means and 15/24 paired final-error runs.
- E-S improves F6, F9, F12, F13, F28 and F30 in the mean comparison, while F3 is consistently worse and F20 is mixed.
- The predeclared 5/8 mean threshold is met, but the 16/24 paired threshold is not. Therefore source-aware screening is a promising fixed strategy, not yet a validated independent contribution and not yet a reason to add Q-learning.
- SourceProgress uses a search-space-scaled denominator floor (`1e-6*norm(ub-lb)`) when the parent and sampled elite are nearly coincident.
