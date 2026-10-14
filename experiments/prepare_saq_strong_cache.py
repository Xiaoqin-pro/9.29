"""Validate the fixed 10-seed subset of the audited full comparison."""
from pathlib import Path
import json, hashlib
import pandas as pd
import numpy as np
from scipy.io import loadmat
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/saq_strong_confirmation_cache_20261014';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'results/saq_cso_eightway_30seed_20261013'
METHODS=['SAQ-CSO','HCLPSO-AuthorSource','HIDMS-PSO-IndexCorrected','DMS-PSO-SIS2005','HPSO-TVAC-CEC','SPSO-2011-OfficialC']
raw=pd.read_csv(SOURCE/'all_quality_runs.csv');raw=raw[raw.Condition.isin(METHODS)&raw.Seed.between(3001,3010)].copy()
assert len(raw)==1740 and set(raw.FunctionID)=={1,*range(3,31)}
assert raw.groupby(['FunctionID','Condition']).size().eq(10).all()
assert raw.Status.eq('ok').all() and raw.Budget.eq(100000).all() and raw.ObjectiveCalls.eq(100000).all()
assert raw.Evaluations.eq(100000).all() and raw.Dimension.eq(50).all() and raw.OutsideCalls.eq(0).all()
assert raw.groupby(['FunctionID','Seed']).InitSeed.nunique().eq(1).all()
assert raw.groupby(['FunctionID','Seed']).SearchSeed.nunique().eq(1).all()
prior=json.loads((SOURCE/'independent_artifact_checks.json').read_text(encoding='utf-8'))
prior_mat=json.loads((SOURCE/'independent_matlab_recheck.json').read_text(encoding='utf-8'))
assert prior['Passed'] and prior_mat['Passed']
source_manifest=json.loads((SOURCE/'source_manifest.json').read_text(encoding='utf-8'))
required=['src/SAQ_CSO.m','src/ASE_CSO_QuotaQ_Candidate.m','src/ASE_CSO_QuotaQ_Compact.m',
 'src/HCLPSO_CEC_AuthorSource.m','src/HIDMS_PSO_CEC.m','src/DMS_PSO_SIS_CEC.m','src/HPSO_TVAC_CEC.m',
 'src/SPSO2011_CEC.m','archive/legacy/CEC2017Function.m']
checked=[]
for rel in required:
    candidates=[x for x in source_manifest if x['Path'].replace(chr(92),'/')==rel]
    blob=(ROOT/rel).read_bytes();current=hashlib.sha256(blob).hexdigest()
    normalized=hashlib.sha256(blob.replace(b'\r\n',b'\n')).hexdigest()
    assert candidates,f'Missing cached source: {rel}'
    for x in candidates:
        snapshot=Path(x['RunDirectory'])/'source_snapshot'/rel
        old_blob=snapshot.read_bytes()
        assert hashlib.sha256(old_blob).hexdigest()==x['SHA256'],f'Historical snapshot changed: {rel}'
        assert hashlib.sha256(old_blob.replace(b'\r\n',b'\n')).hexdigest()==normalized,f'Source changed: {rel}'
    checked.append({'Path':rel,'SHA256':current,'SHA256NormalizedLF':normalized,'MatchesCurrent':True})
# Matrices/shuffles have an independent supplied-data manifest.
manifest=pd.read_csv(ROOT/'data/cec2017/D50_manifest.csv')
for r in manifest.itertuples():
    path=ROOT/'data/cec2017/input_data'/r.File
    assert hashlib.sha256(path.read_bytes()).hexdigest()==r.SHA256
