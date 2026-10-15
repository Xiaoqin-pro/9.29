from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,shutil
import pandas as pd
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2),encoding='utf8')
vdir=ROOT/'work/asc_jump_validation_20261015';v=json.loads((vdir/'validation.json').read_text(encoding='utf8'));assert v['Passed']
assert v['EngineSHA256']==sha(ROOT/'ASC_NoFarness.m')
prior=ROOT/'results/asc_comparison_30seed_20261015';assert sha(prior/'source/ASC_NoFarness.m')==v['EngineSHA256']
ref=pd.read_csv(prior/'all_runs.csv');ref=ref[ref.Method.eq('ASC-NoFarness')&ref.FunctionID.eq(1)&ref.Seed.eq(3001)];assert len(ref)==1
artifact=Path(ref.iloc[0].ArtifactPath);assert artifact.is_file()
for h in pd.read_csv(ROOT/'data/cec2017/D50_manifest.csv').itertuples():assert sha(ROOT/'data/cec2017/input_data'/h.File)==h.SHA256
stamp=datetime.now(ZoneInfo('America/New_York')).strftime('%Y%m%d_%H%M%S');run=ROOT/'results/cec'/f'asc_jump_study_{stamp}'
for sub in ['source','runs','cec_data/input_data']:(run/sub).mkdir(exist_ok=True,parents=True)
for rel in ['ASC_NoFarness.m','experiments/run_asc_jump_job.m','experiments/run_asc_jump_study.m','tests/test_ASC_JumpControls.m','archive/legacy/CEC2017Function.m']:
 shutil.copy2(ROOT/rel,run/'source'/Path(rel).name)
for name in ['cec17_func.cpp','cec17_func.mexw64']:shutil.copy2(ROOT/'data/cec2017'/name,run/'cec_data'/name)
funcs=[1,6,9,13,21,22,27,30]
for fid in funcs:
 for name in [f'shift_data_{fid}.txt',f'M_{fid}_D50.txt',f'shuffle_data_{fid}_D50.txt']:
  p=ROOT/'data/cec2017/input_data'/name
  if p.exists():shutil.copy2(p,run/'cec_data/input_data'/name)
for name in ['validation.json','checks.csv']:shutil.copy2(vdir/name,run/name)
shutil.copy2(ROOT/'docs/ASC_JUMP_STUDY_PROTOCOL_20261015.md',run/'PROTOCOL.md')
methods=['Original','NoJump','LightJump'];jobs=[]
for fid in funcs:
 for seed in range(5001,5011):
  init=261013000+fid*10000+seed
  for method in methods:jobs.append(dict(JobID=len(jobs)+1,FunctionID=fid,Seed=seed,Method=method,InitSeed=init,SearchSeed=init+1000000,UseJump=int(method!='NoJump'),JumpFraction=.10 if method=='LightJump' else .50))
pd.DataFrame(jobs).to_csv(run/'jobs.csv',index=False)
cfg=dict(Date='2026-10-15',Timezone='America/New_York',Dimension=50,Population=50,Budget=100000,Functions=funcs,Seeds=list(range(5001,5011)),Methods=methods,Workers=4,FreshRuns=240,OptimizationCalls=24000000,ReferenceArtifact=str(artifact),OriginalSHA256=v['EngineSHA256'],OriginalSourceUnchanged=True,UnseenFunctions=False)
write(run/'config.json',cfg)
hashes=[]
for p in sorted(run.rglob('*')):
 if p.is_file():hashes.append(dict(Path=str(p),RelativePath=str(p.relative_to(run)),SHA256=sha(p),Bytes=p.stat().st_size))
pd.DataFrame(hashes).to_csv(run/'prelaunch_hashes.csv',index=False)
write(run/'status.json',dict(Status='prepared',Completed=0,Total=240,Directory=str(run)))
(ROOT/'work/asc_jump_latest.txt').write_text(str(run),encoding='utf8')
launcher="addpath('"+(run/'source').as_posix()+"','-begin');"+chr(10)+"run_asc_jump_study('"+run.as_posix()+"');"+chr(10)
(ROOT/'work/launch_asc_jump_study.m').write_text(launcher,encoding='utf8')
print(run)
