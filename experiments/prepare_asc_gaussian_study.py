from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,shutil
import pandas as pd
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2),encoding='utf8')
vdir=ROOT/'work/asc_gaussian_validation_20261015';v=json.loads((vdir/'validation.json').read_text(encoding='utf8'));assert v['Passed']
assert v['EngineSHA256']==sha(ROOT/'ASC_NoFarness_EliteGaussian.m') and v['OriginalSHA256']==sha(ROOT/'ASC_NoFarness.m')
old=ROOT/'results/asc_comparison_30seed_20261015';raw=pd.read_csv(old/'all_runs.csv');ref=raw[raw.Method.eq('ASC-NoFarness')&raw.FunctionID.eq(1)&raw.Seed.eq(3001)];assert len(ref)==1
artifact=Path(ref.iloc[0].ArtifactPath);assert artifact.is_file()
assert sha(old/'source/ASC_NoFarness.m')==v['OriginalSHA256']
for h in pd.read_csv(ROOT/'data/cec2017/D50_manifest.csv').itertuples():assert sha(ROOT/'data/cec2017/input_data'/h.File)==h.SHA256
stamp=datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S');run=ROOT/'results/cec'/f'asc_gaussian_study_{stamp}'
for sub in ['source','runs','cec_data/input_data']:(run/sub).mkdir(exist_ok=True,parents=True)
for rel in ['ASC_NoFarness.m','ASC_NoFarness_EliteGaussian.m','experiments/run_asc_gaussian_job.m','experiments/run_asc_gaussian_study.m','tests/test_ASC_NoFarness_EliteGaussian.m','archive/legacy/CEC2017Function.m']:
 shutil.copy2(ROOT/rel,run/'source'/Path(rel).name)
for name in ['cec17_func.cpp','cec17_func.mexw64']:shutil.copy2(ROOT/'data/cec2017'/name,run/'cec_data'/name)
funcs=[1,6,9,12,13,21,24,27]
for fid in funcs:
 for name in [f'shift_data_{fid}.txt',f'M_{fid}_D50.txt',f'shuffle_data_{fid}_D50.txt']:
  p=ROOT/'data/cec2017/input_data'/name
  if p.exists():shutil.copy2(p,run/'cec_data/input_data'/name)
for name in ['validation.json','checks.csv']:shutil.copy2(vdir/name,run/name)
shutil.copy2(ROOT/'docs/ASC_ELITE_GAUSSIAN_PROTOCOL_20261015.md',run/'PROTOCOL.md')
methods=['A0','A1','A2','A3'];jobs=[]
for fid in funcs:
 for seed in range(6001,6011):
  init=261013000+fid*10000+seed
  for method in methods:jobs.append(dict(JobID=len(jobs)+1,FunctionID=fid,Seed=seed,Method=method,InitSeed=init,SearchSeed=init+1000000,ProbeSeed=init+1000000+9100001))
pd.DataFrame(jobs).to_csv(run/'jobs.csv',index=False)
cfg=dict(Date='2026-10-15',Timezone='America/New_York',Dimension=50,Population=50,Budget=100000,Functions=funcs,Seeds=list(range(6001,6011)),Methods=methods,Workers=4,FreshRuns=320,OptimizationCalls=32000000,ReferenceArtifact=str(artifact),OriginalSHA256=v['OriginalSHA256'],EngineSHA256=v['EngineSHA256'],OriginalSourceUnchanged=True,UnseenFunctions=False,ProbeEveryRounds=5,ProbeDimensions=5,SigmaStart=.05,SigmaEnd=.005,Stage='development',ConfirmOnlyIfGatePasses=True)
write(run/'config.json',cfg)
hashes=[dict(Path=str(p),RelativePath=str(p.relative_to(run)),SHA256=sha(p),Bytes=p.stat().st_size) for p in sorted(run.rglob('*')) if p.is_file()]
pd.DataFrame(hashes).to_csv(run/'prelaunch_hashes.csv',index=False)
write(run/'status.json',dict(Status='prepared',Completed=0,Total=320,Directory=str(run)))
(ROOT/'work/asc_gaussian_latest.txt').write_text(str(run),encoding='utf8')
launcher="addpath('"+(run/'source').as_posix()+"','-begin');"+chr(10)+"run_asc_gaussian_study('"+run.as_posix()+"');"+chr(10)
(ROOT/'work/launch_asc_gaussian_study.m').write_text(launcher,encoding='utf8')
print(run)
