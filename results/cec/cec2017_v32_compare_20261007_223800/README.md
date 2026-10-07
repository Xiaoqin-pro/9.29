# CEC2017 V3.2 mode-preserving opportunity comparison

This development run evaluates the independent `modeAwareV32` implementation on F3, F5, F13, F15, F19 and F30 with three seeds per function. It uses the same D=30, population=50, 300000-FE protocol and the same initial populations/search seeds as the V3/V3.1 comparison. Four local workers were used.

V3.2 allocates the round evaluation budget between Tracing and Seeking according to the selected action MR, then performs spatial screening only within each mode. This prevents the cross-mode min/max score from changing the Q-selected mode ratio. The run records both target and actual mode budgets.

All 18 runs completed. `BudgetFillRate` is 1.0 and `ModeAllocationError` is 0 for every run. The actual Tracing FE share equals the target share (mean 0.3844 across these runs).

The result is a structural validation, not a final algorithm freeze. V3.2 improves over V3 on F3, F5 and F30, but degrades on F13, F15 and F19. Relative to V3.1 it improves F13 and F15 but is worse on the other four functions. The next experiment should therefore test the separate V4 action/recovery redesign rather than mixing it into V3.2.

Files:
- `raw_runs.csv`: one record per run.
- `histories/`: saved Best, convergence history and diagnostics for all runs.
- `summary.csv`: V3.2 statistics by function.
- `comparison.csv`: V3, V3.1 and V3.2 error comparison.
- `diagnostics.csv`: mode allocation and action diagnostics.
- `v32_results.mat`: MATLAB copy of the raw and summary tables.
