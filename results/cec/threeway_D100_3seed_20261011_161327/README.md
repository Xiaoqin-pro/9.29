# Three-algorithm CEC2017 D100 comparison

D=100, 60,000 FE, functions F1 and F3-F30, seeds 101-103, four MATLAB workers. ASE-CSO and CLPSO use NP=50. Paper-aligned NRLPSO uses NP=40 and receives the shared 40-point prefix of each 50-point initial population. ASE-CSO uses the trajectory-equivalent lean runtime implementation. NRLPSO is a paper-aligned independent reproduction, not an official author release.

`raw_runs.csv` is written after every batch and contains one row per run. Summary tables are generated after completion.

Generated tables:
- summary.csv: function/method mean, median, standard deviation, extrema, runtime and audit metrics.
- pairwise_comparison.csv: all three method pairs with 3-seed wins/losses and paired differences.
- seed_comparison.csv: one row per function and seed with all final errors and the best method.
- overall_summary.csv: function wins, average rank, runtime and valid-run counts.
