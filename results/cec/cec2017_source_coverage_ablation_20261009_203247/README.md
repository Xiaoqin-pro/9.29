# Coverage-matched source-aware screening at 60k FE

- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.
- Repeats: 71:73; D=30; population=50; 60,000 FE.
- All runs use Range Seeking, Seeking elite guidance, tracing decay, virtual tracing with rollback, MR=0.4, SMP=5, 2 Tracing + 3 Seeking FE, no Recovery and no RL.
- E-C keeps the E-S first two choices (1 near-gbest + 1 far-center), then randomly chooses an uncovered parent and selects that parent's candidate with the same source-progress score.
- The experiment tests whether E-S gains remain after matching its broader parent coverage.
- The script checks exact FE accounting, mode allocation and parent cap.

## E-C comparison

`coverage_comparison.csv` compares the coverage-matched E-C runs with the existing same-seed E-S runs.

- E-S is better than E-C on 7/8 function means and 16/24 paired final-error runs.
- Mean parent coverage is matched closely (E-S 2.9301, E-C 2.9296), and mean concentration is also nearly identical (E-S 0.3489, E-C 0.3490).
- This supports a source-aware signal beyond the broader parent coverage observed in the original E-S versus E-G comparison.
- The result is still a development-stage causal ablation on eight repeatedly studied functions; it does not yet justify enabling Q-learning or claiming generalization.

