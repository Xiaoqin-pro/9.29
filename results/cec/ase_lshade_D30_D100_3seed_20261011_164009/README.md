# ASE-CSO versus standard L-SHADE at D30 and D100

D=30 and D=100, 60,000 FE, CEC2017 F1 and F3-F30, seeds 101-103, four MATLAB workers. ASE-CSO uses NP=50 and the trajectory-equivalent lean implementation. L-SHADE uses the standard profile: NP0=18D, NPmin=4, archive ratio 2.6 and memory size 6. All runs use the same function data, bounds, FE budget and seed schedule within each dimension.

Generated tables:
- summary.csv: per-dimension/function/method mean, median, standard deviation, checkpoints and runtime.
- pairwise_comparison.csv: 3-seed paired wins and differences.
- seed_comparison.csv: final error for each dimension/function/seed.
- overall_summary.csv: function wins, ranks and runtime.
