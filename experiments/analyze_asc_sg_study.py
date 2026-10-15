"""Independent artifact audit and paired analysis of the starvation-guard 2x2."""
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

METHODS = ["G00", "G01", "G10", "G11"]
SPEC = cfg["MethodSpec"]
PAIRS = [("G10", "G00"), ("G01", "G00"), ("G11", "G01"), ("G11", "G00")]
PRIMARY, CROSS = cfg["PrimaryFunctions"], cfg["CrossFunctions"]
BUDGET, N = cfg["Budget"], cfg["Population"]

raw = pd.read_csv(run / "raw_runs.csv").sort_values("JobID").reset_index(drop=True)
assert len(raw) == cfg["FreshRuns"] == 480, "unexpected number of run records"
assert raw.Status.eq("ok").all(), "a counted run failed"
assert raw.ObjectiveCalls.eq(BUDGET).all() and raw.Evaluations.eq(BUDGET).all()
assert raw.OutsideCalls.eq(0).all()
assert raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.Method) == set(METHODS) and set(raw.Seed) == set(cfg["Seeds"])
assert set(raw.FunctionID) == set(PRIMARY + CROSS)
assert not raw.duplicated(["FunctionID", "Seed", "Method"]).any()
assert raw.groupby(["FunctionID", "Seed"]).Method.nunique().eq(4).all()
for method, spec in SPEC.items():
    sub = raw[raw.Method.eq(method)]
    assert sub.GuardRounds.eq(spec["GuardRounds"]).all()
    assert sub.LearnSchedule.eq(spec["LearnSchedule"]).all()
assert raw.EvalTrace.add(raw.EvalSeek).eq(BUDGET - N).all()
assert raw.EvalNear.add(raw.EvalFar).add(raw.GuardEvaluations).eq(BUDGET - N).all()
assert raw.ImpGlobalNear.add(raw.ImpGlobalFar).add(raw.ImpGlobalGuard).eq(
    raw.ImpGlobalTrace + raw.ImpGlobalSeek).all()
assert raw.ImpPbestNear.add(raw.ImpPbestFar).add(raw.ImpPbestGuard).eq(
    raw.ImpPbestTrace + raw.ImpPbestSeek).all()
assert raw.GapN.eq(BUDGET - N).all() and raw.GapMax.ge(1).all()
assert raw.JumpVictimRecovered.le(raw.JumpVictims).all()
assert raw.CoverageOver50.between(0, 1).all()
assert raw.CoverageOver100.le(raw.CoverageOver50 + 1e-12).all()
assert raw.WindowCoverage.between(0, 1).all() and raw.WindowCoverage.gt(0).all()
assert raw.PbestSpread.gt(0).all() and raw.PbestSpread.lt(1).all()
assert raw[raw.Method.eq("G00")].GuardEvaluations.eq(0).all()
assert raw[raw.Method.eq("G01")].GuardEvaluations.eq(0).all()
assert raw[raw.Method.eq("G00")].CogEvaluations.eq(0).all()
assert raw[raw.Method.eq("G10")].CogEvaluations.eq(0).all()
assert raw[raw.Method.eq("G01")].CogEvaluations.gt(0).all()
assert raw[raw.Method.eq("G11")].CogEvaluations.gt(0).all()
assert raw[raw.Method.eq("G11")].GuardEvaluations.gt(0).all()
assert raw.GuardEvaluations.le(raw.Rounds).all()

checks = []
curves = []
node_fe = [50, 1000, 10000, 20000, 40000, 60000, 80000, 100000]
for row in raw.itertuples():
    art = run / "runs" / row.Artifact
    assert art.is_file(), f"missing artifact {art}"
    m = loadmat(art, variable_names=["T"], squeeze_me=True)
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
    if len(checks) % 80 == 0:
        print("Artifact audit", len(checks), "/", len(raw), flush=True)

raw["Study"] = np.where(raw.FunctionID.isin(PRIMARY), "primary", "cross")
out = ROOT / "results/asc_starvation_guard_10seed_20261015"
out.mkdir(parents=True, exist_ok=True)
(out / "source").mkdir(exist_ok=True)

