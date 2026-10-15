"""Freeze a starvation-guard 2x2 run directory (G00/G01/G10/G11)."""
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


PRIMARY = [1, 6, 9, 12, 13, 21, 24, 27]
CROSS = [3, 4, 17, 29]
# method name = G<guard><cognition>
METHODS = {"G00": (0, "C00"), "G01": (0, "C11"), "G10": (100, "C00"), "G11": (100, "C11")}
SEEDS = list(range(6301, 6311))

vdir = ROOT / "work/sg_validation_20261015"
v = json.loads((vdir / "validation.json").read_text(encoding="utf8"))
assert v["Passed"], "the correctness audit must pass before a run directory is frozen"
assert v["EngineSHA256"] == sha(ROOT / "ASC_NoFarness_StarvationGuard.m")
assert v["StageSHA256"] == sha(ROOT / "ASC_NoFarness_StageLearning.m")
assert v["OriginalSHA256"] == sha(ROOT / "ASC_NoFarness.m")

old = ROOT / "results/asc_comparison_30seed_20261015"
raw = pd.read_csv(old / "all_runs.csv")
ref = raw[(raw.Method == "ASC-NoFarness") & (raw.FunctionID == 1) & (raw.Seed == 3001)]
assert len(ref) == 1
artifact = Path(ref.iloc[0].ArtifactPath)
assert artifact.is_file(), f"missing reference artifact {artifact}"
assert sha(old / "source/ASC_NoFarness.m") == v["OriginalSHA256"]

for h in pd.read_csv(ROOT / "data/cec2017/D50_manifest.csv").itertuples():
    assert sha(ROOT / "data/cec2017/input_data" / h.File) == h.SHA256

stamp = datetime.now(ZoneInfo("America/New_York")).strftime("%Y%m%d_%H%M%S")
run = ROOT / "results/cec" / f"asc_sg_study_{stamp}"
for sub in ["source", "runs", "cec_data/input_data"]:
    (run / sub).mkdir(exist_ok=True, parents=True)

for rel in [
    "ASC_NoFarness.m",
    "ASC_NoFarness_StarvationGuard.m",
    "experiments/run_asc_sg_job.m",
    "experiments/run_asc_sg_study.m",
    "tests/test_ASC_NoFarness_StarvationGuard.m",
    "archive/legacy/CEC2017Function.m",
]:
    shutil.copy2(ROOT / rel, run / "source" / Path(rel).name)
for name in ["cec17_func.cpp", "cec17_func.mexw64"]:
    shutil.copy2(ROOT / "data/cec2017" / name, run / "cec_data" / name)

funcs = PRIMARY + CROSS
for fid in funcs:
    for name in [
        f"shift_data_{fid}.txt",
        f"M_{fid}_D50.txt",
        f"shuffle_data_{fid}_D50.txt",
    ]:
        p = ROOT / "data/cec2017/input_data" / name
        assert p.is_file(), f"missing benchmark input {p}"
        shutil.copy2(p, run / "cec_data/input_data" / name)

for name in ["validation.json", "checks.csv"]:
    shutil.copy2(vdir / name, run / name)
shutil.copy2(
    ROOT / "docs/ASC_STARVATION_GUARD_PROTOCOL_20261015.md", run / "PROTOCOL.md"
)

jobs = []
for fid in funcs:
    for seed in SEEDS:
        init = 262015000 + fid * 10000 + seed
        for method, (guard, schedule) in METHODS.items():
            jobs.append(
                dict(
                    JobID=len(jobs) + 1,
                    FunctionID=fid,
                    Seed=seed,
                    Method=method,
                    Schedule=schedule,
                    GuardRounds=guard,
                    InitSeed=init,
                    SearchSeed=init,
                    CogSeed=init + 7777777,
                    Split="primary" if fid in PRIMARY else "cross",
                )
            )
pd.DataFrame(jobs).to_csv(run / "jobs.csv", index=False)

cfg = dict(
    Date="2026-10-15",
    Timezone="America/New_York",
    Dimension=50,
    Population=50,
    Budget=100000,
    PrimaryFunctions=PRIMARY,
    CrossFunctions=CROSS,
    Seeds=SEEDS,
    Methods=list(METHODS),
    MethodSpec={k: dict(GuardRounds=v0, LearnSchedule=v1) for k, (v0, v1) in METHODS.items()},
    GuardRounds=100,
    SwitchProgress=0.50,
    CognitiveShare=0.50,
    CogSeedOffset=7777777,
    Workers=4,
    FreshRuns=len(jobs),
    OptimizationCalls=len(jobs) * 100000,
    ReferenceArtifact=str(artifact),
    OriginalSHA256=v["OriginalSHA256"],
    EngineSHA256=v["EngineSHA256"],
    OriginalSourceUnchanged=True,
    UnseenFunctions=False,
    Stage="development",
    ConfirmOnlyIfGatePasses=True,
)
write(run / "config.json", cfg)

hashes = [
    dict(
        Path=str(p),
        RelativePath=str(p.relative_to(run)),
        SHA256=sha(p),
        Bytes=p.stat().st_size,
    )
    for p in sorted(run.rglob("*"))
    if p.is_file()
]
pd.DataFrame(hashes).to_csv(run / "prelaunch_hashes.csv", index=False)
write(
    run / "status.json",
    dict(Status="prepared", Completed=0, Total=len(jobs), Directory=str(run)),
)
(ROOT / "work/sg_latest.txt").write_text(str(run), encoding="utf8")
launcher = (
    "addpath('"
    + (run / "source").as_posix()
    + "','-begin');\nrun_asc_sg_study('"
    + run.as_posix()
    + "');\n"
)
(ROOT / "work/launch_asc_sg_study.m").write_text(launcher, encoding="utf8")
print(run)
