# ASE-CSO B10 Cognitive

This experimental variant keeps the B10 evaluation-density schedule and adds a conservative PSO/CSO cognitive component in Tracing:

`0.8 * rand .* (personalBest(i,:) - pop(i,:))`

The existing elite social direction remains unchanged. The variant is intended for paired quality experiments and is not the default implementation.