means = raw.groupby(["FunctionID", "Method"]).FinalError.mean().unstack().reindex(columns=METHODS)
std = raw.groupby(["FunctionID", "Method"]).FinalError.std().unstack().reindex(columns=METHODS)
med = raw.groupby(["FunctionID", "Method"]).FinalError.median().unstack().reindex(columns=METHODS)
for name, d in [("function_means.csv", means), ("function_std.csv", std),
                ("function_medians.csv", med)]:
    d.to_csv(out / name)
means.rank(axis=1).mean().sort_values().rename("AverageRank").to_csv(out / "mean_ranks.csv")


def pair_stats(split, funcs, method, ref):
    sub = means.loc[funcs]
    ratio = sub[method] / sub[ref]
    sel = raw.FunctionID.isin(funcs)
    b = raw[sel & raw.Method.eq(ref)].set_index(["FunctionID", "Seed"]).FinalError
    a = raw[sel & raw.Method.eq(method)].set_index(
        ["FunctionID", "Seed"]).FinalError.reindex(b.index)
    delta = a - b
    return dict(Split=split, Method=method, Reference=ref,
                MeanWins=int((ratio < 1).sum()), MeanLosses=int((ratio > 1).sum()),
                MeanTies=int((ratio == 1).sum()),
                SeedWins=int((delta < 0).sum()), SeedLosses=int((delta > 0).sum()),
                SeedTies=int((delta == 0).sum()),
                MedianMeanRatio=float(ratio.median()),
                GeometricMeanRatio=float(np.exp(np.log(ratio).mean())))


def function_tests(split, funcs, method, ref, rows):
    sub = means.loc[funcs]
    for fid in funcs:
        z = raw[raw.FunctionID.eq(fid)].pivot(index="Seed", columns="Method", values="FinalError")
        d = (z[method] - z[ref]).to_numpy()
        pv = 1.0 if np.all(d == 0) else float(wilcoxon(d, zero_method="wilcox",
                                                       method="auto").pvalue)
        nz = d[np.abs(d) > 0]
        rb = 0.0 if not len(nz) else float(np.sum(rankdata(np.abs(nz)) * np.sign(-nz))
                                          / np.sum(rankdata(np.abs(nz))))
        rows.append(dict(Split=split, FunctionID=int(fid), Method=method, Reference=ref,
                         MeanRatio=float(sub.loc[fid, method] / sub.loc[fid, ref]),
                         WilcoxonP=pv, RankBiserial=rb,
                         SeedWins=int((d < 0).sum()), SeedLosses=int((d > 0).sum()),
                         SeedTies=int((d == 0).sum())))


comp, detail = [], []
for split, funcs in [("primary", PRIMARY), ("cross", CROSS), ("all", PRIMARY + CROSS)]:
    for method, ref in PAIRS:
        comp.append(pair_stats(split, funcs, method, ref))
        if split != "all":
            function_tests(split, funcs, method, ref, detail)
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


def judge(method, ref, split, min_wins, max_ratio, guard=False, hard_cap=False,
          secondary_max=None):
    funcs = PRIMARY if split == "primary" else CROSS
    row = comp[(comp.Method == method) & (comp.Reference == ref)
               & (comp.Split == split)].iloc[0]
    ratio = means.loc[funcs, method] / means.loc[funcs, ref]
    ok = bool(row.MeanWins >= min_wins and row.MedianMeanRatio <= max_ratio)
    if secondary_max is not None:
        ok = ok and row.MedianMeanRatio <= secondary_max
    if hard_cap:
        ok = ok and bool((ratio <= 1.20).all())
    return ok, row, ratio


s1_p, r_s1p, ratio_s1p = judge("G10", "G00", "primary", 4, 1.05, hard_cap=False)
s1_c, r_s1c, _ = judge("G10", "G00", "cross", 2, 1.05)
s1 = bool(s1_p and s1_c)
s2_p, r_s2p, ratio_s2p = judge("G11", "G01", "primary", 5, 0.95, hard_cap=True)
s2_c, r_s2c, _ = judge("G11", "G01", "cross", 3, 1.00)
s2 = bool(s2_p and s2_c)
s3_p, r_s3p, ratio_s3p = judge("G11", "G00", "primary", 5, 0.95, hard_cap=False)
s3_c, r_s3c, _ = judge("G11", "G00", "cross", 3, 1.00)
s3 = bool(s3_p and s3_c)
s4_p, r_s4p, ratio_s4p = judge("G01", "G00", "primary", 5, 0.95, hard_cap=False)
s4_c, r_s4c, _ = judge("G01", "G00", "cross", 3, 1.00)
s4 = bool(s4_p and s4_c)
checks_gate = dict(S1GuardSafety=s1, S2GuardOnCognitionPrimary=s2_p,
                   S2GuardOnCognitionCross=s2_c, S3CombinedVsBaselinePrimary=s3_p,
                   S3CombinedVsBaselineCross=s3_c, S4CognitionVsBaseline=s4,
                   F6F9Guard=bool((ratio_s2p.loc[[6, 9]] <= 1.10).all()))
