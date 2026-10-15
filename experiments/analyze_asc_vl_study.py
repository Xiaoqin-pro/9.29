"""Independent artifact audit and paired analysis of the B0/B1/B2 screen."""
from pathlib import Path
import argparse, hashlib, json, shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import wilcoxon, rankdata
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("run", type=Path)
args = p.parse_args()
run = args.run

cfg = json.loads((run / "config.json").read_text(encoding="utf8"))
status = json.loads((run / "status.json").read_text(encoding="utf8"))
assert status["Status"] == "complete" and status["Completed"] == cfg["FreshRuns"]
for h in pd.read_csv(run / "prelaunch_hashes.csv").itertuples():
    assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest() == h.SHA256

METHODS = ["B0", "B1", "B2"]
PAIRS = [("B1", "B0"), ("B2", "B0"), ("B2", "B1")]
PRIMARY = cfg["PrimaryFunctions"]
CROSS = cfg["CrossFunctions"]
BUDGET = cfg["Budget"]
N = cfg["Population"]

raw = pd.read_csv(run / "raw_runs.csv")
raw = raw.sort_values("JobID").reset_index(drop=True)
assert len(raw) == cfg["FreshRuns"], "unexpected number of run records"
assert raw.Status.eq("ok").all(), "a counted run failed"
assert raw.ObjectiveCalls.eq(BUDGET).all() and raw.Evaluations.eq(BUDGET).all()
assert raw.OutsideCalls.eq(0).all()
assert raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.Method) == set(METHODS)
assert set(raw.Seed) == set(cfg["Seeds"])
assert set(raw.FunctionID) == set(PRIMARY + CROSS)
assert not raw.duplicated(["FunctionID", "Seed", "Method"]).any()
assert raw.groupby(["FunctionID", "Seed"]).Method.nunique().eq(3).all()
assert raw.Population.eq(N).all() and raw.Dimension.eq(cfg["Dimension"]).all()
assert raw.EvalTrace.add(raw.EvalSeek).eq(BUDGET - N).all()
assert raw.EvalNear.add(raw.EvalFar).eq(BUDGET - N).all()
assert raw.ImpGlobalNear.add(raw.ImpGlobalFar).eq(raw.ImpGlobalTrace + raw.ImpGlobalSeek).all()
assert raw.ImpPbestNear.add(raw.ImpPbestFar).eq(raw.ImpPbestTrace + raw.ImpPbestSeek).all()
assert raw.GapN.eq(BUDGET - N).all() and raw.GapMax.ge(1).all()
assert (raw.JumpVictimRecovered <= raw.JumpVictims).all()
assert (raw.JumpVictimRecovered >= 0).all() and (raw.JumpVictims >= 0).all()

# per-run artifact audit: re-read every stored run and replay its own trace
checks = []
curves = []
node_fe = [50, 1000, 10000, 20000, 40000, 60000, 80000, 100000]
for row in raw.itertuples():
    art = run / "runs" / row.Artifact
    assert art.is_file(), f"missing artifact {art}"
    m = loadmat(art, variable_names=["T", "B", "job", "rec"], squeeze_me=True)
    T = np.asarray(m["T"], dtype=float).ravel()
    assert T.size == BUDGET, "stored trace length mismatch"
    assert np.all(np.diff(T) <= 0), "stored trace is not monotone"
    assert np.isclose(T[-1], row.FinalCost, rtol=1e-12, atol=1e-9)
    init_drops = int(np.sum(np.diff(T[:N]) < 0))
    assert row.ImpGlobalTrace + row.ImpGlobalSeek == int(np.sum(np.diff(T) < 0)) - init_drops
    checks.append(dict(FunctionID=row.FunctionID, Seed=row.Seed, Method=row.Method,
                       Passed=True, TraceMonotone=True, DiagnosticsConsistent=True))
    for fe in node_fe:
        curves.append(dict(FunctionID=row.FunctionID, Seed=row.Seed, Method=row.Method,
                           FE=fe, BestError=T[min(fe, BUDGET) - 1] - 100 * row.FunctionID))
    if len(checks) % 60 == 0:
        print("Artifact audit", len(checks), "/", len(raw), flush=True)

