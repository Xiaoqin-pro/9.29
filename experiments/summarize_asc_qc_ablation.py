"""Ablation table for the quota split and the cognitive Tracing direction."""
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
QB = Path(cfg["ReuseQuotaRun"])
LABELS = {
    "ASC-NoFarness": "ASC-NoFarness (reference)",
    "C00_Q50": "A0: base split, no cognition",
    "C00_Q85": "A1: re-balanced split only",
    "C01_Q50": "A2: cognition only",
    "C01_Q85": "A3: re-balanced split + cognition",
    "CLPSO-AuthorSource": "CLPSO", "HCLPSO-AuthorSource": "HCLPSO",
    "HPSO-TVAC-CEC": "HPSO-TVAC", "DMS-PSO-SIS2005": "DMS-PSO",
    "SPSO-2011-OfficialC": "SPSO-2011",
}
ORDER = ["C00_Q50", "C00_Q85", "C01_Q50", "C01_Q85"]

qb = pd.read_csv(QB)
qb["Method"] = qb.NearShare.map(lambda s: f"C00_Q{int(round(s*100))}")
qb = qb[qb.Method.isin(["C00_Q50", "C00_Q85"])]

qc = pd.read_csv(run / "raw_runs.csv")
assert qc.Status.eq("ok").all() and len(qc) == cfg["FreshRuns"] == 580
assert qc.ObjectiveCalls.eq(100000).all() and qc.OutsideCalls.eq(0).all()
assert qc.BestDiff.eq(0).all()
qc["Method"] = [f"{s}_Q{int(round(n*100))}" for s, n in zip(qc.Schedule, qc.NearShare)]
assert set(qc.Method) == {"C01_Q50", "C01_Q85"}

seeds = sorted(qc.Seed.unique().tolist())
old = pd.read_csv(ROOT / "results/asc_comparison_30seed_20261015/all_runs.csv")
old = old[old.Seed.isin(seeds) & old.Method.isin(LABELS)]
keep = ["FunctionID", "Seed", "Method", "FinalError", "Seconds", "Evaluations",
        "ObjectiveCalls", "OutsideCalls", "Status"]
allruns = pd.concat([old[keep], qb[keep], qc[keep]], ignore_index=True)
methods = ORDER + [m for m in LABELS if m not in ORDER and m != "ASC-NoFarness"]
methods = ["ASC-NoFarness"] + methods
allruns = allruns[allruns.Method.isin(methods)]
assert len(allruns) == len(methods) * 29 * len(seeds), (len(allruns), len(methods) * 29 * len(seeds))

out = ROOT / "results/asc_quota_cognition_ablation_29f_10seed_20261015"
out.mkdir(parents=True, exist_ok=True)
means = allruns.groupby(["FunctionID", "Method"]).FinalError.mean().unstack().reindex(columns=methods)
std = allruns.groupby(["FunctionID", "Method"]).FinalError.std().unstack().reindex(columns=methods)
means.to_csv(out / "function_means.csv")
std.to_csv(out / "function_std.csv")

ranks = means.rank(axis=1)
rank_summary = pd.DataFrame({
    "AverageRank": ranks.mean(), "MedianRank": ranks.median(),
    "BestCount": (ranks == 1).sum(),
    "Label": [LABELS.get(m, m) for m in methods],
}).reindex(methods)
rank_summary.to_csv(out / "mean_ranks.csv")

rows = []
detail_all = {}
for prop in ORDER + ["ASC-NoFarness"]:
    for ref in ORDER + ["ASC-NoFarness"]:
        if ref == prop or ref == "ASC-NoFarness" and prop == "ASC-NoFarness":
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
        detail_all[(prop, ref)] = detail
        rows.append(dict(Proposed=LABELS.get(prop, prop), Reference=LABELS.get(ref, ref),
                         FuncMeanWins=int((ratio < 1).sum()),
                         FuncMeanLosses=int((ratio > 1).sum()),
                         SeedWins=int((d < 0).sum()), SeedLosses=int((d > 0).sum()),
                         MedianRatio=float(ratio.median()),
                         GeomeanRatio=float(np.exp(np.log(ratio).mean())),
                         HolmSignificant=int((detail.Holm < 0.05).sum()),
                         WorstFunctionRatio=float(ratio.max())))
comp = pd.DataFrame(rows)
comp.to_csv(out / "ablation_pairs.csv", index=False)
detail_all[("C01_Q85", "C00_Q50")].to_csv(out / "A3_vs_reference_detail.csv", index=False)
detail_all[("C01_Q85", "C00_Q85")].to_csv(out / "A3_vs_A1_detail.csv", index=False)
detail_all[("C01_Q85", "C01_Q50")].to_csv(out / "A3_vs_A2_detail.csv", index=False)

print(rank_summary.round(4).to_string())
print()
print(comp.round(4).to_string(index=False))
print()
print(means[["ASC-NoFarness"] + ORDER].round(4).to_string())
print(out)
