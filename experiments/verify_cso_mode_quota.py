"""Independently check saved MATLAB artifacts against the public CSV."""
from pathlib import Path
import argparse, json
import numpy as np
import pandas as pd
from scipy.io import loadmat

p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--complete',action='store_true');args=p.parse_args()
run_dir=args.run_dir.resolve();raw=pd.read_csv(run_dir/'raw_runs.csv')
if args.complete:assert (run_dir/'COMPLETED.json').exists() and len(raw)==120
same_initial={};checked=0
for row in raw.itertuples():
    data=loadmat(run_dir/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True)
    T=np.asarray(data['T']).reshape(-1);I=data['I'];B=data['B'];R=np.asarray(I['RoundLog']).reshape(-1,13)
    assert len(T)==row.Budget and np.isfinite(T).all() and (np.diff(T)<=0).all()
    assert abs(float(B['Cost'])-row.FinalCost)<=1e-8*max(1,abs(row.FinalCost))
    assert T[-1]==float(B['Cost']) and len(R)==row.Rounds
    assert np.allclose(R[:,1]-R[:,0],R[:,2]+R[:,3],rtol=0,atol=0)
    assert R[:,2].sum()==row.TracingEvaluations and R[:,3].sum()==row.SeekingEvaluations
    for col, raw_count in [(9,row.TraceGlobalSuccesses),(10,row.SeekGlobalSuccesses)]:assert R[:,col].sum()==raw_count
    # Count improvements from T independently and compare every round with counters.
    delta=np.diff(T[49:]);start=(R[:,0]-50).astype(int);stop=(R[:,1]-50).astype(int)
    cumulative=np.r_[0,np.cumsum(delta<0)]
    assert np.array_equal(cumulative[stop]-cumulative[start],R[:,9]+R[:,10])
    gain=float(R[:,11:].sum());total=float(T[49]-T[-1]);assert abs(gain-total)<=1e-10*max(1,abs(total))
    for frac,col in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:
        v=T[int(round(frac*row.Budget))-1]-100*row.FunctionID
        assert abs(v-getattr(row,col))<=1e-8*max(1,abs(v))
    key=(row.FunctionID,row.Seed,row.Budget);p0=np.asarray(data['p0'])
    assert p0.shape==(50,50) and np.isfinite(p0).all() and ((p0>=-100)&(p0<=100)).all()
    if key in same_initial:assert np.array_equal(same_initial[key],p0)
    else:same_initial[key]=p0
    assert np.asarray(B['Vector']).shape==(50,) and np.isfinite(B['Vector']).all()
    assert ((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100)).all()
    checked+=1
result=dict(RunsChecked=checked,AllCompleted=args.complete,SharedInitialGroups=len(same_initial),Passed=True,Checks='CSV/MAT/FE/monotone-T/mode counters/every-round global successes/gain telescoping/initial populations/bounds')
(run_dir/'independent_artifact_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
