# Standard L-SHADE versus D3 at D100, 60k FE

- Functions: F1, F3-F30 (29 functions); dimension: 100; budget: 60,000 FE.
- Repeats: 101:103; L-SHADE uses independent NP0=18D=1800 initial points because its standard population protocol differs from D3.
- Standard profile: NPmin=4, archive rate=2.6, memory size H=6, p-best rate=0.11.
- Initialization evaluations are included in the 60,000 FE budget.
- `comparison.csv` pairs L-SHADE with the existing D3 runs by function and repeat ID; it is a quality comparison under the same FE budget, not identical initialization.
- This is a D100 standard-baseline pretest, not a formal 30-run statistical validation.

## Result summary

- D3 has the lower function mean error on 14/29 functions; standard L-SHADE wins 15/29 (no ties).
- Paired over the 87 function-seed comparisons, D3 wins 40 and standard L-SHADE wins 47 (no ties).
- Mean rank is 1.517 for D3 and 1.483 for standard L-SHADE.
- Mean wall time is about 16.18 s for D3 and 3.91 s for standard L-SHADE in this MATLAB setup. This is a runtime comparison, not a claim about fitness-evaluation cost in an expensive application.

These results narrow the D100 claim: D3 remains a strong low-budget comparator to CLPSO, while standard L-SHADE is slightly stronger overall in this 60,000-FE pretest. They do not establish a universal advantage for D3 or for virtual Tracing over D1.

