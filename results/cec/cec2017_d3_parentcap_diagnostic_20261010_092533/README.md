# D3 parent-cap diagnostic

- D30, 60,000 FE, F3/F6/F9/F12/F13/F20/F28/F30, seeds 141:145, four workers.
- D3-GlobalCap2 is the existing baseline; D3-GlobalCap1 changes only the Seeking parent cap from 2 to 1.
- Both variants use frozen D3 dynamics, Range Seeking, Global 2-near + 1-far candidate ranking, 2 Tracing + 3 Seeking FE, no RL and no Recovery.
- This diagnostic tests whether the three Seeking evaluations should cover three different parents.

## Result summary

- Cap1 covers exactly 3 Seeking parents per round, with mean concentration 0.333 and maximum parent evaluations 1. Cap2 covers 2.176 parents per round on average, with concentration 0.517.
- By function mean error, Cap1 wins 2/8 functions and Cap2 wins 6/8.
- Across the 40 paired function-seed comparisons, Cap1 wins 15 and Cap2 wins 25; there are no ties.
- Mean wall time is 9.66 s for Cap1 and 9.90 s for Cap2, a small implementation-level reduction that does not compensate for the quality loss.

The result does not support forcing all three Seeking evaluations onto different parents as a general improvement. The parent-cap change is therefore closed as a primary mechanism; no HSS or Q-learning branch is started from it.
