"""CSV-only reproduction of the A0-A3 seeking-candidate comparisons."""
from pathlib import Path
import hashlib, json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon, rankdata

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / "results/asc_seeking_candidates_10seed_20261015"

cfg = json.loads((out / "config.json").read_text(encoding="utf8"))
PRIMARY, CROSS = cfg["PrimaryFunctions"], cfg["CrossFunctions"]
SEEDS, METHODS = cfg["Seeds"], cfg["Methods"]
BUDGET, N = cfg["Budget"], cfg["Population"]
GUARD = [6, 9, 27]
TYPE_OF = {"A0": None, "A1": 2, "A2": 3, "A3": 4}

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
assert raw.SeekVariant.eq(raw.Method).all()
assert raw.SeekRefineCount.eq(cfg["SeekRefineCount"]).all()
assert raw.EliteGuideGain.eq(cfg["EliteGuideGain"]).all()
seek_cols = [f"SeekEval{i}" for i in range(1, 5)]
assert raw[seek_cols].sum(axis=1).add(raw.TraceEval).add(raw.OtherEval).eq(BUDGET - N).all()
assert raw.TraceEval.gt(0).all()
for method in METHODS:
    sub = raw[raw.Method.eq(method)]
    if TYPE_OF[method] is None:
        assert sub[seek_cols].drop(columns="SeekEval1").sum(axis=1).eq(0).all()
    else:
        t = TYPE_OF[method]
        assert sub[f"SeekEval{t}"].gt(0).all()
        others = [f"SeekEval{i}" for i in range(2, 5) if i != t]
        assert sub[others].sum(axis=1).eq(0).all()
    assert sub.SeekEval1.gt(0).all()
for t in range(1, 5):
    assert raw[f"SeekImpPbest{t}"].le(raw[f"SeekEval{t}"]).all()
    assert raw[f"SeekImpGlobal{t}"].le(raw[f"SeekEval{t}"]).all()

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


def recompute(method, ref, split):
    row = comp[(comp.Method == method) & (comp.Reference == ref)
               & (comp.Split == split)].iloc[0]
    funcs = subset(split)
    ratio = means.loc[funcs, method] / means.loc[funcs, ref]
    ok = bool(row.MeanWins >= (5 if split == "primary" else 3)
              and row.MedianMeanRatio <= (0.95 if split == "primary" else 1.00))
    if split == "primary":
        ok = ok and bool((ratio.loc[GUARD] <= 1.10).all()) and bool((ratio <= 1.20).all())
    return ok


expected = {}
for name in ["A1", "A2", "A3"]:
    p_ok = recompute(name, "A0", "primary")
    c_ok = recompute(name, "A0", "cross")
    expected[name] = dict(PrimaryPassed=p_ok, CrossPassed=c_ok, Advance=bool(p_ok and c_ok))
g = json.loads((out / "gate_decision.json").read_text(encoding="utf8"))
for name in ["A1", "A2", "A3"]:
    assert g["Detail"][name]["PrimaryPassed"] == expected[name]["PrimaryPassed"]
    assert g["Detail"][name]["CrossPassed"] == expected[name]["CrossPassed"]
    assert g["Detail"][name]["Advance"] == expected[name]["Advance"]
assert g["Advance"] == {n: expected[n]["Advance"] for n in ["A1", "A2", "A3"]}
assert g["Passed"] == any(g["Advance"].values())
assert g["OptimizationCalls"] == int(raw.ObjectiveCalls.sum())
assert g["AuditCalls"] == int(raw.PostRunRecheckCalls.sum())

diag = pd.read_csv(out / "diagnostics_runs.csv")
assert len(diag) == len(raw)
pub = pd.read_csv(out / "diagnostics_summary.csv", index_col=0)
agg = diag.groupby("Method")[list(pub.columns)].mean()
assert np.allclose(agg, pub.reindex(agg.index), rtol=1e-9, atol=1e-12, equal_nan=True)
for name, t in TYPE_OF.items():
    if t is None:
        continue
    sub = diag[diag.Method.eq(name)]
    assert np.allclose(sub.RefinedEval, sub[f"SeekEval{t}"], rtol=0, atol=0)

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
for name in ["ASC_NoFarness.m", "ASC_NoFarness_SeekingCandidates.m", "run_asc_sc_job.m",
             "run_asc_sc_study.m", "test_ASC_NoFarness_SeekingCandidates.m"]:
    entry = manifest[manifest.RelativePath.str.replace("\\", "/", regex=False)
                     .eq("source/" + name)]
    assert len(entry) == 1
    digest = hashlib.sha256((out / "source" / name).read_bytes()).hexdigest()
    assert digest == entry.iloc[0].SHA256, f"source snapshot changed for {name}"
assert json.loads((out / "validation.json").read_text(encoding="utf8"))["Passed"]
assert json.loads((out / "preflight.json").read_text(encoding="utf8"))["Passed"]

rep = dict(Passed=True, Rows=480, FunctionMeansChecked=48, PairedTestsRecomputed=36,
           HolmTestsRecomputed=36, DiagnosticsRecomputed=True,
           CandidateTypeAccountingRecomputed=True, GateRecomputed=True,
           ConvergenceNodesChecked=3840, SourceSnapshotsVerified=True,
           PrivateMATRequired=False,
           SignificantFunctionTests=int((detail.Holm < 0.05).sum()))
(out / "public_verification.json").write_text(json.dumps(rep, indent=2), encoding="utf8")
print(json.dumps(rep, indent=2))
