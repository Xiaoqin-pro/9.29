"""Check currently completed records without predicting remaining comparisons."""
from pathlib import Path
import argparse,json
import numpy as np,pandas as pd
from scipy.io import loadmat
p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;raw=pd.read_csv(run/'raw_runs.csv');groups={}
for r in raw.itertuples():
 assert r.Status=='ok' and r.ObjectiveCalls==r.Budget==r.Evaluations==100000 and r.OutsideCalls==0 and r.PostRunRecheckCalls==1
 d=loadmat(run/'runs'/f'job_{r.JobID:04d}.mat',simplify_cells=True);T=np.asarray(d['T']).reshape(-1);p0=np.asarray(d['p0']);I=d['I'];B=d['B']
 assert len(T)==100000 and np.isfinite(T).all() and (np.diff(T)<=0).all() and T[-1]==B['Cost'] and abs(B['Cost']-r.FinalCost)<=1e-8*max(1,abs(r.FinalCost))
 assert p0.shape==(r.Population,50) and ((p0>=-100)&(p0<=100)).all() and ((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100)).all()
 key=(r.FunctionID,r.Seed);previous=groups.get(key)
 if previous is not None:assert np.array_equal(previous[:min(len(previous),len(p0))],p0[:min(len(previous),len(p0))])
 if previous is None or len(previous)<len(p0):groups[key]=p0
 if r.Condition=='CSO-Fixed6':assert I['ModeTraceQuota']==6 and I['TracingEvaluations']+I['SeekingEvaluations']==99950 and I['MaxParentEvaluations']<=2
result=dict(RunsChecked=len(raw),ActualInitialPrefixGroups=len(groups),Passed=True,Scope='Completed records only; not final ranking')
(run/'partial_artifact_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
