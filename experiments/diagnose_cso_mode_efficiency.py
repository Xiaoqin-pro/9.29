"""Lagged actual-mode feedback on previously run random quota controls."""
from pathlib import Path
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];out=root/'results/cso_mode_efficiency_20261012';out.mkdir(exist_ok=True)
sources=['cso_mode_q_study_20261012_141736','cso_mode_q_state_confirmation_study_20261012_150741'];records=[]
for source in sources:
 run=root/'results/cec'/source;raw=pd.read_csv(run/'raw_runs.csv')
 for row in raw[raw.Condition=='random'].itertuples():
  d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);R=np.asarray(d['I']['RoundLog']);L=np.asarray(d['I']['DecisionLog'])
  cs=np.vstack([np.zeros(6),np.cumsum(R[:,[2,3,7,8,11,12]],axis=0)])
  for k,l in enumerate(L):
   end=k*10;start=max(0,end-100);v=cs[end]-cs[start]
   if end==0:continue
   local_t=v[2]/max(1,v[0]);local_s=v[3]/max(1,v[1]);gain_t=v[4]/max(1,v[0]);gain_s=v[5]/max(1,v[1]);gain=max(0,l[7]-l[8]);err=max(l[7]-100*row.FunctionID,1e-12)
   records.append(dict(Cohort=source,FunctionID=row.FunctionID,Seed=row.Seed,Phase=int(l[5]),Action=int(l[3]),LocalSignal=int(np.sign(local_t-local_s)),GainSignal=int(np.sign(gain_t-gain_s)),TraceLocal=local_t,SeekLocal=local_s,Positive=int(gain>0),RelativeGain=gain/err))
r=pd.DataFrame(records);r.to_csv(out/'lagged_random_blocks.csv',index=False)
for signal in ['LocalSignal','GainSignal']:
 # First within each run/function/phase: prevent long runs or function scale dominating.
 within=r.groupby(['Cohort','FunctionID','Seed','Phase',signal,'Action']).agg(Blocks=('Positive','size'),PositiveRate=('Positive','mean'),MeanRelativeGain=('RelativeGain','mean')).reset_index()
 within.to_csv(out/(signal+'_within_run.csv'),index=False)
 table=within.groupby(['Phase',signal,'Action']).agg(RunCells=('Blocks','size'),MeanBlocks=('Blocks','mean'),PositiveRate=('PositiveRate','mean'),RelativeGain=('MeanRelativeGain','mean')).reset_index();table.to_csv(out/(signal+'_summary.csv'),index=False)
 print(signal,'fractions',r[signal].value_counts(normalize=True).to_dict());print(table.to_string(index=False))
