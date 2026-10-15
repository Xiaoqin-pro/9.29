"""Freeze ASC inputs and verified historical controls before a 4-worker run."""
from pathlib import Path
from datetime import datetime
import hashlib,json,shutil
import numpy as np
import pandas as pd
ROOT=Path(__file__).resolve().parents[1]
def digest(path,lf=False):
 b=Path(path).read_bytes();return hashlib.sha256(b.replace(b'\r\n',b'\n') if lf else b).hexdigest()
def write(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf8')
vdir=ROOT/'work/asc_position_rank_validation_20261015'
assert (vdir/'validation.json').exists(), 'Validation must complete first'
v=json.loads((vdir/'validation.json').read_text(encoding='utf8'));assert v['Passed']
assert digest(ROOT/'ASC_NoFarness.m')==v['OriginalSHA256'] and digest(ROOT/'ASC_NoFarness_PositionRank.m')==v['ImprovedSHA256']
refs=['SAQ-CSO','CLPSO-AuthorSource','HCLPSO-AuthorSource','HPSO-TVAC-CEC','SPSO-2011-OfficialC','DMS-PSO-SIS2005']
old=ROOT/'results/saq_cso_eightway_30seed_20261013';raw=pd.read_csv(old/'all_quality_runs.csv');raw=raw[raw.Condition.isin(refs)].copy()
assert len(raw)==5220 and raw.Status.eq('ok').all() and raw.Dimension.eq(50).all() and raw.Budget.eq(100000).all()
assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.OutsideCalls.eq(0).all()
assert not raw.duplicated(['FunctionID','Seed','Condition']).any()
assert raw.groupby(['FunctionID','Seed']).Condition.nunique().eq(6).all()
assert set(raw.FunctionID)==set([1]+list(range(3,31))) and set(raw.Seed)==set(range(3001,3031))
assert (raw.InitSeed==261013000+raw.FunctionID*10000+raw.Seed).all() and (raw.SearchSeed==raw.InitSeed+1000000).all()
relative={'SAQ-CSO':['src/SAQ_CSO.m','src/ASE_CSO_QuotaQ_Candidate.m','src/ASE_CSO_QuotaQ_Compact.m'],
 'CLPSO-AuthorSource':['src/CLPSO_CEC_AuthorSource.m'],'HCLPSO-AuthorSource':['src/HCLPSO_CEC_AuthorSource.m'],
 'HPSO-TVAC-CEC':['src/HPSO_TVAC_CEC.m'],'DMS-PSO-SIS2005':['src/DMS_PSO_SIS_CEC.m'],'SPSO-2011-OfficialC':['src/SPSO2011_CEC.m']}
source_checks=[]
for ref in refs:
 row=raw[raw.Condition.eq(ref)].iloc[0];snapshot=ROOT/'results/cec'/Path(row.RunDirectory).name/'source_snapshot'
 for rel in relative[ref]:
  assert digest(ROOT/rel,True)==digest(snapshot/rel,True),f'Cached source changed: {rel}'
  source_checks.append(dict(Method=ref,Source=rel,SHA256NormalizedLF=digest(ROOT/rel,True),SourceMatches=True))
sp=ROOT/'results/cec/spso2011_30seed_study_20261013_130252/source_snapshot'
pre=json.loads((sp/'preflight.json').read_text(encoding='utf8'));assert pre['Passed'] and pre['CrossLanguageOraclePairs']==34
assert digest(sp/'native_build/SPSO2011_native.mexw64')==pre['SourceHashes']['NativeMex']
# Verify the active CEC D50 files against the stored numerical-data manifest.
for row in pd.read_csv(ROOT/'data/cec2017/D50_manifest.csv').itertuples():
 assert digest(ROOT/'data/cec2017/input_data'/row.File)==row.SHA256
stamp=datetime.now().strftime('%Y%m%d_%H%M%S');run=ROOT/'results/cec'/f'asc_rank_30seed_{stamp}'
for sub in ['source','cec_data/input_data','runs','cache']:(run/sub).mkdir(parents=True,exist_ok=True)
sources=['ASC_NoFarness.m','ASC_NoFarness_PositionRank.m','experiments/run_asc_rank_job.m','experiments/run_asc_rank_comparison.m',
 'experiments/verify_asc_rank_cache.m','tests/test_ASC_PositionRank.m','archive/legacy/CEC2017Function.m']
for rel in sources:shutil.copy2(ROOT/rel,run/'source'/Path(rel).name)
for ref in refs:
 for rel in relative[ref]:shutil.copy2(ROOT/rel,run/'source'/Path(rel).name)
shutil.copy2(sp/'native_build/SPSO2011_native.mexw64',run/'source/SPSO2011_native.mexw64')
for name in ['cec17_func.mexw64','cec17_func.cpp']:shutil.copy2(ROOT/'data/cec2017'/name,run/'cec_data'/name)
for f in (ROOT/'data/cec2017/input_data').iterdir():
 if f.is_file() and ('D50' in f.name or f.name.startswith('shift_data_')):shutil.copy2(f,run/'cec_data/input_data'/f.name)
for name in ['validation.json','checks.csv']:shutil.copy2(vdir/name,run/name)
shutil.copy2(ROOT/'docs/ASC_POSITION_RANK_COMPARISON_PROTOCOL_20261015.md',run/'PROTOCOL.md')
raw['RunDirectory']=raw.RunDirectory.map(lambda p:str(ROOT/'results/cec'/Path(p).name))
raw['ArtifactPath']=[str(Path(p)/'runs'/f'job_{j:04d}.mat') for p,j in zip(raw.RunDirectory,raw.JobID)]
assert raw.ArtifactPath.map(lambda p:Path(p).is_file()).all()
raw=raw.rename(columns={'Condition':'Method'});raw.to_csv(run/'cache/cached_runs.csv',index=False)
pd.DataFrame(source_checks).to_csv(run/'cache/source_checks.csv',index=False)
# The original baseline raw data and a provenance record are frozen rather than silently rerun.
write(run/'cache/cache_preparation.json',{'Passed':True,'Runs':5220,'SourcesMatch':True,'CecDataManifestMatch':True,'CachedMethods':refs,'NativeSPSOVerified':True})
jobs=[]
for fid in [1]+list(range(3,31)):
 for seed in range(3001,3031):
  init=261013000+fid*10000+seed
  for method in ['ASC-NoFarness','ASC-PositionRank']:
   jobs.append(dict(JobID=len(jobs)+1,FunctionID=fid,Seed=seed,Method=method,InitSeed=init,SearchSeed=init+1000000))
pd.DataFrame(jobs).to_csv(run/'jobs.csv',index=False)
write(run/'config.json',{'Date':'2026-10-15','Dimension':50,'Population':50,'Budget':100000,'Functions':[1]+list(range(3,31)),
 'Seeds':list(range(3001,3031)),'Workers':4,'FreshMethods':['ASC-NoFarness','ASC-PositionRank'],'ReferenceMethods':refs,
 'FreshRuns':1740,'CachedRuns':5220,'OptimizationCallsFresh':174000000,'Excluded':['Original-CSO-MR02','HIDMS-PSO-IndexCorrected'],
 'NoParameterSweep':True,'UnseenFunctions':False})
hashes=[dict(Path=str(f),SHA256=digest(f),Bytes=f.stat().st_size) for sub in ['source','cec_data','cache'] for f in sorted((run/sub).rglob('*')) if f.is_file()]
pd.DataFrame(hashes).to_csv(run/'prelaunch_hashes.csv',index=False)
write(run/'status.json',{'Status':'prepared','Completed':0,'Total':1740,'Directory':str(run)})
(ROOT/'work/asc_rank_comparison_latest.txt').write_text(str(run),encoding='utf8')
launcher="addpath('"+str(run/'source').replace('\\','/')+"','-begin');\nrun_asc_rank_comparison('"+str(run).replace('\\','/')+"');\n"
(ROOT/'work/launch_asc_rank_comparison.m').write_text(launcher,encoding='utf8')
print(run)
