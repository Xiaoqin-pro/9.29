# B10 quality candidate pilot

This pilot keeps B10 fixed at 10 real evaluations per round (4 Tracing and 6
Seeking), Range bounds, the trusted real-position anchor and the existing
Global-Cap2 parent limit. It changes only the Seeking candidate pool and its
selection policy.

Candidate sources are: cognitive pull to the cat's real personal best, social
pull to a sampled elite personal best, a coordinate-wise real-personal-best
exemplar, and Range exploration.

`geometry` uses the existing near-best/far-centre ordering. `random` samples
the same eligible pool under the same parent cap. `reserved` reserves one Range
candidate and uses geometry for the remaining slots. `credit` reserves one
Range candidate and orders the remaining candidates using source credit from
previous real improvements, followed by the existing geometric tie-breaks.

This is a development pilot, not a final claim. All runs must have exactly
60,000 objective calls, finite non-increasing convergence, and zero final-best
recheck error.