raw["Study"] = np.where(raw.FunctionID.isin(PRIMARY), "primary", "cross")
out = ROOT / "results/asc_verified_learning_10seed_20261015"
out.mkdir(parents=True, exist_ok=True)
(out / "source").mkdir(exist_ok=True)

means = raw.groupby(["FunctionID", "Method"]).FinalError.mean().unstack().reindex(columns=METHODS)
std = raw.groupby(["FunctionID", "Method"]).FinalError.std().unstack().reindex(columns=METHODS)
med = raw.groupby(["FunctionID", "Method"]).FinalError.median().unstack().reindex(columns=METHODS)
for name, d in [("function_means.csv", means), ("function_std.csv", std),
                ("function_medians.csv", med)]:
    d.to_csv(out / name)
means.rank(axis=1).mean().sort_values().rename("AverageRank").to_csv(out / "mean_ranks.csv")

detail, comp = [], []
for split, funcs in [("primary", PRIMARY), ("cross", CROSS), ("all", PRIMARY + CROSS)]:
    sub = means.loc[funcs]
    for method, ref in PAIRS:
        ratio = sub[method] / sub[ref]
        # paired seed counts must use the same function subset as the ratio
        sel = raw.FunctionID.isin(funcs)
        b = raw[sel & raw.Method.eq(ref)].set_index(["FunctionID", "Seed"]).FinalError
        a = raw[sel & raw.Method.eq(method)].set_index(
            ["FunctionID", "Seed"]).FinalError.reindex(b.index)
        delta = a - b
        comp.append(dict(Split=split, Method=method, Reference=ref,
                         MeanWins=int((ratio < 1).sum()), MeanLosses=int((ratio > 1).sum()),
                         MeanTies=int((ratio == 1).sum()),
                         SeedWins=int((delta < 0).sum()), SeedLosses=int((delta > 0).sum()),
                         SeedTies=int((delta == 0).sum()),
                         MedianMeanRatio=float(ratio.median()),
                         GeometricMeanRatio=float(np.exp(np.log(ratio).mean()))))
        if split == "all":
            continue
        for fid in funcs:
            z = raw[raw.FunctionID.eq(fid)].pivot(index="Seed", columns="Method",
                                                  values="FinalError")
            d = (z[method] - z[ref]).to_numpy()
            pv = 1.0 if np.all(d == 0) else float(wilcoxon(d, zero_method="wilcox",
                                                           method="auto").pvalue)
            nz = d[np.abs(d) > 0]
            rb = 0.0 if not len(nz) else float(np.sum(rankdata(np.abs(nz)) * np.sign(-nz))
                                              / np.sum(rankdata(np.abs(nz))))
            detail.append(dict(Split=split, FunctionID=int(fid), Method=method, Reference=ref,
                               MeanRatio=float(sub.loc[fid, method] / sub.loc[fid, ref]),
                               WilcoxonP=pv, RankBiserial=rb,
                               SeedWins=int((d < 0).sum()), SeedLosses=int((d > 0).sum()),
                               SeedTies=int((d == 0).sum())))

comp = pd.DataFrame(comp)
detail = pd.DataFrame(detail)
comp.to_csv(out / "comparisons.csv", index=False)
pv = detail.WilcoxonP.to_numpy()
adj = np.empty(len(pv))
running = 0.0
for k, i in enumerate(np.argsort(pv)):
    running = max(running, (len(pv) - k) * pv[i])
    adj[i] = min(1.0, running)
detail["Holm"] = adj
detail.to_csv(out / "function_comparisons.csv", index=False)


