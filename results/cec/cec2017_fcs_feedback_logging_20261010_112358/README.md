# FCS feedback logging pilot

- D=30, 60,000 FE, eight diagnostic functions, seeds 161:163, four workers.
- Frozen D3 kernel: Range Seeking, Global-Cap2, tracing decay, virtual tracing and rollback; no RL or Recovery.
- Logging only: no candidate-selection rule, random stream, FE allocation or trajectory is changed.
- Each event records the parent, within-round ordinal, trusted anchor cost, parent-relative success and marginal gain.
- Ordinal 2 is the observed same-parent second evaluation under the static D3 plan; this is diagnostic evidence, not a causal Continue/Switch comparison.
- The paired 6,000-FE audit passed with identical Best and T trajectories with logging disabled/enabled.

