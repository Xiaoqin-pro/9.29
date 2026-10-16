"""冻结深开发 / 速度重置单因素批次。

五个条件都使用配额 9:1（nearShare = 0.85），只改与"开发强度"有关的两个开关：
  P20/P10/P05/P02：固定 Seeking 概率（Tracing 比例 = 1 - 该值），速度重置保持默认
  V21：自适应 Seeking 概率（ASC 默认律），但 Seeking 轮不清零速度
对照组 R0（原 1:1 配额）与 R1（9:1 配额、自适应概率）直接取自既有运行，种子相同。
"""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, shutil
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def write(p, x):
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2), encoding="utf8")


# tag -> (useAdaptiveProb, seekProbFixed, resetVelOnSeek, tracing fraction label)
CONDITIONS = {
    "P20": (0, 0.20, 1),
    "P10": (0, 0.10, 1),
    "P05": (0, 0.05, 1),
    "P02": (0, 0.02, 1),
    "V21": (1, 0.40, 0),      # seekProbFixed 在自适应模式下不生效
}
NEAR_SHARE = 0.85

vdir = ROOT / "work/dt_validation_20261015"
v = json.loads((vdir / "validation.json").read_text(encoding="utf8"))
assert v["Passed"], "深开发变体必须先通过谱系审计"
assert v["EngineSHA256"] == sha(ROOT / "ASC_NoFarness_DeepTracing.m")
assert v["OriginalSHA256"] == sha(ROOT / "ASC_NoFarness.m")

old = ROOT / "results/asc_comparison_30seed_20261015"
raw = pd.read_csv(old / "all_runs.csv")
ref = raw[(raw.Method == "ASC-NoFarness") & (raw.FunctionID == 1) & (raw.Seed == 3001)]
assert len(ref) == 1
seedmap = raw[raw.Method.eq("ASC-NoFarness")][
    ["FunctionID", "Seed", "InitSeed", "SearchSeed"]].drop_duplicates()
seedmap = seedmap[seedmap.Seed.isin(range(3001, 3011))]
assert len(seedmap) == 29 * 10
funcs = sorted(seedmap.FunctionID.unique().tolist())

for h in pd.read_csv(ROOT / "data/cec2017/D50_manifest.csv").itertuples():
    assert sha(ROOT / "data/cec2017/input_data" / h.File) == h.SHA256

stamp = datetime.now(ZoneInfo("America/New_York")).strftime("%Y%m%d_%H%M%S")
run = ROOT / "results/cec" / f"asc_dt_study_{stamp}"
for sub in ["source", "runs", "cec_data/input_data"]:
    (run / sub).mkdir(exist_ok=True, parents=True)

for rel in ["ASC_NoFarness.m", "ASC_NoFarness_DeepTracing.m",
            "experiments/run_asc_dt_job.m", "experiments/run_asc_dt_study.m",
            "tests/test_ASC_NoFarness_DeepTracing.m",
            "archive/legacy/CEC2017Function.m"]:
    shutil.copy2(ROOT / rel, run / "source" / Path(rel).name)
for name in ["cec17_func.cpp", "cec17_func.mexw64"]:
    shutil.copy2(ROOT / "data/cec2017" / name, run / "cec_data" / name)
for fid in funcs:
    for name in [f"shift_data_{fid}.txt", f"M_{fid}_D50.txt", f"shuffle_data_{fid}_D50.txt"]:
        p = ROOT / "data/cec2017/input_data" / name
        assert p.is_file(), f"缺少基准输入 {name}"
        shutil.copy2(p, run / "cec_data/input_data" / name)
for name in ["validation.json", "checks.csv"]:
    shutil.copy2(vdir / name, run / name)

jobs = []
for row in seedmap.sort_values(["FunctionID", "Seed"]).itertuples():
    for tag, (adapt, fixed, reset) in CONDITIONS.items():
        jobs.append(dict(JobID=len(jobs) + 1, FunctionID=int(row.FunctionID),
                         Seed=int(row.Seed), Tag=tag, NearShare=NEAR_SHARE,
                         UseAdaptiveProb=adapt, SeekProbFixed=fixed,
                         ResetVelOnSeek=reset, InitSeed=int(row.InitSeed),
                         SearchSeed=int(row.SearchSeed)))
pd.DataFrame(jobs).to_csv(run / "jobs.csv", index=False)

cfg = dict(Date="2026-10-15", Timezone="America/New_York", Dimension=50, Population=50,
           Budget=100000, NearShare=NEAR_SHARE, Functions=funcs,
           Seeds=sorted(seedmap.Seed.unique().tolist()), Conditions=CONDITIONS,
           Workers=4, FreshRuns=len(jobs), OptimizationCalls=len(jobs) * 100000,
           ReferenceArtifact=str(ref.iloc[0].ArtifactPath),
           OriginalSHA256=v["OriginalSHA256"], EngineSHA256=v["EngineSHA256"],
           PairedWith="results/asc_comparison_30seed_20261015")
write(run / "config.json", cfg)
hashes = [dict(Path=str(p), RelativePath=str(p.relative_to(run)), SHA256=sha(p),
               Bytes=p.stat().st_size)
          for p in sorted(run.rglob("*")) if p.is_file()]
pd.DataFrame(hashes).to_csv(run / "prelaunch_hashes.csv", index=False)
write(run / "status.json", dict(Status="prepared", Completed=0, Total=len(jobs),
                                Directory=str(run)))
(ROOT / "work/dt_latest.txt").write_text(str(run), encoding="utf8")
print(run, len(jobs))
