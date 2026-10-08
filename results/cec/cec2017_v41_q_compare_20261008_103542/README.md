# V4.1 CEC2017 development ablation

This archive contains the V4.1 structure-correction experiments on F3, F5, F13, F15, F19 and F30, with D=30, population=50, 300000 total FE and three paired seeds. All runs used four local workers.

V4.1 inherits V3.2 mode-preserving allocation, uses three MR actions (0.2, 0.4, 0.6), and separates Recovery from the Q reward. Interval Recovery is enabled at stall 10 and then every 20 stall rounds.

Configurations:
- `V4.1-Q-NoRecovery`: 27-state MAQL, no Recovery.
- `V4.1-Q-IntervalRecovery`: 27-state MAQL, interval Recovery.
- `V4.1-Random-Interval`: random three-action scheduler, interval Recovery.
- `V4.1-EpsFixed-Interval`: epsilon exploration with fixed MR=0.4, interval Recovery.
- `V4.1-Random-NoRecovery` and `V4.1-EpsFixed-NoRecovery`: same baselines without Recovery, for paired no-Recovery comparison.
- `V4.1-Q-9State-NoRecovery`: Q-learning without the mode-success state component.

Structural checks passed for every run: total FE reached 300000, mode allocation error was zero, and total round budget was filled. Interval Recovery used about 4.9% of rounds and 1% of non-initialization FE.

The results do not yet support claiming a universal MAQL advantage. Under no Recovery, Q beats Random on 5/6 function means and has a lower overall mean error than Random in this development subset, while fixed MR=0.4 remains slightly better overall. Under interval Recovery, Q also wins Random on 3/6 means but is usually behind fixed MR=0.4. The 9-state comparison improves some functions but has a worse overall mean due to F30. These are development diagnostics, not formal CEC2017 results.

Only CSV and README files are intended for repository upload. MATLAB `.mat` histories remain local.
