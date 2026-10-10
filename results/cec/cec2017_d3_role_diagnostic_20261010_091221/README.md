# D3 K2-Role diagnostic

- D30, 60,000 FE, F3/F6/F9/F12/F13/F20/F28/F30, seeds 141:145, four workers.
- This version keeps the legacy two-parent shortlist, then guarantees one closest-gbest developer candidate and one farthest-center explorer candidate before selecting the third slot.
- D3 dynamics, Range Seeking, virtual Tracing, 2 Tracing + 3 Seeking FE, and parent cap 2 are unchanged.
- The experiment tests role consistency only; it does not introduce HSS pre-generation or RL.

## Result summary

- Role coverage is 100% for both the developer and explorer representative candidate slots.
- Against the existing 40 paired runs, D3-DSS-Role wins 21 and loses 19 against D3-DSS-Old; it wins 16 and loses 24 against D3-G.
- D3-DSS-Role and D3-DSS-Joint have identical final errors in 36/40 paired runs; the remaining four are split 2:2.
- Mean runtime is 12.59 s per run, compared with 10.55 s for D3-DSS-Old, 10.66 s for D3-DSS-Joint, and 10.18 s for D3-G.

The role guarantee is therefore correctly executed but does not provide an independent performance gain in this diagnostic. The HSS redesign, larger shortlist sweeps, and Q-learning remain gated rather than being started from this result.
