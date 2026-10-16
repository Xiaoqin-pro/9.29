"""Build the formal 29-function comparison table with the selected hybrid.

The new method was run with the exact initial populations and search seeds of
the existing 30-seed comparison batch, so every number below is a paired
comparison against the baselines already stored in the repository.
"""
from pathlib import Path
import argparse, json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon, rankdata

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("run", type=Path)
args = p.parse_args()
run = args.run

cfg = json.loads((run / "config.json").read_text(encoding="utf8"))
NEW = "M3-Hybrid"
LABELS = {
    "ASC-NoFarness": "ASC-NoFarness",
    "M3-Hybrid": "ASC-Hybrid (proposed)",
    "CLPSO-AuthorSource": "CLPSO",
    "HCLPSO-AuthorSource": "HCLPSO",
    "HPSO-TVAC-CEC": "HPSO-TVAC",
    "DMS-PSO-SIS2005": "DMS-PSO",
    "SPSO-2011-OfficialC": "SPSO-2011",
}

new = pd.read_csv(run / "raw_runs.csv")
assert new.Status.eq("ok").all() and len(new) == cfg["FreshRuns"] == 870
assert new.ObjectiveCalls.eq(100000).all() and new.OutsideCalls.eq(0).all()
assert new.BestDiff.eq(0).all()
new = new.rename(columns={"Method": "MethodRaw"})
new["Method"] = NEW

old = pd.read_csv(ROOT / "results/asc_comparison_30seed_20261015/all_runs.csv")
old = old[old.Method.isin(LABELS.keys())]
keep = ["FunctionID", "Seed", "Method", "FinalError", "Seconds", "Evaluations",
        "ObjectiveCalls", "OutsideCalls", "Status"]
allruns = pd.concat([old[keep], new[keep]], ignore_index=True)
methods = ["ASC-NoFarness", NEW, "CLPSO-AuthorSource", "HCLPSO-AuthorSource",
           "HPSO-TVAC-CEC", "DMS-PSO-SIS2005", "SPSO-2011-OfficialC"]
allruns = allruns[allruns.Method.isin(methods)]
assert len(allruns) == len(methods) * 29 * 30

out = ROOT / "results/asc_hybrid_formal_29f_30seed_20261015"
out.mkdir(parents=True, exist_ok=True)
(out / "source").mkdir(exist_ok=True)

means = allruns.groupby(["FunctionID", "Method"]).FinalError.mean().unstack()
std = allruns.groupby(["FunctionID", "Method"]).FinalError.std().unstack()
med = allruns.groupby(["FunctionID", "Method"]).FinalError.median().unstack()
means = means.reindex(columns=methods)
std = std.reindex(columns=methods)
med = med.reindex(columns=methods)
means.to_csv(out / "function_means.csv")
std.to_csv(out / "function_std.csv")
med.to_csv(out / "function_medians.csv")

ranks = means.rank(axis=1)
rank_summary = pd.DataFrame({
    "AverageRank": ranks.mean(),
    "MedianRank": ranks.median(),
    "BestCount": (ranks == 1).sum(),
}).reindex(methods)
rank_summary["Label"] = [LABELS[m] for m in methods]
rank_summary.to_csv(out / "mean_ranks.csv")

# paired comparisons of the new method against every baseline
rows = []
for ref in methods:
    if ref == NEW:
        continue
    b = allruns[allruns.Method.eq(ref)].set_index(["FunctionID", "Seed"]).FinalError
    a = allruns[allruns.Method.eq(NEW)].set_index(["FunctionID", "Seed"]).FinalError.reindex(b.index)
    d = (a - b).to_numpy()
    ratio = means[NEW] / means[ref]
    pvs = []
    for fid in means.index:
        z = allruns[allruns.FunctionID.eq(fid)].pivot(index="Seed", columns="Method",
                                                     values="FinalError")
        dd = (z[NEW] - z[ref]).to_numpy()
        pv = 1.0 if np.all(dd == 0) else float(wilcoxon(dd, zero_method="wilcox",
                                                        method="auto").pvalue)
        nz = dd[np.abs(dd) > 0]
        rb = 0.0 if not len(nz) else float(np.sum(rankdata(np.abs(nz)) * np.sign(-nz))
                                          / np.sum(rankdata(np.abs(nz))))
        pvs.append(dict(FunctionID=int(fid), MeanRatio=float(ratio.loc[fid]), P=float(pv),
                        RankBiserial=rb, SeedWins=int((dd < 0).sum()),
                        SeedLosses=int((dd > 0).sum())))
    detail = pd.DataFrame(pvs)
    adj = np.empty(len(detail))
    running = 0.0
    for k, i in enumerate(np.argsort(detail.P.to_numpy())):
        running = max(running, (len(detail) - k) * detail.P.to_numpy()[i])
        adj[i] = min(1.0, running)
    detail["Holm"] = adj
    detail.to_csv(out / f"vs_{ref.replace('-', '_')}.csv", index=False)
    rows.append(dict(Reference=LABELS[ref],
                     FuncMeanWins=int((ratio < 1).sum()), FuncMeanLosses=int((ratio > 1).sum()),
                     SeedWins=int((d < 0).sum()), SeedLosses=int((d > 0).sum()),
                     MedianRatio=float(ratio.median()),
                     GeomeanRatio=float(np.exp(np.log(ratio).mean())),
                     HolmSignificant=int((detail.Holm < 0.05).sum()),
                     BestFunctionRatio=float(ratio.min()), WorstFunctionRatio=float(ratio.max())))
comp = pd.DataFrame(rows)
comp.to_csv(out / "vs_baselines.csv", index=False)

(out / "config.json").write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf8")
print(rank_summary.round(4).to_string())
print()
print(comp.round(4).to_string(index=False))
print()
print(means.round(4).to_string())
print(out)
