# ASE-CSO Lean Fast

`ASE_CSO_Lean_Fast.m` keeps the frozen ASE-CSO equations and random-call order while removing avoidable hot-loop allocations. It is intended for regression testing before any default replacement.

The current frozen implementation remains `ASE_CSO_Lean.m`.
