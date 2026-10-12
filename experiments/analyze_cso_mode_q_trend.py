"""Verify neutral diversity replays and summarize actual population/stagnation trends."""
from pathlib import Path
import argparse,json,shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/cso_mode_q_trend_20261012';out.mkdir(exist_ok=True)
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');oldrun=root/'results/cec/cso_mode_q_study_20261012_141736';old=pd.read_csv(oldrun/'raw_runs.csv');assert len(raw)==32 and raw.Status.eq('ok').all()
records=[]
for row in raw.itertuples():
    oldrow=old[(old.FunctionID==row.FunctionID)&(old.Seed==row.Seed)&(old.Condition==row.Condition)].iloc[0]
    x=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);y=loadmat(oldrun/'runs'/f'job_{int(oldrow.JobID):04d}.mat',simplify_cells=True)
    assert np.array_equal(x['T'],y['T']) and np.array_equal(x['B']['Vector'],y['B']['Vector']) and x['B']['Cost']==y['B']['Cost']
    assert np.array_equal(x['I']['DecisionLog'],y['I']['DecisionLog']) and np.array_equal(x['I']['QTable'],y['I']['QTable'])
    T=np.asarray(x['T']).reshape(-1);L=np.asarray(x['I']['TrendLog']).reshape(-1,7);D=np.asarray(x['I']['DecisionLog']).reshape(-1,14)
    assert len(L)==1001 and np.array_equal(L[:,5],T[L[:,0].astype(int)-1]) and np.isfinite(L).all()
    imp=np.flatnonzero(np.diff(T)<0)+2;imp=imp[imp>50];last=np.maximum.accumulate(np.where(np.isin(np.arange(1,len(T)+1),imp),np.arange(1,len(T)+1),50))
    assert np.array_equal(L[:,4],L[:,0]-last[L[:,0].astype(int)-1])
    for k,l in enumerate(L):
        records.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(l[0]),Phase=min(2,int(3*(l[0]-50)/(row.Budget-50))),RealDiversity=l[1],VirtualDiversity=l[2],RealDiversityRatio=l[1]/l[6],FitnessSpread=l[3],StagnationFE=int(l[4]),Error=l[5]-100*row.FunctionID,Action=0 if k==len(D) else int(D[k,3])))
r=pd.DataFrame(records);r.to_csv(out/'diversity_trace.csv',index=False)
r.groupby(['FunctionID','Condition','Phase']).agg(MeanRealDiversityRatio=('RealDiversityRatio','mean'),MedianRealDiversityRatio=('RealDiversityRatio','median'),MedianStagnationFE=('StagnationFE','median'),Stagnation500Rate=('StagnationFE',lambda v:float((v>=500).mean())),Stagnation1000Rate=('StagnationFE',lambda v:float((v>=1000).mean())),MeanError=('Error','mean')).to_csv(out/'diversity_phase_summary.csv')
shutil.copy2(run/'raw_runs.csv',out/'replay_raw_runs.csv');shutil.copy2(root/'work/cso_mode_q_trend_20261012/logging_checks.json',out/'logging_checks.json')
(out/'neutral_replay_checks.json').write_text(json.dumps(dict(Replays=32,ExactOriginalTrajectories=32,ExactQTables=32,Passed=True,Scope='same-seed diagnostic reruns, not independent effect evidence'),indent=2),encoding='utf-8')
print(r.groupby(['FunctionID','Condition','Phase']).agg(Diversity=('RealDiversityRatio','mean'),StagnationMedian=('StagnationFE','median')).to_string())
