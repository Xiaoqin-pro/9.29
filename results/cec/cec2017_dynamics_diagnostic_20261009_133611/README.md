# V1 dynamics diagnostic at 60k FE

This experiment separates Tracing velocity decay from virtual movement of unevaluated Tracing cats.

- D1-TracingDecay: V1 with Tracing inertia decreasing from 0.9 to 0.4.
- D2-VirtualTracing: V1 with virtual movement for Tracing cats that receive no real evaluation.
- D3-Both: both changes enabled.
- V1-Reference is run only on F6 because the other reference rows are already available for the same seeds.

All runs use D=30, population=50, 60,000 FE, Range Seeking, Global-Cap2, MR=0.4, SMP=5, no Recovery, and paired seeds 21:23 on F1, F3, F6, F9, F12 and F22.

The script checks exact FE accounting and the 2 Tracing + 3 Seeking allocation for every run.

## Result summary

The first implementation allowed a rejected virtual Tracing position to remain in `pop` while its real fitness cache was retained. The implementation was corrected so that a virtual position is kept only until its next real evaluation; a rejected real trial rolls back to the last real position. The results in this directory are from the corrected implementation.

Relative to the matched 60k V1 reference, the paired wins are:

- D1-TracingDecay: 14/18
- D2-VirtualTracing: 7/18
- D3-Both: 18/18

D3 has the lowest mean error on all six diagnostic functions in this small development screen. D2 alone is not supported: after the state-consistency fix it remains worse than the reference on most functions. D3 is promising, but this is still a six-function, three-seed development result and must be checked on fresh functions and seeds before it becomes the default algorithm.

`dynamics_comparison.csv` contains the per-function means, standard deviations, runtime and paired wins against the V1 reference.

