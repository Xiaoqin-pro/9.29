# HCLPSO source audit for the formal comparison (2026-10-13)

## Reference

- Reference implementation: NEORL `neorl/evolu/hclpso.py`.
- Repository: `https://github.com/mradaideh/neorl`.
- Pinned commit: `ebe03dcdb6def8c74e185300500841003ca49fbb`.
- Cited original paper: Lynn, N.; Suganthan, P. N. (2015), *Heterogeneous comprehensive learning particle swarm optimization with enhanced exploration and exploitation*, Swarm and Evolutionary Computation, 24, 11–24.
- Local source snapshot: `work/external/neorl_source_20261013/`.

## Preserved mechanics

- Two subpopulations: comprehensive-learning exploration group and cognitive/social exploitation group.
- Particle-wise learning probability `Pc` increasing across the population.
- Exemplar refresh after more than five unsuccessful updates.
- Time-varying inertia, constriction coefficient, cognitive coefficient, and social coefficient.
- Velocity limit at 20% of the variable range.
- Exploration group uses exemplar-guided movement; exploitation group uses exemplar plus global-best movement.

## Explicit adapter decisions

- The formal comparison uses `N=50`, `g1=20`, `g2=30` so all four algorithms share the same population size.
- The caller-provided initial population is preserved. The NEORL wrapper reinitializes positions internally after processing an optional `x0`; reproducing that wrapper behavior would break paired initialization.
- Every initialization and movement objective call is counted. The final generation is truncated at the remaining FE budget.
- Continuous variables are clipped to `[-100,100]` before objective evaluation.

The adapter is therefore an auditable CEC continuous reference profile, not a claim of bitwise reproduction of the Python runtime.

---
**2026-10-13核验后更正**：本文件是首次NEORL移植计划的历史记录，不再定义正式HCLPSO身份。正式列已改用作者MATLAB源码profile，并完成32组逐点/RNG核验、29函数30种子870次补跑。保留原Reference结果独立可追溯。见 `HCLPSO_AUTHOR_CORRECTION_20261013.md`。
