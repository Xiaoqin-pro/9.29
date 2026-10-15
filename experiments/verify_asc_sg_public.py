"""CSV-only reproduction of the starvation-guard 2x2 comparisons."""
from pathlib import Path
import hashlib, json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon, rankdata

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / "results/asc_starvation_guard_10seed_20261015"

cfg = json.loads((out / "config.json").read_text(encoding="utf8"))
PRIMARY, CROSS = cfg["PrimaryFunctions"], cfg["CrossFunctions"]
SEEDS, METHODS = cfg["Seeds"], cfg["Methods"]
SPEC = cfg["MethodSpec"]
BUDGET, N = cfg["Budget"], cfg["Population"]

raw = pd.read_csv(out / "all_runs.csv")
assert len(raw) == cfg["FreshRuns"] == 480
assert raw.Status.eq("ok").all()
assert raw.ObjectiveCalls.eq(BUDGET).all() and raw.Evaluations.eq(BUDGET).all()
assert raw.OutsideCalls.eq(0).all()
assert raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.Seed) == set(SEEDS) and set(raw.Method) == set(METHODS)
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
assert raw.GapN.eq(BUDGET - N).all()
assert raw.JumpVictimRecovered.le(raw.JumpVictims).all()
assert raw.CoverageOver50.between(0, 1).all()
assert raw.CoverageOver100.le(raw.CoverageOver50 + 1e-12).all()
assert raw.WindowCoverage.between(0, 1).all() and raw.WindowCoverage.gt(0).all()
assert raw.PbestSpread.gt(0).all() and raw.PbestSpread.lt(1).all()
assert raw[raw.Method.isin(["G00", "G01"])].GuardEvaluations.eq(0).all()
assert raw[raw.Method.isin(["G00", "G01"])].ImpPbestGuard.eq(0).all()
assert raw[raw.Method.isin(["G00", "G10"])].CogEvaluations.eq(0).all()
assert raw[raw.Method.isin(["G01", "G11"])].CogEvaluations.gt(0).all()
assert raw[raw.Method.eq("G11")].GuardEvaluations.gt(0).all()
assert raw.GuardEvaluations.le(raw.Rounds).all()

means = raw.groupby(["FunctionID", "Method"]).FinalError.mean().unstack().reindex(columns=METHODS)
assert np.allclose(means, pd.read_csv(out / "function_means.csv", index_col=0),
                   rtol=1e-12, atol=1e-8)
std = raw.groupby(["FunctionID", "Method"]).FinalError.std().unstack().reindex(columns=METHODS)
assert np.allclose(std, pd.read_csv(out / "function_std.csv", index_col=0),
                   rtol=1e-12, atol=1e-8)
med = raw.groupby(["FunctionID", "Method"]).FinalError.median().unstack().reindex(columns=METHODS)
assert np.allclose(med, pd.read_csv(out / "function_medians.csv", index_col=0),
                   rtol=1e-12, atol=1e-8)

comp = pd.read_csv(out / "comparisons.csv")
detail = pd.read_csv(out / "function_comparisons.csv")
assert len(detail) == 48 and len(comp) == 12


def subset(split):
    return PRIMARY if split == "primary" else (CROSS if split == "cross" else PRIMARY + CROSS)


for row in comp.itertuples():
    funcs = subset(row.Split)
    sub = means.loc[funcs]
    sel = raw.FunctionID.isin(funcs)
    b = raw[sel & raw.Method.eq(row.Reference)].set_index(["FunctionID", "Seed"]).FinalError
    a = raw[sel & raw.Method.eq(row.Method)].set_index(
        ["FunctionID", "Seed"]).FinalError.reindex(b.index)
    delta = a - b
    ratio = sub[row.Method] / sub[row.Reference]
    assert row.MeanWins == int((ratio < 1).sum()) and row.MeanLosses == int((ratio > 1).sum())
    assert row.MeanTies == int((ratio == 1).sum())
    assert row.SeedWins == int((delta < 0).sum()) and row.SeedLosses == int((delta > 0).sum())
    assert row.SeedTies == int((delta == 0).sum())
    assert np.isclose(row.MedianMeanRatio, ratio.median(), rtol=1e-12)
for row in detail.itertuples():
    z = raw[raw.FunctionID.eq(row.FunctionID)].pivot(index="Seed", columns="Method",
                                                    values="FinalError")
    d = (z[row.Method] - z[row.Reference]).to_numpy()
    pv = 1.0 if np.all(d == 0) else float(wilcoxon(d, zero_method="wilcox",
                                                  method="auto").pvalue)
    assert np.isclose(row.WilcoxonP, pv, rtol=1e-12)
    nz = d[np.abs(d) > 0]
    rb = 0.0 if not len(nz) else float(np.sum(rankdata(np.abs(nz)) * np.sign(-nz))
                                      / np.sum(rankdata(np.abs(nz))))
    assert np.isclose(row.RankBiserial, rb, rtol=1e-12)
pv = detail.WilcoxonP.to_numpy()
adj = np.empty(len(pv))
running = 0.0
for k, i in enumerate(np.argsort(pv)):
    running = max(running, (len(pv) - k) * pv[i])
    adj[i] = min(1.0, running)
