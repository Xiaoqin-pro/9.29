"""深开发 / 速度重置单因素批次的汇总与配对比较。

输出三种视角：
  1) 开发强度扫描：固定 Seeking 概率 0.20 / 0.10 / 0.05 / 0.02（Tracing 80%–98%），
     以及 ASC 默认自适应律（实测约 0.21）与 1:1 配额基线；
  2) 速度重置负对照：自适应概率但 Seeking 轮不清零速度；
  3) 相对当前最优（9:1 配额 + 自适应概率）的逐函数变化，用于判断是否存在
     "过度开发"的翻转点。
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
NEAR_SHARE = cfg["NearShare"]

LABELS = {
    "ASC-NoFarness": "R0: 1:1 quota, adaptive prob (original)",
    "QB085":         "R1: 9:1 quota, adaptive prob (current best)",
    "P20":           "T80: 9:1 quota, fixed Seeking 0.20",
    "P10":           "T90: 9:1 quota, fixed Seeking 0.10",
    "P05":           "T95: 9:1 quota, fixed Seeking 0.05",
    "P02":           "T98: 9:1 quota, fixed Seeking 0.02",
    "V21":           "Ctl: adaptive prob, no velocity reset",
}
ORDER = ["ASC-NoFarness", "QB085", "P20", "P10", "P05", "P02", "V21"]

# 新跑的批次
new = pd.read_csv(run / "raw_runs.csv")
assert new.Status.eq("ok").all()
assert len(new) == cfg["FreshRuns"] == 1450
assert new.ObjectiveCalls.eq(100000).all() and new.OutsideCalls.eq(0).all()
assert new.BestDiff.eq(0).all()
new = new.copy()
new["Method"] = new.Tag
for tag, spec in cfg["Conditions"].items():
    sub = new[new.Tag.eq(tag)]
    if spec[0] == 1:
        assert np.allclose(sub.MeanSeekProb, sub.MeanSeekProb.iloc[0], atol=0.05)
    else:
        assert np.allclose(sub.MeanSeekProb, spec[1], atol=1e-9), tag

seeds = sorted(new.Seed.unique().tolist())
keep = ["FunctionID", "Seed", "Method", "FinalError"]

# 参考 R0：既有 30 种子对比批中的原版 ASC-NoFarness（同种子子集）
old = pd.read_csv(ROOT / "results/asc_comparison_30seed_20261015/all_runs.csv")
r0 = old[old.Method.eq("ASC-NoFarness") & old.Seed.isin(seeds)][keep]

# 参考 R1：配额批次中的 nearShare = 0.85 运行（同种子子集）
qb = pd.read_csv(ROOT / "results/cec/asc_qb_study_20261015_213645/raw_runs.csv")
r1 = qb[(qb.NearShare == NEAR_SHARE) & qb.Seed.isin(seeds)][
    ["FunctionID", "Seed", "FinalError"]].copy()
r1["Method"] = "QB085"

allruns = pd.concat([r0, r1, new[keep]], ignore_index=True)
methods = ORDER
allruns = allruns[allruns.Method.isin(methods)]
assert len(allruns) == len(methods) * 29 * len(seeds), (len(allruns), len(methods) * 29 * len(seeds))

out = ROOT / "results/asc_deep_tracing_29f_10seed_20261015"
out.mkdir(parents=True, exist_ok=True)
means = allruns.groupby(["FunctionID", "Method"]).FinalError.mean().unstack().reindex(columns=methods)
std = allruns.groupby(["FunctionID", "Method"]).FinalError.std().unstack().reindex(columns=methods)
means.to_csv(out / "function_means.csv")
std.to_csv(out / "function_std.csv")

ranks = means.rank(axis=1)
rank_summary = pd.DataFrame({
    "AverageRank": ranks.mean(), "MedianRank": ranks.median(),
    "BestCount": (ranks == 1).sum(), "Label": [LABELS[m] for m in methods],
}).reindex(methods)
rank_summary.to_csv(out / "mean_ranks.csv")

ref = "QB085"
rows, details = [], {}
for prop in methods:
    if prop == ref:
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
    details[prop] = detail
    detail.to_csv(out / f"{prop}_vs_{ref}.csv", index=False)
    rows.append(dict(Condition=LABELS[prop], FuncMeanWins=int((ratio < 1).sum()),
                     FuncMeanLosses=int((ratio > 1).sum()),
                     SeedWins=int((d < 0).sum()), SeedLosses=int((d > 0).sum()),
                     MedianRatio=float(ratio.median()),
                     GeomeanRatio=float(np.exp(np.log(ratio).mean())),
                     HolmSignificant=int((detail.Holm < 0.05).sum()),
                     BestFunctionRatio=float(ratio.min()),
                     WorstFunctionRatio=float(ratio.max())))
comp = pd.DataFrame(rows)
comp.to_csv(out / f"vs_{ref}.csv", index=False)

print("平均排名（29 函数，10 配对种子）")
print(rank_summary.round(4).to_string())
print(f"\n相对 {LABELS[ref]} 的配对比较")
print(comp.round(4).to_string(index=False))
print("\n逐函数均值")
print(means.round(4).to_string())

tracer = new.groupby("Tag")[["MeanSeekProb", "EarlySeekProb", "LateSeekProb",
                             "MeanRadius", "Rounds"]].mean()
tracer.to_csv(out / "developer_strength_trace.csv")
print("\n开发强度实测（新条件）")
print(tracer.round(4).to_string())
print(out)
