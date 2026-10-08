# V4.1 fixed MR development comparison

This run compares the V4.1 mode-preserving, no-Recovery protocol with three deterministic MR schedules on F3, F5, F13, F15, F19 and F30. Each variant uses the same D=30, population=50, 300000 FE budget, initial population, search seed and three repeats. Four workers were used.

Variants:
- `Fixed-MR0.2`: every round uses MR=0.2.
- `Fixed-MR0.4`: every round uses MR=0.4.
- `Fixed-MR0.6`: every round uses MR=0.6.

The Q no-Recovery records from the paired V4.1 run are included in `comparison.csv` for direct diagnosis. Q is better than Random on 5/6 function means, but the fixed schedules show that this does not establish a Q-learning advantage: Fixed-MR0.4 has the lowest overall mean error among the compared schedules in this development subset. The per-function ranking is mixed, so no fixed ratio is being selected as a final algorithm parameter.

Only CSV and README files are intended for repository upload. MATLAB `.mat` histories remain local.
