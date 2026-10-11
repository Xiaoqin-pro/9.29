# ASE-CSO B5 versus B10 pilot

D=30, CEC2017 F1 and F3-F30, 60,000 FE, seeds 101-103, four MATLAB workers.

- B5: frozen schedule, 5 FE per round, normally 2 Tracing + 3 Seeking.
- B10: experimental schedule, 10 FE per round, normally 4 Tracing + 6 Seeking.
- Both use the same Range Seeking, elite pool, virtual Tracing, real-state rollback and Global-Cap2 rules.
- The total FE budget is identical; B10 changes only the per-round evaluation density.

All 174 runs completed with status `ok`, exactly 60,000 evaluations, finite monotone traces and zero final-value recheck difference.

B10 is a speed candidate, not the frozen default: it is faster but changes the search trajectory and can regress on individual functions.
