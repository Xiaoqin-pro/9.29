"""Independent artifact audit and paired analysis of the A0-A3 seeking candidates."""
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

METHODS = ["A0", "A1", "A2", "A3"]
TYPE_OF = {"A0": None, "A1": 2, "A2": 3, "A3": 4}
PAIRS = [("A1", "A0"), ("A2", "A0"), ("A3", "A0")]
PRIMARY, CROSS = cfg["PrimaryFunctions"], cfg["CrossFunctions"]
BUDGET, N = cfg["Budget"], cfg["Population"]
GUARD = [6, 9, 27]          # F27 is protected: ASC already leads on it

raw = pd.read_csv(run / "raw_runs.csv").sort_values("JobID").reset_index(drop=True)
assert len(raw) == cfg["FreshRuns"] == 480
assert raw.Status.eq("ok").all(), "a counted run failed"
assert raw.ObjectiveCalls.eq(BUDGET).all() and raw.Evaluations.eq(BUDGET).all()
assert raw.OutsideCalls.eq(0).all()
assert raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.Method) == set(METHODS) and set(raw.Seed) == set(cfg["Seeds"])
assert set(raw.FunctionID) == set(PRIMARY + CROSS)
assert not raw.duplicated(["FunctionID", "Seed", "Method"]).any()
assert raw.groupby(["FunctionID", "Seed"]).Method.nunique().eq(4).all()
assert raw.SeekVariant.eq(raw.Method).all()
assert raw.SeekRefineCount.eq(cfg["SeekRefineCount"]).all()
seek_cols = [f"SeekEval{i}" for i in range(1, 5)]
assert raw[seek_cols].sum(axis=1).add(raw.TraceEval).add(raw.OtherEval).eq(BUDGET - N).all()
assert raw.TraceEval.gt(0).all()
for method in METHODS:
    sub = raw[raw.Method.eq(method)]
    if TYPE_OF[method] is None:
        assert sub[seek_cols].drop(columns="SeekEval1").sum(axis=1).eq(0).all()
        assert sub.SeekEval1.gt(0).all()
    else:
        t = TYPE_OF[method]
        assert sub[f"SeekEval{t}"].gt(0).all()
        assert sub.SeekEval1.gt(0).all()
        others = [f"SeekEval{i}" for i in range(2, 5) if i != t]
        assert sub[others].sum(axis=1).eq(0).all()
    tcheck = TYPE_OF[method] if TYPE_OF[method] is not None else 1
    assert (sub[f"SeekImpGlobal{tcheck}"] <= sub[f"SeekEval{tcheck}"]).all()
    assert (sub[f"SeekImpPbest{tcheck}"] <= sub[f"SeekEval{tcheck}"]).all()

checks = []
curves = []
node_fe = [50, 1000, 10000, 20000, 40000, 60000, 80000, 100000]
for row in raw.itertuples():
    art = run / "runs" / row.Artifact
    assert art.is_file(), f"missing artifact {art}"
    m = loadmat(art, variable_names=["T"], squeeze_me=True)
    T = np.asarray(m["T"], dtype=float).ravel()
    assert T.size == BUDGET and np.all(np.diff(T) <= 0)
    assert np.isclose(T[-1], row.FinalCost, rtol=1e-12, atol=1e-9)
    init_drops = int(np.sum(np.diff(T[:N]) < 0))
    total_imp = sum(getattr(row, f"SeekImpGlobal{i}") for i in range(1, 5)) \
        + row.TraceImpGlobal + row.OtherImpGlobal
    assert total_imp == int(np.sum(np.diff(T) < 0)) - init_drops, \
        "candidate-type global improvement counts do not match the trace"
    checks.append(dict(FunctionID=row.FunctionID, Seed=row.Seed, Method=row.Method,
                       Passed=True, TraceMonotone=True, DiagnosticsConsistent=True))
    for fe in node_fe:
        curves.append(dict(FunctionID=row.FunctionID, Seed=row.Seed, Method=row.Method,
                           FE=fe, BestError=T[min(fe, BUDGET) - 1] - 100 * row.FunctionID))
    if len(checks) % 80 == 0:
        print("Artifact audit", len(checks), "/", len(raw), flush=True)

raw["Study"] = np.where(raw.FunctionID.isin(PRIMARY), "primary", "cross")
out = ROOT / "results/asc_seeking_candidates_10seed_20261015"
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


comp, detail = [], []
for split, funcs in [("primary", PRIMARY), ("cross", CROSS), ("all", PRIMARY + CROSS)]:
    for method, ref in PAIRS:
        comp.append(pair_stats(split, funcs, method, ref))
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
                               MeanRatio=float(means.loc[fid, method] / means.loc[fid, ref]),
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


def judge(method, ref, split):
    funcs = PRIMARY if split == "primary" else CROSS
    row = comp[(comp.Method == method) & (comp.Reference == ref)
               & (comp.Split == split)].iloc[0]
    ratio = means.loc[funcs, method] / means.loc[funcs, ref]
    ok = bool(row.MeanWins >= (5 if split == "primary" else 3)
              and row.MedianMeanRatio <= (0.95 if split == "primary" else 1.00))
    if split == "primary":
        ok = ok and bool((ratio.loc[GUARD] <= 1.10).all()) and bool((ratio <= 1.20).all())
    return ok, row, ratio