advance = {"G11": bool(s2 and s3)}
gate = dict(Passed=bool(advance["G11"]), Advance=advance, GateChecks=checks_gate,
            GuardRounds=cfg["GuardRounds"],
            S1Detail=dict(Primary=bool(s1_p), Cross=bool(s1_c),
                          MedianPrimary=float(r_s1p.MedianMeanRatio),
                          MedianCross=float(r_s1c.MedianMeanRatio)),
            S2Detail=dict(Primary=bool(s2_p), Cross=bool(s2_c),
                          MedianPrimary=float(r_s2p.MedianMeanRatio),
                          MedianCross=float(r_s2c.MedianMeanRatio),
                          MaxRegressionPrimary=float(ratio_s2p.max())),
            S3Detail=dict(Primary=bool(s3_p), Cross=bool(s3_c),
                          MedianPrimary=float(r_s3p.MedianMeanRatio),
                          MedianCross=float(r_s3c.MedianMeanRatio)),
            S4Detail=dict(Primary=bool(s4_p), Cross=bool(s4_c),
                          MedianPrimary=float(r_s4p.MedianMeanRatio),
                          MedianCross=float(r_s4c.MedianMeanRatio)),
            PrimaryFunctions=PRIMARY, CrossFunctions=CROSS,
            FreshRuns=len(raw), OptimizationCalls=int(raw.ObjectiveCalls.sum()),
            AuditCalls=int(raw.PostRunRecheckCalls.sum()),
            ValidationObjectiveCalls=json.loads(
                (run / "validation.json").read_text(encoding="utf8"))["ValidationObjectiveCalls"],
            PreflightObjectiveCalls=json.loads(
                (run / "preflight.json").read_text(encoding="utf8"))["ObjectiveCalls"],
            NewSeedReplicates=True, UnseenFunctions=False,
            SeedRange=[min(cfg["Seeds"]), max(cfg["Seeds"])],
            MinPossibleP=2.0 / (2 ** 10), HolmFirstCutoff=0.05 / len(detail),
            SignificantFunctionTests=int((detail.Holm < 0.05).sum()),
            Comparisons=comp.to_dict("records"))
(out / "gate_decision.json").write_text(
    json.dumps(gate, ensure_ascii=False, indent=2), encoding="utf8")

# ---------------- diagnostics ----------------
diag_cols = ["EvalTrace", "EvalSeek", "EvalNear", "EvalFar", "GuardEvaluations",
             "ImpPbestTrace", "ImpPbestSeek", "ImpPbestNear", "ImpPbestFar",
             "ImpPbestGuard", "ImpGlobalTrace", "ImpGlobalSeek", "ImpGlobalNear",
             "ImpGlobalFar", "ImpGlobalGuard", "GapSum", "GapN", "GapMax", "JumpEvents",
             "JumpStallSum", "JumpVictims", "JumpVictimRecovered", "MeanEvalGap",
             "CogEvaluations", "CoverageOver50", "CoverageOver100", "WindowCoverage",
             "PbestSpread"]
