# ASE-CSO runtime implementation

`ASE_CSO.m` remains the reference implementation used by the historical experiments. `ASE_CSO_Lean.m` keeps the same search arithmetic, random-call order, FE allocation, candidate ranking, and state updates while using a smaller runtime path.

The runtime version follows the simple structure used by the teacher's MATLAB code:

- one readable main loop;
- small helpers with one responsibility;
- preallocated arrays in the repeated loop;
- no per-round diagnostic history in the hot path.

It does not change the optimization rule. The diagnostics retained in the returned `info` structure are the scalar totals needed by the runtime runner. Use `ASE_CSO.m` when per-round diagnostic vectors are required.

## Verification

The following checks were run with MATLAB R2025b:

- D10 synthetic objective, 6,000 FE: final best, full convergence vector, FE totals, and mode totals exactly match `ASE_CSO.m`.
- CEC2017 F9, D30 and D100, 6,000 FE: final best and full convergence vector exactly match `ASE_CSO.m`.
- CEC2017 F9, D30, 60,000 FE: three paired runs gave identical final results and an average wall-clock reduction of about 6.8% in the local test.

The timing result is hardware- and MATLAB-version-dependent; it is a runtime measurement, not an algorithmic quality claim.
