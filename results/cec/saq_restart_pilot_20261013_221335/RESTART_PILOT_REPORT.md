# SAQ Partial Restart Pilot Results

Settings: D=50, 100,000 true FE, 8 diagnostic functions, 10 seeds per condition, four MATLAB workers. All 320 runs in the cooldown-gated batch passed FE, finite-trace and Best recheck validation.

## Comparison

| Comparison | Function mean wins | Function mean losses | Seed wins | Seed losses |
|---|---:|---:|---:|---:|
|Fixed-Restart vs Sparse-Base|6|2|31|37|
|Random-Restart vs Sparse-Base|6|2|38|30|
|Q-Restart vs Sparse-Base|3|5|39|41|
|QReward vs Sparse-Base|3|5|40|40|
|QReward vs Fixed-Restart|4|4|43|37|

## Interpretation

- Cooldown-gated fixed restart improves the function mean on 6/8 diagnostic functions, but has a large F30 degradation and does not win the pooled paired seeds.
- Q-Restart wins 3/8 function means against the matched sparse baseline. The corrected reward includes parent-level restart improvements, but Q still has no stable extra value over the fixed rule.
- Random-Restart also wins 6/8 function means, so the current data do not prove that Q is better than a simple trigger.
- Restart candidates usually improve local parents rather than immediately updating gbest. This explains why a pure gbest reward was insufficient.

Partial Restart remains a candidate mechanism. Q should remain exploratory unless a separate pre-registered state/reward test shows stable gain.
