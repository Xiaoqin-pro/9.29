"""Replay actual evaluation order to diagnose search modes and delayed credit."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
from scipy.io import loadmat
p=argparse.ArgumentParser();p.add_argument('run_directory',type=Path);a=p.parse_args();run=a.run_directory
raw=pd.read_csv(run/'raw_runs.csv');assert raw.Status.eq('ok').all()
mode_rows=[];credit_rows=[]
for r in raw.itertuples():
    saved=loadmat(run/'runs'/r.Artifact,simplify_cells=True);I=saved['info'];T=np.asarray(saved['T'],dtype=float).reshape(-1)
    R=np.asarray(I['RoundLog'],dtype=float).reshape(-1,5);W=np.asarray(I['WindowLog'],dtype=float).reshape(-1,23)
    types=np.zeros(len(T),dtype=np.int8)
    assert np.array_equal(R[:,0],np.r_[50,R[:-1,1]]) and R[-1,1]==len(T)
    for row in R:
        start,end,trace,seek,probe=map(int,row)
        assert end-start==trace+seek
        types[start:start+trace]=1;types[start+trace:end-probe]=2
        if probe:types[end-1]=3
    assert np.all(types[50:]>0) and np.sum(types==1)==I['TracingEvaluations']
    assert np.sum(types==2)+np.sum(types==3)==I['SeekingEvaluations'] and np.sum(types==3)==I['ProbeEvaluations']
    gain=np.r_[0,T[:-1]-T[1:]];assert np.all(gain>=0)
    fes=np.arange(1,len(T)+1);phase=np.minimum(2,np.floor(3*np.maximum(0,fes-50)/(len(T)-50))).astype(int)+1
    for ph in [1,2,3]:
        for code,name in [(1,'Tracing'),(2,'Seeking'),(3,'EliteProbe')]:
            mask=(phase==ph)&(types==code);count=int(mask.sum())
            mode_rows.append({'FunctionID':r.FunctionID,'Seed':r.Seed,'Method':r.Method,'Phase':ph,'SearchMode':name,
              'Evaluations':count,'StrictGlobalImprovements':int((gain[mask]>0).sum()),'DirectGlobalGain':float(gain[mask].sum()),
              'GlobalSuccessPerEvaluation':float((gain[mask]>0).mean()) if count else np.nan})
    for ph in [1,2,3]:
        for action,name in [(1,'Normal'),(2,'Probe')]:
            eligible=W[(W[:,3]==ph)&(W[:,7]>0)&(W[:,9]==action)]
            now=0;future500=0;future1000=0;negative_to_success500=0;negative_to_success1000=0;observed500=0;observed1000=0
            for w in eligible:
                start=int(w[0]);scale=w[5];best_before=w[12];threshold=1e-4*scale
                current_success=w[15]>0;now+=int(current_success)
                if start+500<=len(T):
                    success=best_before-T[start+500-1]>=threshold
                    future500+=int(success);negative_to_success500+=int(not current_success and success);observed500+=1
                if start+1000<=len(T):
                    success=best_before-T[start+1000-1]>=threshold
                    future1000+=int(success);negative_to_success1000+=int(not current_success and success);observed1000+=1
            credit_rows.append({'FunctionID':r.FunctionID,'Seed':r.Seed,'Method':r.Method,'Phase':ph,'Action':name,
              'EligibleWindows':len(eligible),'EffectiveSuccessCurrentWindow':now,'FullyObserved500Windows':observed500,
              'EffectiveSuccessBy500':future500,'CurrentNegativeButSuccessBy500':negative_to_success500,
              'FullyObserved1000Windows':observed1000,'EffectiveSuccessBy1000':future1000,
              'CurrentNegativeButSuccessBy1000':negative_to_success1000})
pd.DataFrame(mode_rows).to_csv(run/'mode_gain_diagnostics.csv',index=False)
pd.DataFrame(credit_rows).to_csv(run/'delayed_credit_diagnostics.csv',index=False)
print(f'Replayed modes and delayed credit for {len(raw)} runs. Delayed gains include subsequent search, not isolated probe effects.')