curves=[];cache_rows=[];initial={};data_checks=0
nodes=np.unique(np.r_[50,np.linspace(1000,100000,101).round().astype(int),20000,60000,80000])
for index,r in enumerate(raw.itertuples(),1):
    artifact=Path(r.RunDirectory)/'runs'/f'job_{r.JobID:04d}.mat'
    assert artifact.exists()
    saved=loadmat(artifact,simplify_cells=True)
    T=np.asarray(saved['T'],dtype=float).reshape(-1);B=saved['B'];I=saved['I'];p0=np.asarray(saved['p0'],dtype=float)
    rec=saved['rec'];job=saved['job']
    for key in ['FunctionID','Seed','Budget','Population','InitSeed','SearchSeed','Condition']:
        assert job[key]==getattr(r,key)
    assert len(T)==100000 and np.isfinite(T).all() and np.all(np.diff(T)<=0)
    assert I['Evaluations']==100000 and rec['ObjectiveCalls']==100000 and rec['OutsideCalls']==0
    assert T[-1]==B['Cost'] and abs(B['Cost']-r.FinalCost)<=1e-10*max(1,abs(r.FinalCost))
    assert abs(T[19999]-100*r.FunctionID-r.Error20FE)<=1e-10*max(1,abs(r.Error20FE))
    assert abs(T[59999]-100*r.FunctionID-r.Error60FE)<=1e-10*max(1,abs(r.Error60FE))
    assert abs(T[79999]-100*r.FunctionID-r.Error80FE)<=1e-10*max(1,abs(r.Error80FE))
    assert p0.shape==(r.Population,50) and np.all(p0>=-100) and np.all(p0<=100)
    vector=np.asarray(B['Vector'],dtype=float).reshape(-1)
    assert len(vector)==50 and np.all(vector>=-100) and np.all(vector<=100)
    if r.Condition=='SAQ-CSO':initial[(r.FunctionID,r.Seed)]=p0.copy()
    cache_rows.append({'FunctionID':r.FunctionID,'Seed':r.Seed,'Method':r.Condition,'Population':r.Population,
      'InitSeed':r.InitSeed,'SearchSeed':r.SearchSeed,'Budget':100000,'Dimension':50,
      'FinalCost':float(B['Cost']),'FinalError':r.FinalError,'Error20FE':r.Error20FE,'Error60FE':r.Error60FE,
      'Error80FE':r.Error80FE,'Seconds':r.Seconds,'ObjectiveCalls':r.ObjectiveCalls,'Evaluations':r.Evaluations,
      'OutsideCalls':r.OutsideCalls,'PostRunRecheckCalls':r.PostRunRecheckCalls,'Status':'ok','ArtifactPath':str(artifact),
      'ArtifactSHA256':hashlib.sha256(artifact.read_bytes()).hexdigest(),'FromCache':True})
    for fe in nodes:curves.append({'FunctionID':r.FunctionID,'Seed':r.Seed,'Method':r.Condition,'FE':int(fe),'BestError':float(T[fe-1]-100*r.FunctionID)})
    data_checks+=1
    if index%300==0:print(f'Checked {index}/1740 cache artifacts',flush=True)
# Every smaller swarm uses the same fixed 50-particle initial pool prefix.
for r in raw.itertuples():
    saved=loadmat(Path(r.RunDirectory)/'runs'/f'job_{r.JobID:04d}.mat',variable_names=['p0'],simplify_cells=True)
    assert np.array_equal(saved['p0'],initial[(r.FunctionID,r.Seed)][:r.Population])
cache=pd.DataFrame(cache_rows);cache.to_csv(OUT/'cached_runs.csv',index=False)
pd.DataFrame(curves).to_csv(OUT/'cached_convergence_nodes.csv',index=False)
paired=cache[cache.Method.eq('SAQ-CSO')][['FunctionID','Seed','InitSeed','SearchSeed']].copy()
paired.sort_values(['FunctionID','Seed']).to_csv(OUT/'paired_seeds.csv',index=False)
pd.DataFrame(checked).to_csv(OUT/'cached_source_hashes.csv',index=False)
report={'Date':'2026-10-14','Passed':True,'CachedRuns':1740,'Functions':29,'Seeds':list(range(3001,3011)),
 'Methods':METHODS,'ActualOptimizationCallsInCachedRuns':174000000,'NewOptimizationCallsForPreparation':0,
 'ArtifactChecks':data_checks,'CommonInitialPools':290,'D50DataFilesChecked':len(manifest),
 'MatlabRegenerationAndObjectiveRechecksRequiredBeforeReuse':True,'SourceArchive':str(SOURCE),
 'SourceRawSHA256':hashlib.sha256((SOURCE/'all_quality_runs.csv').read_bytes()).hexdigest()}
(OUT/'cache_python_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Prepared validated cache:',OUT)