def gate(method, ref, split, min_wins, max_ratio, guard=None, guard_cap=1.10, hard_cap=1.20):
    row = comp[(comp.Method == method) & (comp.Reference == ref) & (comp.Split == split)].iloc[0]
    funcs = PRIMARY if split == "primary" else CROSS
    ratio = means.loc[funcs, method] / means.loc[funcs, ref]
    ok = bool(row.MeanWins >= min_wins and row.MedianMeanRatio <= max_ratio)
    if guard:
        ok = ok and bool((ratio.loc[guard] <= guard_cap).all())
    if split == "primary":
        ok = ok and bool((ratio <= hard_cap).all())
    return ok, row, ratio


p1, r1, ratio1 = gate("B1", "B0", "primary", 5, 0.95, guard=[6, 9])
p2, r2, ratio2 = gate("B2", "B0", "primary", 5, 0.95, guard=[6, 9])
c1, rc1, _ = gate("B1", "B0", "cross", 3, 1.00)
c2, rc2, _ = gate("B2", "B0", "cross", 3, 1.00)
d1, rd1, _ = gate("B2", "B1", "primary", 5, 1.00)
d2, rd2, _ = gate("B2", "B1", "cross", 3, 1.00)
checks_gate = dict(B1VsB0Primary=p1, B1VsB0Cross=c1, B2VsB0Primary=p2, B2VsB0Cross=c2,
                   B2VsB1ExtraValuePrimary=d1, B2VsB1ExtraValueCross=d2)
advance = dict(B1=bool(p1 and c1), B2=bool(p2 and c2 and d1))
gate_decision = dict(
    Passed=bool(any(advance.values())), Advance=advance, GateChecks=checks_gate,
    PrimaryFunctions=PRIMARY, CrossFunctions=CROSS,
    FreshRuns=len(raw), OptimizationCalls=int(raw.ObjectiveCalls.sum()),
    AuditCalls=int(raw.PostRunRecheckCalls.sum()),
    ValidationObjectiveCalls=json.loads((run / "validation.json").read_text(encoding="utf8"))["ValidationObjectiveCalls"],
    PreflightObjectiveCalls=json.loads((run / "preflight.json").read_text(encoding="utf8"))["ObjectiveCalls"],
    NewSeedReplicates=True, UnseenFunctions=False, SeedRange=[min(cfg["Seeds"]), max(cfg["Seeds"])],
    F6F9Guard=bool((ratio1.loc[[6, 9]] <= 1.10).all() and (ratio2.loc[[6, 9]] <= 1.10).all()),
    MinPossibleP=2.0 / (2 ** 10),
    HolmFirstCutoff=0.05 / len(detail),
    SignificantFunctionTests=int((detail.Holm < 0.05).sum()),
    Comparisons=comp.to_dict("records"))
(out / "gate_decision.json").write_text(
    json.dumps(gate_decision, ensure_ascii=False, indent=2), encoding="utf8")

# ---------------- diagnostics ----------------
diag_cols = ["EvalTrace", "EvalSeek", "EvalNear", "EvalFar", "ImpPbestTrace", "ImpPbestSeek",
             "ImpPbestNear", "ImpPbestFar", "ImpGlobalTrace", "ImpGlobalSeek",
             "ImpGlobalNear", "ImpGlobalFar", "GapSum", "GapN", "GapMax", "JumpEvents",
             "JumpStallSum", "JumpVictims", "JumpVictimRecovered", "MeanEvalGap"]
