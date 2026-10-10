# D3 hierarchy diagnostic

- Functions: F3, F6, F9, F12, F13, F20, F28, F30; D=30; 60,000 FE; five paired seeds 141:145.
- Variants: D3-G (Global-Cap2), D3-DSS-Old (legacy parent shortlist plus sequential per-parent selection), and D3-DSS-Joint (two-parent shortlist followed by joint Global-Cap2 selection).
- All variants use frozen D3 search dynamics, Range Seeking, 2 Tracing + 3 Seeking evaluations, no RL and no Recovery.
- `comparison.csv` reports function means and paired wins. This is a mechanism diagnostic, not a final 29-function validation.

The K=8 shadow audit found exact equality with Global-Cap2 on all audited rounds; it is therefore omitted as a redundant performance variant.

## Result summary

- By function mean error, D3-G wins 4/8 against D3-DSS-Old and 5/8 against D3-DSS-Joint. D3-DSS-Joint wins 3/8 against D3-DSS-Old.
- Across the 40 paired function-seed runs, D3-G wins 25 against D3-DSS-Old and 24 against D3-DSS-Joint. D3-DSS-Joint wins 21 against D3-DSS-Old.
- Mean wall time per run is 10.18 s for D3-G, 10.55 s for D3-DSS-Old, and 10.66 s for D3-DSS-Joint. The shortlist variants did not yet show a runtime advantage in this implementation.
- The Joint variant is therefore a useful diagnostic, not a confirmed replacement for Global-Cap2. These results do not justify adding Q-learning or tuning the shortlist size yet.
