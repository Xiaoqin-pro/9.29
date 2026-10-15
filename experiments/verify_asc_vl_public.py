"""CSV-only reproduction of the verified-exemplar learning comparisons.

This script deliberately does not touch the local MAT archives: it recomputes
every published number from the CSV files in the public result folder, so an
outside reader can check the release with numpy/pandas/scipy alone.
"""
from pathlib import Path
import hashlib, json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon, rankdata

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / "results/asc_verified_learning_10seed_20261015"

cfg = json.loads((out / "config.json").read_text(encoding="utf8"))
PRIMARY, CROSS = cfg["PrimaryFunctions"], cfg["CrossFunctions"]
SEEDS, METHODS = cfg["Seeds"], cfg["Methods"]
BUDGET, N = cfg["Budget"], cfg["Population"]

raw = pd.read_csv(out / "all_runs.csv")
assert len(raw) == cfg["FreshRuns"] == 360
assert raw.Status.eq("ok").all()
assert raw.ObjectiveCalls.eq(BUDGET).all() and raw.Evaluations.eq(BUDGET).all()
assert raw.OutsideCalls.eq(0).all()
assert raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.Seed) == set(SEEDS) and set(raw.Method) == set(METHODS)
assert set(raw.FunctionID) == set(PRIMARY + CROSS)
assert not raw.duplicated(["FunctionID", "Seed", "Method"]).any()
assert raw.groupby(["FunctionID", "Seed"]).Method.nunique().eq(3).all()
assert raw.EvalTrace.add(raw.EvalSeek).eq(BUDGET - N).all()
assert raw.EvalNear.add(raw.EvalFar).eq(BUDGET - N).all()
assert raw.ImpGlobalNear.add(raw.ImpGlobalFar).eq(raw.ImpGlobalTrace + raw.ImpGlobalSeek).all()
assert raw.ImpPbestNear.add(raw.ImpPbestFar).eq(raw.ImpPbestTrace + raw.ImpPbestSeek).all()
assert raw.GapN.eq(BUDGET - N).all()
assert raw.JumpVictimRecovered.le(raw.JumpVictims).all()
assert raw[raw.Method.eq("B0")].ExploreParticles.eq(0).all()
assert raw[raw.Method.eq("B1")].ExploreParticles.eq(0).all()
explore = int(sum(1 for i in range(N) if (i % 10) < round(10 * cfg["ExploreFraction"])))
assert raw[raw.Method.eq("B2")].ExploreParticles.eq(explore).all()
assert np.allclose(raw[raw.Method.eq("B0")].CognitiveShare, cfg["CognitiveShare"])

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
assert len(detail) == 36 and len(comp) == 9
for row in comp.itertuples():
    funcs = PRIMARY if row.Split == "primary" else (CROSS if row.Split == "cross" else PRIMARY + CROSS)
    sub = means.loc[funcs]
    b = raw[raw.Method.eq(row.Reference)].set_index(["FunctionID", "Seed"]).FinalError
    a = raw[raw.Method.eq(row.Method)].set_index(["FunctionID", "Seed"]).FinalError.reindex(b.index)
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
    pv = 1.0 if np.all(d == 0) else float(wilcoxon(d, zero_method="wilcox", method="auto").pvalue)
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


def recompute(method, ref, split):
    row = comp[(comp.Method == method) & (comp.Reference == ref) & (comp.Split == split)].iloc[0]
    funcs = PRIMARY if split == "primary" else CROSS
    ratio = means.loc[funcs, method] / means.loc[funcs, ref]
    ok = bool(row.MeanWins >= (5 if split == "primary" else 3)
              and row.MedianMeanRatio <= (0.95 if split == "primary" else 1.00))
    if split == "primary":
        ok = ok and bool((ratio.loc[[6, 9]] <= 1.10).all()) and bool((ratio <= 1.20).all())
    return ok