diag = raw[["FunctionID", "Seed", "Method", "Study"] + diag_cols].copy()
diag["PbestRateTrace"] = diag.ImpPbestTrace / diag.EvalTrace.replace(0, np.nan)
diag["PbestRateSeek"] = diag.ImpPbestSeek / diag.EvalSeek.replace(0, np.nan)
diag["GlobalRateTrace"] = diag.ImpGlobalTrace / diag.EvalTrace.replace(0, np.nan)
diag["GlobalRateSeek"] = diag.ImpGlobalSeek / diag.EvalSeek.replace(0, np.nan)
diag["PbestRateNear"] = diag.ImpPbestNear / diag.EvalNear.replace(0, np.nan)
diag["PbestRateFar"] = diag.ImpPbestFar / diag.EvalFar.replace(0, np.nan)
diag["GlobalRateNear"] = diag.ImpGlobalNear / diag.EvalNear.replace(0, np.nan)
diag["GlobalRateFar"] = diag.ImpGlobalFar / diag.EvalFar.replace(0, np.nan)
diag["JumpRecoveryRate"] = diag.JumpVictimRecovered / diag.JumpVictims.replace(0, np.nan)
diag.to_csv(out / "diagnostics_runs.csv", index=False)
diag.groupby("Method")[["EvalTrace", "EvalSeek", "EvalNear", "EvalFar", "ImpPbestTrace",
                        "ImpPbestSeek", "ImpPbestNear", "ImpPbestFar", "ImpGlobalTrace",
                        "ImpGlobalSeek", "ImpGlobalNear", "ImpGlobalFar", "PbestRateTrace",
                        "PbestRateSeek", "GlobalRateTrace", "GlobalRateSeek", "PbestRateNear",
                        "PbestRateFar", "GlobalRateNear", "GlobalRateFar", "MeanEvalGap",
                        "GapMax", "JumpEvents", "JumpStallSum", "JumpVictims",
                        "JumpVictimRecovered", "JumpRecoveryRate"]].mean().to_csv(
    out / "diagnostics_summary.csv")
diag.groupby(["FunctionID", "Study", "Method"])[
    ["PbestRateTrace", "PbestRateSeek", "GlobalRateTrace", "GlobalRateSeek",
     "PbestRateNear", "PbestRateFar", "MeanEvalGap", "JumpRecoveryRate"]].mean().to_csv(
    out / "diagnostics_by_function.csv")

# ---------------- convergence figure ----------------
cur = pd.DataFrame(curves)
cur.to_csv(out / "convergence_nodes.csv", index=False)
fids = PRIMARY + CROSS
fig, axes = plt.subplots(3, 4, figsize=(19, 11))
for ax, fid in zip(axes.ravel(), fids):
    d = cur[cur.FunctionID.eq(fid)]
    for method, style in zip(METHODS, ["-", "--", ":"]):
        g = d[d.Method.eq(method)].groupby("FE").BestError.mean()
        ax.plot(g.index, np.maximum(g.to_numpy(), 1e-12), style, marker="o",
                markersize=3.5, linewidth=1.6, label=method)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_title(f"F{fid}", fontsize=11)
    ax.grid(alpha=0.3, which="both", linewidth=0.4)
    ax.tick_params(labelsize=8)
axes.ravel()[0].legend(fontsize=8)
fig.suptitle("ASC verified-exemplar learning: mean best-so-far error "
             "(10 seeds, 100k real evaluations)", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.97])
for ext in ["png", "pdf"]:
    fig.savefig(out / f"convergence.{ext}", dpi=180, bbox_inches="tight")
plt.close(fig)

for name in ["config.json", "validation.json", "checks.csv", "PROTOCOL.md",
             "preflight.json", "prelaunch_hashes.csv", "vl_tracing_fixture.m"]:
    shutil.copyfile(run / name, out / name)
for name in ["ASC_NoFarness.m", "ASC_NoFarness_VerifiedLearning.m", "run_asc_vl_job.m",
             "run_asc_vl_study.m", "test_ASC_NoFarness_VerifiedLearning.m"]:
    shutil.copyfile(run / "source" / name, out / "source" / name)
pd.DataFrame(checks).to_csv(out / "integrity_checks.csv", index=False)
raw.to_csv(out / "all_runs.csv", index=False)

summary = dict(OptimizationCalls=int(raw.ObjectiveCalls.sum()),
               AuditCalls=int(raw.PostRunRecheckCalls.sum()),
               Runs=len(raw), ValidationObjectiveCalls=gate_decision["ValidationObjectiveCalls"],
               PreflightObjectiveCalls=gate_decision["PreflightObjectiveCalls"])
(out / "analysis_summary.json").write_text(
    json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf8")
print(comp.to_string(index=False))
print(means.round(4).to_string())
print(json.dumps(gate_decision, ensure_ascii=False, indent=2)[:1500])
print(out)
