# ASE-CSO B10

`ASE_CSO_Lean_B10.m` is an experimental evaluation-density variant. It keeps the total FE budget and search equations, but uses 10 evaluations per full round (4 Tracing + 6 Seeking) instead of the frozen 5-FE schedule.

It is not the default implementation. Use it only with the paired pilot results and compare quality and runtime together.
