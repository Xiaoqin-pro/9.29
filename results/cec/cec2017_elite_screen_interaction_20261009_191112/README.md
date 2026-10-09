# Seeking elite guidance x candidate screening interaction at 60k FE

- Functions: F3, F6, F9, F12, F13, F20, F28 and F30.
- Repeats: 61:63; D=30; population=50; 60,000 FE.
- All variants use Range Seeking, tracing decay, virtual tracing with rollback, MR=0.4, SMP=5, 2 Tracing + 3 Seeking FE, no Recovery and no RL.
- E-G: Seeking elite guidance enabled + Global-Cap2.
- E-R: Seeking elite guidance enabled + Matched-Random.
- N-G: Seeking elite guidance disabled (Tracing elite guidance remains enabled) + Global-Cap2.
- N-R: Seeking elite guidance disabled + Matched-Random.
- The independent `seekingEliteGuidance` switch isolates Seeking guidance from Tracing guidance.
- Feedback logs include selected-candidate distances to round-start gbest and sampled elite; no extra Fitness evaluations are used.


## Interaction analysis

`interaction_comparison.csv` reports per-function means, paired wins and the predeclared log interaction
`I = [log10(1+E-G)-log10(1+N-G)] - [log10(1+E-R)-log10(1+N-R)]`.

- E-G vs N-G: E wins 5/8 function means and 15/24 paired runs.
- E-R vs N-R: E wins 6/8 function means and 18/24 paired runs.
- E-G vs E-R: E-G wins 3/8 function means and 10/24 paired runs.
- N-G vs N-R: N-G wins 5/8 function means and 13/24 paired runs.
- The interaction is positive on 6/8 functions and has mean 0.2049, but is negative on F3 and F6. This supports a possible geometry-specific reduction in the value of Seeking elite guidance, not a universal conflict claim.
- Selected-candidate distance logs show that E-G candidates are closer to gbest than E-R candidates on average; the logged distances are spatial diagnostics, not true-fitness evidence for unevaluated candidates.
