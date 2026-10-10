# Detailed ASE-CSO / CLPSO / NRLPSO comparison

## Protocol

- CEC2017 functions: F1 and F3-F30 (29 functions; F2 excluded)
- Dimension: 30
- Counted budget: 60,000 objective evaluations per run
- Seeds: 101-110 (10 runs per function)
- MATLAB: 4 local workers
- ASE-CSO and CLPSO: NP=50
- NRLPSO-PaperAligned: NP=40, k=8, c2=1.9
- Initial populations: one NP=50 pool per function-seed; NRLPSO receives its shared 40-point prefix

The NRLPSO condition is a paper-aligned independent reproduction, not an official author implementation. Different NP values are retained because they follow the declared baseline protocols; this is FE-matched and prefix-shared, not an identical-population comparison.

## Files

- `detailed_raw_runs.csv`: 870 rows, one row per algorithm/function/seed run, including final and checkpoint errors, runtime, FE/objective-call audits, Best recheck, and NRLPSO mutation/Q diagnostics.
- `detailed_summary_by_function.csv`: per-function mean, median, standard deviation, runtime, and rank columns.
- `method_overall_summary.csv`: overall runtime and error summaries.
- `pairwise_comparison.csv`: function-mean and paired-seed win counts.
- `nrlpso_mechanism_by_function.csv`: mutation fraction, out-of-bound mutation count, action counts, inertia, and learning-rate diagnostics.
- `audit_checks.csv`: independent objective-call, trace, and Best consistency checks.

Every one of the 870 rows is `ok`; all runs reached 60,000 evaluations, had 60,000 counted objective calls plus one excluded post-run Best recheck, finite monotone traces, and a consistent Best re-evaluation.

The NRLPSO source fixes the global mutation branch by comparing against the pre-mutation global-best cost. Its independent objective counter is implemented through `CountingObjective` and is separate from the algorithm's internal FE counter.
