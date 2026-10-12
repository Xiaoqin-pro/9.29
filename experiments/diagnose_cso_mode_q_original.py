"""Diagnose the already completed 280-run Q study without changing results."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];run=root/'results/cec/cso_mode_q_study_20261012_141736';raw=pd.read_csv(run/'raw_runs.csv');out=root/'results/cso_mode_q_trend_20261012';out.mkdir(exist_ok=True)
phase_rows=[];state_actions=[];final_q=[]
for row in raw.itertuples():
    data=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(data['I']['DecisionLog']).reshape(-1,14)
    for phase in range(3):
        P=L[L[:,5]==phase];gain=P[:,7]-P[:,8]
        phase_rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,Phase=phase,Blocks=len(P),PositiveRate=float((gain>0).mean()),ErrorBefore=float(P[0,7]-100*row.FunctionID),ErrorAfter=float(P[-1,8]-100*row.FunctionID),FractionErrorRemoved=float(gain.sum()/max(P[0,7]-100*row.FunctionID,1e-12)),Action1Share=float((P[:,3]==1).mean()),Action2Share=float((P[:,3]==2).mean()),Action3Share=float((P[:,3]==3).mean())))
        if row.Condition=='q':
            for st in sorted(set(P[:,2].astype(int))):
                for ac in range(1,4):
                    A=P[(P[:,2]==st)&(P[:,3]==ac)];g=A[:,7]-A[:,8];positive=g[g>0]
                    if not len(A):continue
                    state_actions.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Phase=phase,State=st,Action=ac,Blocks=len(A),PositiveRate=float((g>0).mean()),GainShareWithinPhase=float(g.sum()/max(gain.sum(),1e-300)),GainPerBlock=float(g.mean()),PositiveGainMedian=float(np.median(positive)) if len(positive) else 0,PositiveGainMean=float(positive.mean()) if len(positive) else 0))
    if row.Condition=='q':
        Q=np.asarray(data['I']['QTable']);V=np.asarray(data['I']['QVisits'])
        for st in range(6):
            for ac in range(3):final_q.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,State=st+1,Action=ac+1,QValue=float(Q[st,ac]),Visits=int(V[st,ac])))
p=pd.DataFrame(phase_rows);p.to_csv(out/'original_phase_runs.csv',index=False)
p.groupby(['Condition','Phase'])[['PositiveRate','FractionErrorRemoved','Action1Share','Action2Share','Action3Share']].mean().to_csv(out/'original_phase_summary.csv')
a=pd.DataFrame(state_actions);a.to_csv(out/'original_q_state_action_runs.csv',index=False)
a.groupby(['Phase','State','Action'])[['Blocks','PositiveRate','GainShareWithinPhase']].mean().to_csv(out/'original_q_state_action_summary.csv')
f=pd.DataFrame(final_q);f.to_csv(out/'original_q_final_tables.csv',index=False);f.groupby(['State','Action'])[['QValue','Visits']].mean().to_csv(out/'original_q_final_table_summary.csv')
print(p.groupby(['Condition','Phase']).PositiveRate.mean().unstack().to_string())
print(p[p.Condition=='q'].groupby('Phase')[['Action1Share','Action2Share','Action3Share']].mean().to_string())
print(f.groupby(['State','Action']).QValue.mean().unstack().to_string())
