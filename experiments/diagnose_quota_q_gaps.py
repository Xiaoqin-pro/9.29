"""Locate matched Q deficits and distinguish healthy versus real FE stagnation."""
from pathlib import Path
import numpy as np,pandas as pd,json
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];qdir=root/'results/cec/quota_q_full_100k_study_20261012_194957';bdir=root/'results/cec/clpso_full_100k_study_20261012_193032';q=pd.read_csv(qdir/'raw_runs.csv');b=pd.read_csv(bdir/'raw_runs.csv');b=b[b.Condition=='CSO-Fixed6'];out=root/'results/quota_q_gap_20261012';out.mkdir(exist_ok=True)
rows=[];stage=[];outcome=[]
for row in q.itertuples():
    d=loadmat(qdir/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['DecisionLog']);S=np.asarray(d['I']['StateLog']);T=np.asarray(d['T']).reshape(-1)
    peer=b[(b.FunctionID==row.FunctionID)&(b.Seed==row.Seed)].iloc[0];BD=loadmat(bdir/'runs'/f'job_{int(peer.JobID):04d}.mat',simplify_cells=True);BT=np.asarray(BD['T']).reshape(-1)
    assert np.array_equal(d['p0'],BD['p0'])
    for phase in range(3):
        mask=L[:,5]==phase;R=L[mask];start=int(R[0,0]);end=int(R[-1,1]);qa=T[end-1]-100*row.FunctionID;ba=BT[end-1]-100*row.FunctionID
        stage.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Phase=phase,EndFE=end,QError=qa,Fixed6Error=ba,QtoFixed6Ratio=(max(qa,0)+1e-12)/(max(ba,0)+1e-12),QFractionRemoved=float((T[start-1]-T[end-1])/max(T[start-1]-100*row.FunctionID,1e-12)),Fixed6FractionRemoved=float((BT[start-1]-BT[end-1])/max(BT[start-1]-100*row.FunctionID,1e-12))))
        for flag in [0,1]:
            ix=mask&(S[:,1]==flag);P=L[ix]
            if not len(P):continue
            gain=P[:,7]-P[:,8]
            for ac in [1,2,3]:
                A=P[P[:,3]==ac];g=A[:,7]-A[:,8]
                rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Phase=phase,Stalled=flag,Action=ac,StateBlocks=len(P),ActionBlocks=len(A),ActionShare=float(len(A)/len(P)),PositiveRate=float((g>0).mean()) if len(A) else np.nan,RelativeGainPerBlock=float(np.mean(g/np.maximum(A[:,7]-100*row.FunctionID,1e-12))) if len(A) else np.nan,PhaseGainShare=float(g.sum()/max(gain.sum(),1e-12))))
    healthy=S[:,1]==0;stalled=~healthy
    outcome.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,FinalQError=row.FinalError,Fixed6Error=float(peer.FinalError),HealthyBlockRate=float(healthy.mean()),HealthyFixed6Rate=float((L[healthy,3]==3).mean()),StalledFixed6Rate=float((L[stalled,3]==3).mean()) if stalled.any() else np.nan,HealthyPositiveRate=float((L[healthy,9]>0).mean()),StalledPositiveRate=float((L[stalled,9]>0).mean()) if stalled.any() else np.nan))
r=pd.DataFrame(rows);r.to_csv(out/'q_actual_state_action_outcomes.csv',index=False);s=pd.DataFrame(stage);s.to_csv(out/'matched_phase_errors.csv',index=False);o=pd.DataFrame(outcome);o.to_csv(out/'matched_run_diagnostics.csv',index=False)
summary=r.groupby(['Phase','Stalled','Action'])[['ActionShare','PositiveRate','RelativeGainPerBlock']].mean();summary.to_csv(out/'state_action_summary.csv');functions=o.groupby('FunctionID').agg(QMean=('FinalQError','mean'),Fixed6Mean=('Fixed6Error','mean'),HealthyBlockRate=('HealthyBlockRate','mean'),HealthyFixed6Rate=('HealthyFixed6Rate','mean'),StalledFixed6Rate=('StalledFixed6Rate','mean'));functions['MeanErrorRatio']=(functions.QMean.clip(lower=0)+1e-12)/(functions.Fixed6Mean.clip(lower=0)+1e-12);functions.to_csv(out/'function_gap_summary.csv')
print('All-run state summary:');print(o[['HealthyBlockRate','HealthyFixed6Rate','StalledFixed6Rate','HealthyPositiveRate','StalledPositiveRate']].mean().to_string());print('Phase/stall/action conditional outcomes (observational):');print(summary.to_string());print('Largest relative losses:');print(functions.sort_values('MeanErrorRatio',ascending=False).head(10).to_string())
(out/'scope.json').write_text(json.dumps(dict(Runs=145,SourceQ=str(qdir),SourceFixed6=str(bdir),NoNewOptimizationRuns=True,Scope='descriptive past-action outcomes; confounded with search state and earlier choices; no counterfactual causality'),indent=2),encoding='utf-8')
