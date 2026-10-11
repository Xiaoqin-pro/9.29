# TPL-CSO pilot

This pilot tests a compact, evaluation-consistent candidate ledger on top of
the B10 evaluation schedule. It is deliberately separate from the historical
D3/B10 files.

## Variants

- `B10-Reference`: existing `ASE_CSO_Lean_B10` implementation.
- `TPL-Fixed`: proposal ledger with a balanced exploitation/coverage score.
- `TPL-Random`: same proposal ledger and FE schedule, random proposal choice.
- `TPL-Q`: the same ledger with an 8-state, 2-action Q table.

The ledger keeps trusted real positions (`realPop`, `fitness`) separate from
unevaluated proposals. Proposals expire after two rounds and receive credit
only from their own real evaluation.

## Pilot scope

Eight functions (`F3,F6,F9,F12,F13,F22,F28,F30`), five paired seeds
(`201:205`), 60,000 FE, B10's four Tracing plus six Seeking evaluations per
round, and four parallel workers. The script writes `raw_runs.csv` after each
batch so interrupted runs remain usable.

The pilot is a mechanism screen, not a final CEC result. The Q branch is kept
only if it beats the fixed ledger on both mean performance and paired wins;
otherwise the fixed ledger remains the simpler candidate.
