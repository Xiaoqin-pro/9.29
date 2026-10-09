# Source-aware candidate family generalization at 60k FE

- Functions: F4, F5, F7, F8, F11, F17, F23 and F25.
- Repeats: 81:85; D=30; population=50; 60,000 FE.
- All runs use Range Seeking, Seeking elite guidance, tracing decay, virtual tracing with rollback, MR=0.4, SMP=5, 2 Tracing + 3 Seeking FE, no Recovery and no RL.
- E-G: standard Global-Cap2 (2 near-gbest + 1 far-center).
- E-C: coverage-matched source control; it follows the E-S shadow coverage state but randomly chooses the third parent, then uses that parent's source-progress candidate.
- E-S: 1 near-gbest + 1 source-aware candidate + 1 far-center.
- The script checks exact FE accounting, mode allocation and parent cap.

## Generalization comparison

`family_comparison.csv` reports the same-seed comparison on the eight new functions.

- E-S versus E-G: 6/8 function means and 26/40 paired runs favor E-S.
- E-S versus coverage-matched E-C: 4/8 function means and 22/40 paired runs favor E-S.
- E-C and E-S have the same mean rank (1.75) on this small extension set.
- The source-aware signal therefore remains promising on the original diagnostic set, but does not show a stable independent generalization gain here. Q-learning is not enabled.

