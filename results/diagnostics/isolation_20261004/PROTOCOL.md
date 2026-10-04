PSO protocol: 30 positions, FE3000 including initialization, 5 seeds per case.
Full: repository PSO/Fitness unchanged, peaks x N10/N15/N20 x width12/45.
RouteOnly: only N keys, .03 initial key velocity, full original pbest/gbest update; travel direct XYZ; same waiting/time objective and hard depot deadline; no geometry constraints or controls.
ControlOnly: fixed archived route ONLY, 126 rand controls, .01 velocity, identical PSO pbest/gbest and FE loop; no archived controls injected; time windows disabled ONLY in diagnostic model; geometry cost identical to original Fitness when wait/late=0.
All scalar penalties, Vmax=.15, c1=c2=1.5, w=.9-.5*(FE-P)/(budget-P) retained. ControlOnly dimension restriction is diagnostic, not fair algorithm ranking.
An external derivative of PSO is compared exactly to original in Full mode; additional route-change counters make no random calls and no extra objective evaluations.
