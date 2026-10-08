# CEC2017 V4 action and recovery comparison

This development run evaluates the separate `modeAwareV4` design on F3, F5, F13, F15, F19 and F30 with three seeds per function. The protocol remains D=30, population=50, 300000 total FE, shared initial populations and shared search seeds. Four local workers were used.

V4 removes the Gaussian A4 action from the Q action set. Q-learning chooses only three MR values (0.2, 0.4 and 0.6) with the same Seeking parameters. When the search has stalled for at least ten rounds, one Gaussian recovery evaluation is made from the current best and charged to the current round budget. The recovery step does not increase the total FE.

The comparison contains:
- `V4-MAQL`: Q-learning scheduler.
- `V4-Random`: uniformly random three-action scheduler.
- `V4-EpsFixed`: the same epsilon schedule, exploiting fixed MR=0.4.

All 54 runs reached 300000 FE. MAQL beats Random on 4/6 function means and beats EpsFixed on 4/6 function means. Its action proportions are close to one third rather than collapsing to a single action, so the action set is no longer equivalent to the old Gaussian A4 baseline. The absolute results on F3 and F5 are worse than the earlier V3/V3.2 candidates, so this is a mechanism validation and not a replacement for the frozen candidate yet.

Files:
- `raw_runs.csv`: one record per run.
- `histories/`: saved Best, convergence history and diagnostics.
- `summary.csv`: mean and standard deviation by function and variant.
- `comparison.csv`: paired MAQL, Random and EpsFixed comparison.
- `diagnostics.csv`: action and recovery statistics.
- `v4_results.mat`: MATLAB copy of raw and summary tables.