diag = raw[["FunctionID", "Seed", "Method", "Study"] + diag_cols].copy()
diag["PbestRateTrace"] = diag.ImpPbestTrace / diag.EvalTrace.replace(0, np.nan)
diag["PbestRateSeek"] = diag.ImpPbestSeek / diag.EvalSeek.replace(0, np.nan)
diag["GlobalRateTrace"] = diag.ImpGlobalTrace / diag.EvalTrace.replace(0, np.nan)
diag["GlobalRateSeek"] = diag.ImpGlobalSeek / diag.EvalSeek.replace(0, np.nan)
diag["PbestRateNear"] = diag.ImpPbestNear / diag.EvalNear.replace(0, np.nan)
diag["PbestRateFar"] = diag.ImpPbestFar / diag.EvalFar.replace(0, np.nan)
diag["PbestRateGuard"] = diag.ImpPbestGuard / diag.GuardEvaluations.replace(0, np.nan)
diag["GlobalRateGuard"] = diag.ImpGlobalGuard / diag.GuardEvaluations.replace(0, np.nan)
diag["GuardShare"] = diag.GuardEvaluations / (BUDGET - N)
diag["JumpRecoveryRate"] = diag.JumpVictimRecovered / diag.JumpVictims.replace(0, np.nan)
diag.to_csv(out / "diagnostics_runs.csv", index=False)
summary_cols = ["EvalTrace", "EvalSeek", "EvalNear", "EvalFar", "GuardEvaluations",
                "ImpPbestGuard", "ImpGlobalGuard", "GuardShare", "PbestRateGuard",
                "GlobalRateGuard", "PbestRateTrace", "PbestRateNear", "PbestRateFar",
                "GlobalRateTrace", "MeanEvalGap", "GapMax", "JumpEvents", "JumpVictims",
                "JumpRecoveryRate", "CogEvaluations", "CoverageOver50", "CoverageOver100",
                "WindowCoverage", "PbestSpread"]
diag.groupby("Method")[summary_cols].mean().to_csv(out / "diagnostics_summary.csv")
diag.groupby(["FunctionID", "Study", "Method"])[
    ["GuardEvaluations", "GuardShare", "PbestRateGuard", "GlobalRateGuard",
     "CoverageOver50", "CoverageOver100", "WindowCoverage", "GapMax", "PbestSpread",
     "PbestRateTrace", "GlobalRateTrace"]].mean().to_csv(out / "diagnostics_by_function.csv")

# ---------------- convergence figure ----------------
cur = pd.DataFrame(curves)
cur.to_csv(out / "convergence_nodes.csv", index=False)
fig, axes = plt.subplots(3, 4, figsize=(19, 11))
for ax, fid in zip(axes.ravel(), PRIMARY + CROSS):
    d = cur[cur.FunctionID.eq(fid)]
    for method, style in zip(METHODS, ["-", "--", "-.", ":"]):
        g = d[d.Method.eq(method)].groupby("FE").BestError.mean()
        ax.plot(g.index, np.maximum(g.to_numpy(), 1e-12), style, marker="o",
                markersize=3.5, linewidth=1.6, label=method)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_title(f"F{fid}", fontsize=11)
    ax.grid(alpha=0.3, which="both", linewidth=0.4)
    ax.tick_params(labelsize=8)
axes.ravel()[0].legend(fontsize=8)
fig.suptitle("ASC starvation guard: mean best-so-far error "
             "(10 seeds, 100k real evaluations)", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.97])
for ext in ["png", "pdf"]:
    fig.savefig(out / f"convergence.{ext}", dpi=180, bbox_inches="tight")
plt.close(fig)

for name in ["config.json", "validation.json", "checks.csv", "PROTOCOL.md",
             "preflight.json", "prelaunch_hashes.csv"]:
    shutil.copyfile(run / name, out / name)
for name in ["ASC_NoFarness.m", "ASC_NoFarness_StarvationGuard.m", "run_asc_sg_job.m",
             "run_asc_sg_study.m", "test_ASC_NoFarness_StarvationGuard.m"]:
    shutil.copyfile(run / "source" / name, out / "source" / name)
pd.DataFrame(checks).to_csv(out / "integrity_checks.csv", index=False)
raw.to_csv(out / "all_runs.csv", index=False)

summary = dict(OptimizationCalls=int(raw.ObjectiveCalls.sum()),
               AuditCalls=int(raw.PostRunRecheckCalls.sum()), Runs=len(raw),
               ValidationObjectiveCalls=gate["ValidationObjectiveCalls"],
               PreflightObjectiveCalls=gate["PreflightObjectiveCalls"])
(out / "analysis_summary.json").write_text(
    json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf8")
print(comp.to_string(index=False))
print(means.round(4).to_string())
print(json.dumps({k: gate[k] for k in ["Passed", "Advance", "GateChecks"]},
                 ensure_ascii=False, indent=2))
print(out)
