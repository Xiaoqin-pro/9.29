# Seeking candidate generation comparison

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, 3 seeds, 4 MATLAB workers. Both variants use the same initial populations, search seeds, fixed MR=0.4, no Recovery, and DSS screening.

- `DSS-ClassicSeeking`: traditional coordinate-multiplicative CSO Seeking perturbation.
- `DSS-RangeSeeking`: selected coordinates use a range-normalized additive perturbation
  `x + SRD*(ub-lb)/2*(1-progress)*(2*r-1)`.

## Mean error

| Function | ClassicSeeking | RangeSeeking |
|---|---:|---:|
| F03 | 11683.33 | 6928.88 |
| F05 | 175.26 | 193.57 |
| F13 | 31320.85 | 35056.70 |
| F15 | 19049.60 | 14135.84 |
| F19 | 13779.08 | 2364.51 |
| F30 | 18480.38 | 19873.41 |

Range-normalized Seeking improves F03, F15 and F19, but degrades F05, F13 and F30. It also increases mean runtime. The result is therefore a useful mechanism diagnostic, not evidence to replace the frozen default formula. The formal algorithm remains on `classic` Seeking until a separate, pre-specified validation supports a change.
