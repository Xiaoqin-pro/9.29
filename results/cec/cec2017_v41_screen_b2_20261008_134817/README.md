# B2 candidate-only screening ablation

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, 3 seeds, fixed MR=0.4, no Recovery, and 5 real evaluations per round.

`B2-CandidateScreen` uses random cat selection, then applies the DSS near-best/far-center selection to the two Seeking candidates. It complements the existing fair-screening configurations:

- B0 `NoScreen`: random cats and random two candidates.
- B1 `SS-CSO`: space-screened cats and random two candidates.
- B3 `DSS-CSO`: space-screened cats and space-screened candidates.

## Mean error

| Function | B2 CandidateScreen |
|---|---:|
| F03 | 97652.33 |
| F05 | 277.25 |
| F13 | 247761425.41 |
| F15 | 44026027.17 |
| F19 | 91325189.87 |
| F30 | 46040421.70 |

Candidate-level screening without effective cat-level screening is poor on this development set. Together with B0/B1/B3, this supports a conditional interpretation: the second layer is useful after the first layer has concentrated evaluations on promising cats; it is not a generally effective stand-alone selector.
