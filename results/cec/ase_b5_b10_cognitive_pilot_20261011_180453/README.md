# B10 cognitive tracing pilot

D=30, CEC2017 F1, F3, F6, F9, F12 and F22, 60,000 FE, seeds 101-103, four MATLAB workers.

- B5: frozen 5-FE-per-round ASE-CSO.
- B10: 10 FE per round, normally 4 Tracing + 6 Seeking.
- B10-Cognitive: B10 plus a small PSO/CSO-style cognitive Tracing term toward each cat's real personal best. Seeking, screening, rollback and total FE are unchanged.

All 54 runs completed with status `ok`, exactly 60,000 evaluations and zero final-value recheck difference. B10-Cognitive is a quality candidate, not a frozen default.