assert np.allclose(adj, detail.Holm, rtol=1e-12)


def recompute(method, ref, split, min_wins, max_ratio, hard_cap=False):
    row = comp[(comp.Method == method) & (comp.Reference == ref)
               & (comp.Split == split)].iloc[0]
    funcs = subset(split)
    ratio = means.loc[funcs, method] / means.loc[funcs, ref]
    ok = bool(row.MeanWins >= min_wins and row.MedianMeanRatio <= max_ratio)
    if hard_cap:
        ok = ok and bool((ratio <= 1.20).all())
    return ok, row, ratio


s1_p, r_s1p, _ = recompute("G10", "G00", "primary", 4, 1.05)
s1_c, r_s1c, _ = recompute("G10", "G00", "cross", 2, 1.05)
s2_p, r_s2p, ratio_s2p = recompute("G11", "G01", "primary", 5, 0.95, hard_cap=True)
s2_c, r_s2c, _ = recompute("G11", "G01", "cross", 3, 1.00)
s3_p, r_s3p, _ = recompute("G11", "G00", "primary", 5, 0.95)
s3_c, r_s3c, _ = recompute("G11", "G00", "cross", 3, 1.00)
s4_p, r_s4p, _ = recompute("G01", "G00", "primary", 5, 0.95)
s4_c, r_s4c, _ = recompute("G01", "G00", "cross", 3, 1.00)
checks_gate = dict(S1GuardSafety=bool(s1_p and s1_c), S2GuardOnCognitionPrimary=bool(s2_p),
                   S2GuardOnCognitionCross=bool(s2_c),
                   S3CombinedVsBaselinePrimary=bool(s3_p),
                   S3CombinedVsBaselineCross=bool(s3_c),
                   S4CognitionVsBaseline=bool(s4_p and s4_c),
                   F6F9Guard=bool((ratio_s2p.loc[[6, 9]] <= 1.10).all()))
g = json.loads((out / "gate_decision.json").read_text(encoding="utf8"))
assert g["GateChecks"] == checks_gate, (g["GateChecks"], checks_gate)
assert g["Advance"] == {"G11": bool(s2_p and s2_c and s3_p and s3_c)}
assert g["Passed"] == g["Advance"]["G11"]
assert g["OptimizationCalls"] == int(raw.ObjectiveCalls.sum())
assert g["AuditCalls"] == int(raw.PostRunRecheckCalls.sum())
assert np.isclose(g["S2Detail"]["MedianPrimary"], r_s2p.MedianMeanRatio, rtol=1e-12)
assert np.isclose(g["S3Detail"]["MedianCross"], r_s3c.MedianMeanRatio, rtol=1e-12)

diag = pd.read_csv(out / "diagnostics_runs.csv")
assert len(diag) == len(raw)
pub = pd.read_csv(out / "diagnostics_summary.csv", index_col=0)
agg = diag.groupby("Method")[list(pub.columns)].mean()
# rows without a guard leave the guard-only rates undefined, so NaN matching is
# part of the comparison rather than a failure
assert np.allclose(agg, pub.reindex(agg.index), rtol=1e-9, atol=1e-12, equal_nan=True)

curves = pd.read_csv(out / "convergence_nodes.csv")
assert not curves.duplicated(["FunctionID", "Seed", "Method", "FE"]).any()
assert len(curves) == 480 * 8
last = curves[curves.FE.eq(BUDGET)].set_index(["FunctionID", "Seed", "Method"]).BestError
assert len(last) == 480
assert np.allclose(last, raw.set_index(["FunctionID", "Seed", "Method"])
                   .FinalError.reindex(last.index), rtol=1e-10, atol=1e-6)

integrity = pd.read_csv(out / "integrity_checks.csv")
assert len(integrity) == 480 and integrity.Passed.all()

manifest = pd.read_csv(out / "prelaunch_hashes.csv")
for name in ["ASC_NoFarness.m", "ASC_NoFarness_StarvationGuard.m", "run_asc_sg_job.m",
             "run_asc_sg_study.m", "test_ASC_NoFarness_StarvationGuard.m"]:
    entry = manifest[manifest.RelativePath.str.replace("\\", "/", regex=False)
                     .eq("source/" + name)]
    assert len(entry) == 1
    digest = hashlib.sha256((out / "source" / name).read_bytes()).hexdigest()
    assert digest == entry.iloc[0].SHA256, f"source snapshot changed for {name}"
assert json.loads((out / "validation.json").read_text(encoding="utf8"))["Passed"]
assert json.loads((out / "preflight.json").read_text(encoding="utf8"))["Passed"]

rep = dict(Passed=True, Rows=480, FunctionMeansChecked=48, PairedTestsRecomputed=48,
           HolmTestsRecomputed=48, DiagnosticsRecomputed=True,
           GuardAccountingRecomputed=True, CoverageDiagnosticsRecomputed=True,
           GateRecomputed=True, ConvergenceNodesChecked=3840,
           SourceSnapshotsVerified=True, PrivateMATRequired=False,
           SignificantFunctionTests=int((detail.Holm < 0.05).sum()))
(out / "public_verification.json").write_text(json.dumps(rep, indent=2), encoding="utf8")
print(json.dumps(rep, indent=2))