detail_gate = {}
for name in ["A1", "A2", "A3"]:
    p_ok, r_p, ratio_p = judge(name, "A0", "primary")
    c_ok, r_c, _ = judge(name, "A0", "cross")
    detail_gate[name] = dict(
        PrimaryPassed=p_ok, CrossPassed=c_ok,
        MedianMeanRatioPrimary=float(r_p.MedianMeanRatio),
        MedianMeanRatioCross=float(r_c.MedianMeanRatio),
        F6F9F27Guard=bool((ratio_p.loc[GUARD] <= 1.10).all()),
        MaxRegressionPrimary=float(ratio_p.max()),
        Advance=bool(p_ok and c_ok))
advance = {name: detail_gate[name]["Advance"] for name in ["A1", "A2", "A3"]}
gate = dict(Passed=bool(any(advance.values())), Advance=advance, Detail=detail_gate,
            GuardFunctions=GUARD, PrimaryFunctions=PRIMARY, CrossFunctions=CROSS,
            SeekRefineCount=cfg["SeekRefineCount"], EliteGuideGain=cfg["EliteGuideGain"],
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

# ---------------- candidate-type diagnostics ----------------
diag = raw[["FunctionID", "Seed", "Method", "Study"] + seek_cols
           + [f"SeekImpPbest{i}" for i in range(1, 5)]
           + [f"SeekImpGlobal{i}" for i in range(1, 5)]
           + [f"SeekDistSum{i}" for i in range(1, 5)]
           + ["TraceEval", "TraceImpPbest", "TraceImpGlobal"]].copy()
diag["RefinedEval"] = np.zeros(len(diag), dtype=int)
diag["RefinedImpPbest"] = np.zeros(len(diag), dtype=int)
diag["RefinedImpGlobal"] = np.zeros(len(diag), dtype=int)
diag["RefinedDistSum"] = np.zeros(len(diag), dtype=float)
for name, t in TYPE_OF.items():
    if t is None:
        continue
    m = diag.Method.eq(name)
    diag.loc[m, "RefinedEval"] = diag.loc[m, f"SeekEval{t}"]
    diag.loc[m, "RefinedImpPbest"] = diag.loc[m, f"SeekImpPbest{t}"]
    diag.loc[m, "RefinedImpGlobal"] = diag.loc[m, f"SeekImpGlobal{t}"]
    diag.loc[m, "RefinedDistSum"] = diag.loc[m, f"SeekDistSum{t}"]
diag["PlainSeekEval"] = diag.SeekEval1
diag["PlainSeekImpPbest"] = diag.SeekImpPbest1
diag["PlainSeekImpGlobal"] = diag.SeekImpGlobal1
diag["PlainSeekDistMean"] = diag.SeekDistSum1 / diag.SeekEval1.replace(0, np.nan)
diag["RefinedDistMean"] = diag.RefinedDistSum / diag.RefinedEval.replace(0, np.nan)
diag["RefinedImproveRate"] = diag.RefinedImpPbest / diag.RefinedEval.replace(0, np.nan)
diag["RefinedGlobalRate"] = diag.RefinedImpGlobal / diag.RefinedEval.replace(0, np.nan)
diag["PlainImproveRate"] = diag.PlainSeekImpPbest / diag.PlainSeekEval.replace(0, np.nan)
diag["PlainGlobalRate"] = diag.PlainSeekImpGlobal / diag.PlainSeekEval.replace(0, np.nan)
diag.to_csv(out / "diagnostics_runs.csv", index=False)
sum_cols = ["SeekEval1", "RefinedEval", "PlainImproveRate", "RefinedImproveRate",
            "PlainGlobalRate", "RefinedGlobalRate", "PlainSeekDistMean", "RefinedDistMean",
            "TraceEval", "TraceImpGlobal"]
diag.groupby("Method")[sum_cols].mean().to_csv(out / "diagnostics_summary.csv")
diag.groupby(["FunctionID", "Study", "Method"])[
    ["SeekEval1", "RefinedEval", "PlainImproveRate", "RefinedImproveRate",
     "PlainGlobalRate", "RefinedGlobalRate", "PlainSeekDistMean", "RefinedDistMean"]].mean(
    ).to_csv(out / "diagnostics_by_function.csv")

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
fig.suptitle("ASC seeking candidates: mean best-so-far error "
             "(10 seeds, 100k real evaluations)", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.97])
for ext in ["png", "pdf"]:
    fig.savefig(out / f"convergence.{ext}", dpi=180, bbox_inches="tight")
plt.close(fig)

for name in ["config.json", "validation.json", "checks.csv", "PROTOCOL.md",
             "preflight.json", "prelaunch_hashes.csv"]:
    shutil.copyfile(run / name, out / name)
for name in ["ASC_NoFarness.m", "ASC_NoFarness_SeekingCandidates.m", "run_asc_sc_job.m",
             "run_asc_sc_study.m", "test_ASC_NoFarness_SeekingCandidates.m"]:
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
print(json.dumps({k: gate[k] for k in ["Passed", "Advance"]}, ensure_ascii=False))
print(out)
