"""Describe delayed gains after gated stalled trials; do not assign future credit retroactively."""
from pathlib import Path
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];run=root/'results/cec/quota_q_stall_gate_study_20261012_202002';raw=pd.read_csv(run/'raw_runs.csv');rows=[]
for row in raw[raw.Condition=='gateq'].itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['DecisionLog']);G=np.asarray(d['I']['GateLog']);T=np.asarray(d['T']).reshape(-1)
 for k in range(len(L)-4):
  if G[k,1]!=1:continue
  following=L[k:k+5];start=int(L[k,0]);end=int(L[k+4,1]);gain100=L[k,7]-L[k,8];gain500=T[start-1]-T[end-1]
  rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Decision=k+1,Action=int(L[k,3]),Positive100=int(gain100>0),PositiveFollowing500=int(gain500>0),SameActionAll500=int(np.all(following[:,3]==L[k,3])),AnyActionSwitch=int(np.any(np.diff(following[:,3])!=0)),Failed100ThenGain500=int(gain100<=0 and gain500>0)))
out=root/'results/quota_q_episode_20261012';out.mkdir(exist_ok=True);r=pd.DataFrame(rows);r.to_csv(out/'original_gate_delayed_gain_diagnosis.csv',index=False);r.groupby(['FunctionID','Seed'])[['Positive100','PositiveFollowing500','SameActionAll500','AnyActionSwitch','Failed100ThenGain500']].mean().to_csv(out/'original_gate_delayed_gain_summary.csv')
print(r[['Positive100','PositiveFollowing500','SameActionAll500','AnyActionSwitch','Failed100ThenGain500']].mean().to_string());print('Trials',len(r));print('Observational only: following500 includes other actions; not attributable return for original choice.')
