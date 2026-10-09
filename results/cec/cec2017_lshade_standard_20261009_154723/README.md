# Standard L-SHADE validation at 60k FE

- Functions: all CEC2017 functions except F2 (29 functions).
- Dimension: D=30; initial population: 18D=540; minimum population: 4.
- Archive rate: 2.6; historical memory size: 6; p-best rate: 0.11.
- Budget: 60,000 FE; repeats: 41:45.
- The first 50 initial points reuse the same random stream as the CSO runs; 490 additional points are generated afterward.
- The first six functions were used for the protocol pilot; all 29 functions are rerun here under the same standard configuration.

## Result summary

All 145 standard L-SHADE runs completed with exact 60,000 FE accounting. `standard_comparison.csv` combines these rows with the already completed D3, D1 and CLPSO runs using the same functions and seeds.

- D3 vs standard L-SHADE: 2/29 function-mean wins.
- D3 vs D1: 15/29 function-mean wins.
- D3 vs CLPSO: 28/29 function-mean wins.
- Mean rank: standard L-SHADE 1.14, D3 2.45, D1 2.62, CLPSO 3.79.

The standard L-SHADE configuration is materially stronger than the N=50 adaptation used in the earlier screen. Therefore the earlier D3-versus-L-SHADE comparison must not be used as a formal baseline claim. D3 remains a strong 60k CSO/CLPSO result, but it is not competitive with standard L-SHADE on most functions.

