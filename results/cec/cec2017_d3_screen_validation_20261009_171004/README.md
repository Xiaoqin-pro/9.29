# D3 screening validation at 60k FE

- D=30, population=50, 60,000 FE, Range Seeking, MR=0.4, SMP=5.
- Seeds 41:45; four workers; no Recovery and no Q-learning.
- `D3-RandomCap2`: remaining 21 CEC functions; random Seeking candidates with the same parent cap.
- `D3-MatchedRandomCap2`: eight diagnostic functions; random candidate selection with the same per-round parent-count multiset as Global-Cap2.
- `D3-RandomCap2` and the matched control retain the same 2 Tracing + 3 Seeking FE allocation.
- The script asserts exact FE accounting, mode allocation, parent cap, and matched coverage/concentration.

## Results

`screen_comparison.csv` pairs each run with `D3-Both` from the unified D3 run using the same function and seed.

- Remaining 21-function Random-Cap2 comparison: D3 wins 13/21 function means; paired wins are 75 D3 versus 30 random.
- Eight-function Matched-Random comparison: D3 wins 5/8 function means; paired wins are 21 D3 versus 19 matched-random.
- These are development diagnostics, not final statistical claims. The random selector changes the stochastic path, so the comparison is not bitwise counterfactual.
- The matched result removes the main parent-coverage/concentration confound from the eight-function diagnostic comparison, but it still does not establish a universal geometric-screening advantage.