checks = dict(B1VsB0Primary=recompute("B1", "B0", "primary"),
              B1VsB0Cross=recompute("B1", "B0", "cross"),
              B2VsB0Primary=recompute("B2", "B0", "primary"),
              B2VsB0Cross=recompute("B2", "B0", "cross"),
              B2VsB1ExtraValuePrimary=recompute("B2", "B1", "primary"),
              B2VsB1ExtraValueCross=recompute("B2", "B1", "cross"))
g = json.loads((out / "gate_decision.json").read_text(encoding="utf8"))
assert g["GateChecks"] == checks, (g["GateChecks"], checks)
assert g["Advance"] == dict(B1=bool(checks["B1VsB0Primary"] and checks["B1VsB0Cross"]),
                            B2=bool(checks["B2VsB0Primary"] and checks["B2VsB0Cross"]
                                    and checks["B2VsB1ExtraValuePrimary"]))
assert g["Passed"] == any(g["Advance"].values())
assert g["OptimizationCalls"] == int(raw.ObjectiveCalls.sum())
assert g["AuditCalls"] == int(raw.PostRunRecheckCalls.sum())

diag = pd.read_csv(out / "diagnostics_runs.csv")
assert len(diag) == len(raw)
agg = diag.groupby("Method")[["EvalTrace", "EvalSeek", "EvalNear", "EvalFar",
                              "ImpPbestTrace", "ImpPbestSeek", "PbestRateTrace",
                              "PbestRateSeek", "GlobalRateTrace", "GlobalRateSeek",
                              "PbestRateNear", "PbestRateFar", "MeanEvalGap", "GapMax",
                              "JumpEvents", "JumpVictims", "JumpVictimRecovered",
                              "JumpRecoveryRate"]].mean()
pub = pd.read_csv(out / "diagnostics_summary.csv", index_col=0)
assert np.allclose(agg, pub[agg.columns], rtol=1e-9, atol=1e-12)

curves = pd.read_csv(out / "convergence_nodes.csv")
assert not curves.duplicated(["FunctionID", "Seed", "Method", "FE"]).any()
assert len(curves) == 360 * 8
last = curves[curves.FE.eq(BUDGET)].set_index(["FunctionID", "Seed", "Method"]).BestError
assert len(last) == 360
assert np.allclose(last, raw.set_index(["FunctionID", "Seed", "Method"])
                   .FinalError.reindex(last.index), rtol=1e-10, atol=1e-6)

integrity = pd.read_csv(out / "integrity_checks.csv")
assert len(integrity) == 360 and integrity.Passed.all()

# executed sources must still match the frozen prelaunch hashes
manifest = pd.read_csv(out / "prelaunch_hashes.csv")
for name in ["ASC_NoFarness.m", "ASC_NoFarness_VerifiedLearning.m", "run_asc_vl_job.m",
             "run_asc_vl_study.m", "test_ASC_NoFarness_VerifiedLearning.m"]:
    entry = manifest[manifest.RelativePath.str.replace("\\", "/", regex=False)
                     .eq("source/" + name)]
    assert len(entry) == 1
    digest = hashlib.sha256((out / "source" / name).read_bytes()).hexdigest()
    assert digest == entry.iloc[0].SHA256, f"source snapshot changed for {name}"
assert json.loads((out / "validation.json").read_text(encoding="utf8"))["Passed"]
assert json.loads((out / "preflight.json").read_text(encoding="utf8"))["Passed"]

rep = dict(Passed=True, Rows=360, FunctionMeansChecked=36, PairedTestsRecomputed=36,
           HolmTestsRecomputed=36, DiagnosticsRecomputed=True, GateRecomputed=True,
           ConvergenceNodesChecked=2880, SourceSnapshotsVerified=True,
           PrivateMATRequired=False, SignificantFunctionTests=int((detail.Holm < 0.05).sum()))
(out / "public_verification.json").write_text(json.dumps(rep, indent=2), encoding="utf8")
print(json.dumps(rep, indent=2))
