"""Formal comparison of the quota-split variants against the paired baselines."""
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
SHARES = cfg["NearShares"]
NAMES = {0.5: "Q50 (baseline split)", 0.7: "Q70", 0.85: "Q85"}
LABELS = {
    "ASC-NoFarness": "ASC-NoFarness",
    "CLPSO-AuthorSource": "CLPSO", "HCLPSO-AuthorSource": "HCLPSO",
    "HPSO-TVAC-CEC": "HPSO-TVAC", "DMS-PSO-SIS2005": "DMS-PSO",
    "SPSO-2011-OfficialC": "SPSO-2011",
}

new = pd.read_csv(run / "raw_runs.csv")
assert new.Status.eq("ok").all()
assert len(new) == cfg["FreshRuns"] == 870
assert new.ObjectiveCalls.eq(100000).all() and new.OutsideCalls.eq(0).all()
assert new.BestDiff.eq(0).all()
new = new.copy()
new["Method"] = new.NearShare.map(lambda s: f"Q{int(round(s*100))}")

old = pd.read_csv(ROOT / "results/asc_comparison_30seed_20261015/all_runs.csv")
seeds = sorted(new.Seed.unique().tolist())
old = old[old.Seed.isin(seeds)]
keep = ["FunctionID", "Seed", "Method", "FinalError", "Seconds", "Evaluations",
        "ObjectiveCalls", "OutsideCalls", "Status"]
allruns = pd.concat([old[old.Method.isin(LABELS)][keep], new[keep]], ignore_index=True)
methods = ["ASC-NoFarness"] + [f"Q{int(round(s*100))}" for s in SHARES] \
    + ["CLPSO-AuthorSource", "HCLPSO-AuthorSource", "HPSO-TVAC-CEC",
       "DMS-PSO-SIS2005", "SPSO-2011-OfficialC"]
allruns = allruns[allruns.Method.isin(methods)]
assert len(allruns) == len(methods) * 29 * len(seeds), (len(allruns), len(methods) * 29 * len(seeds))
for m in [f"Q{int(round(s*100))}" for s in SHARES]:
    assert len(allruns[allruns.Method.eq(m)]) == 29 * len(seeds)

out = ROOT / "results/asc_quota_balance_29f_10seed_20261015"
out.mkdir(parents=True, exist_ok=True)
means = allruns.groupby(["FunctionID", "Method"]).FinalError.mean().unstack().reindex(columns=methods)
std = allruns.groupby(["FunctionID", "Method"]).FinalError.std().unstack().reindex(columns=methods)
means.to_csv(out / "function_means.csv")
std.to_csv(out / "function_std.csv")

ranks = means.rank(axis=1)
rank_summary = pd.DataFrame({
    "AverageRank": ranks.mean(), "MedianRank": ranks.median(),
    "BestCount": (ranks == 1).sum(),
    "Label": [NAMES.get(m, LABELS.get(m, m)) for m in methods],
}).reindex(methods)
rank_summary.to_csv(out / "mean_ranks.csv")

rows = []
for prop in [f"Q{int(round(s*100))}" for s in SHARES]:
    for ref in methods:
        if ref == prop:
            continue
        b = allruns[allruns.Method.eq(ref)].set_index(["FunctionID", "Seed"]).FinalError
        a = allruns[allruns.Method.eq(prop)].set_index(
            ["FunctionID", "Seed"]).FinalError.reindex(b.index)
        d = (a - b).to_numpy()
        ratio = means[prop] / means[ref]
        pvs = []
        for fid in means.index:
            z = allruns[allruns.FunctionID.eq(fid)].pivot(index="Seed", columns="Method",
                                                         values="FinalError")
            dd = (z[prop] - z[ref]).to_numpy()
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
        detail.to_csv(out / f"{prop}_vs_{ref.replace('-', '_')}.csv", index=False)
        rows.append(dict(Proposed=NAMES.get(prop, prop),
                         Reference=LABELS.get(ref, ref),
                         FuncMeanWins=int((ratio < 1).sum()),
                         FuncMeanLosses=int((ratio > 1).sum()),
                         SeedWins=int((d < 0).sum()), SeedLosses=int((d > 0).sum()),
                         MedianRatio=float(ratio.median()),
                         GeomeanRatio=float(np.exp(np.log(ratio).mean())),
                         HolmSignificant=int((detail.Holm < 0.05).sum()),
                         BestFunctionRatio=float(ratio.min()),
                         WorstFunctionRatio=float(ratio.max())))
comp = pd.DataFrame(rows)
comp.to_csv(out / "vs_baselines.csv", index=False)

print(rank_summary.round(4).to_string())
print()
print(comp.round(4).to_string(index=False))
print()
print(means.round(4).to_string())
print(out)
