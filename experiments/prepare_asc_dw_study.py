"""Freeze the 29-function formal run of the selected hybrid (M3 = C01 + A2).

The seeds, initial populations and search seeds are taken from the existing
30-seed comparison batch so that the new method is paired with every baseline
already in the repository.
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


METHOD = "M4-DimWise"
SCHEDULE, SEEK = "C01", "A4"

vdir = ROOT / "work/dw_validation_20261015"
v = json.loads((vdir / "validation.json").read_text(encoding="utf8"))
assert v["Passed"]
assert v["EngineSHA256"] == sha(ROOT / "ASC_NoFarness_DimWise.m")
assert v["OriginalSHA256"] == sha(ROOT / "ASC_NoFarness.m")

old = ROOT / "results/asc_comparison_30seed_20261015"
raw = pd.read_csv(old / "all_runs.csv")
ref = raw[(raw.Method == "ASC-NoFarness") & (raw.FunctionID == 1) & (raw.Seed == 3001)]
assert len(ref) == 1
artifact = Path(ref.iloc[0].ArtifactPath)
assert artifact.is_file()

seedmap = raw[raw.Method.eq("ASC-NoFarness")][["FunctionID", "Seed", "InitSeed", "SearchSeed"]] \
    .drop_duplicates()
assert len(seedmap) == 29 * 30

for h in pd.read_csv(ROOT / "data/cec2017/D50_manifest.csv").itertuples():
    assert sha(ROOT / "data/cec2017/input_data" / h.File) == h.SHA256

stamp = datetime.now(ZoneInfo("America/New_York")).strftime("%Y%m%d_%H%M%S")
run = ROOT / "results/cec" / f"asc_dw_study_{stamp}"
for sub in ["source", "runs", "cec_data/input_data"]:
    (run / sub).mkdir(exist_ok=True, parents=True)

for rel in ["ASC_NoFarness.m", "ASC_NoFarness_DimWise.m", "experiments/run_asc_dw_job.m",
            "experiments/run_asc_dw_study.m", "tests/test_ASC_NoFarness_DimWise.m",
            "archive/legacy/CEC2017Function.m"]:
    shutil.copy2(ROOT / rel, run / "source" / Path(rel).name)
for name in ["cec17_func.cpp", "cec17_func.mexw64"]:
    shutil.copy2(ROOT / "data/cec2017" / name, run / "cec_data" / name)

funcs = sorted(raw.FunctionID.unique().tolist())
for fid in funcs:
    for name in [f"shift_data_{fid}.txt", f"M_{fid}_D50.txt", f"shuffle_data_{fid}_D50.txt"]:
        p = ROOT / "data/cec2017/input_data" / name
        assert p.is_file(), f"missing benchmark input {p}"
        shutil.copy2(p, run / "cec_data/input_data" / name)

for name in ["validation.json", "checks.csv"]:
    shutil.copy2(vdir / name, run / name)

jobs = []
for row in seedmap.sort_values(["FunctionID", "Seed"]).itertuples():
    jobs.append(dict(JobID=len(jobs) + 1, FunctionID=int(row.FunctionID), Seed=int(row.Seed),
                     Method=METHOD, Schedule=SCHEDULE, SeekVariant=SEEK, SeekRefineCount=2,
                     InitSeed=int(row.InitSeed), SearchSeed=int(row.SearchSeed),
                     Split="formal"))
pd.DataFrame(jobs).to_csv(run / "jobs.csv", index=False)

cfg = dict(Date="2026-10-15", Timezone="America/New_York", Dimension=50, Population=50,
           Budget=100000, Functions=funcs, Seeds=sorted(seedmap.Seed.unique().tolist()),
           Methods=[METHOD], PrimaryFunctions=funcs, CrossFunctions=[],
           MethodSpec={METHOD: dict(CogSchedule=SCHEDULE, SeekVariant=SEEK)},
           SwitchProgress=0.50, CognitiveShare=0.50, CogSeedOffset=7777777,
           SeekRefineCount=2, EliteGuideGain=0.25, Workers=4, FreshRuns=len(jobs),
           OptimizationCalls=len(jobs) * 100000, ReferenceArtifact=str(artifact),
           OriginalSHA256=v["OriginalSHA256"], EngineSHA256=v["EngineSHA256"],
           PairedWith="results/asc_comparison_30seed_20261015",
           OriginalSourceUnchanged=True, UnseenFunctions=False, Stage="formal")
write(run / "config.json", cfg)
hashes = [dict(Path=str(p), RelativePath=str(p.relative_to(run)), SHA256=sha(p),
               Bytes=p.stat().st_size)
          for p in sorted(run.rglob("*")) if p.is_file()]
pd.DataFrame(hashes).to_csv(run / "prelaunch_hashes.csv", index=False)
write(run / "status.json", dict(Status="prepared", Completed=0, Total=len(jobs),
                                Directory=str(run)))
(ROOT / "work/dw_latest.txt").write_text(str(run), encoding="utf8")
print(run)
