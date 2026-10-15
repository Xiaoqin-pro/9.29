"""Recompute the Jump comparison from public CSV files; no private MAT required."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'results/asc_jump_study_10seed_20261015'
raw=pd.read_csv(out/'all_runs.csv');cfg=json.loads((out/'config.json').read_text(encoding='utf8'));g=json.loads((out/'gate_decision.json').read_text(encoding='utf8'))
assert len(raw)==240 and raw.Status.eq('ok').all() and raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all()
assert raw.OutsideCalls.eq(0).all() and raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.Seed)==set(range(5001,5011)) and set(raw.Method)=={'Original','NoJump','LightJump'}
assert not raw.duplicated(['FunctionID','Seed','Method']).any() and raw.groupby(['FunctionID','Seed']).Method.nunique().eq(3).all()
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=['Original','NoJump','LightJump'])
assert np.allclose(means,pd.read_csv(out/'function_means.csv',index_col=0),rtol=1e-12,atol=1e-8)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=means.columns)
assert np.allclose(std,pd.read_csv(out/'function_std.csv',index_col=0),rtol=1e-12,atol=1e-8)
c=pd.read_csv(out/'comparisons.csv');detail=pd.read_csv(out/'function_comparisons.csv');assert len(detail)==24
for row in c.itertuples():
    b=raw[raw.Method.eq(row.Reference)].set_index(['FunctionID','Seed']).FinalError
    a=raw[raw.Method.eq(row.Method)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index);ds=a-b;ratio=means[row.Method]/means[row.Reference]
    assert row.MeanWins==(ratio<1).sum() and row.MeanLosses==(ratio>1).sum() and row.MeanTies==(ratio==1).sum()
    assert row.SeedWins==(ds<0).sum() and row.SeedLosses==(ds>0).sum() and row.SeedTies==(ds==0).sum()
    assert np.isclose(row.MedianMeanRatio,ratio.median(),rtol=1e-12)
for row in detail.itertuples():
    z=raw[raw.FunctionID.eq(row.FunctionID)].pivot(index='Seed',columns='Method',values='FinalError');ds=(z[row.Method]-z[row.Reference]).to_numpy()
    pv=1. if np.all(ds==0) else float(wilcoxon(ds,zero_method='wilcox',method='auto').pvalue)
    assert np.isclose(pv,row.WilcoxonP,rtol=1e-12)
pv=detail.WilcoxonP.to_numpy();adj=np.empty(len(pv));running=0
for k,i in enumerate(np.argsort(pv)):running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
assert np.allclose(adj,detail.Holm24,rtol=1e-12)
for method in ['NoJump','LightJump']:
    ratio=means[method]/means.Original
    passed=bool((ratio<1).sum()>=5 and ratio.median()<=.95 and (ratio<=1.2).all() and (ratio.loc[[6,9]]<=1.1).all())
    assert g['Candidates'][method]['Passed']==passed
passed=[m for m in ['NoJump','LightJump'] if g['Candidates'][m]['Passed']]
selected=min(passed,key=lambda m:(g['Candidates'][m]['MedianMeanRatio'],0 if m=='NoJump' else 1)) if passed else None
assert g['SelectedForIndependentConfirmation']==selected and g['Passed']==bool(passed)
assert g['FreshOptimizationCalls']==raw.ObjectiveCalls.sum() and g['FreshBestRecheckCalls']==raw.PostRunRecheckCalls.sum()
checks=pd.read_csv(out/'integrity_checks.csv');assert len(checks)==240 and checks.Passed.all()
curves=pd.read_csv(out/'convergence_nodes.csv');assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
last=curves[curves.FE.eq(100000)].set_index(['FunctionID','Seed','Method']).BestError
assert len(last)==240 and np.allclose(last,raw.set_index(['FunctionID','Seed','Method']).FinalError.reindex(last.index),rtol=1e-12,atol=1e-8)
diag=pd.read_csv(out/'run_diagnostics.csv');assert len(diag)==240 and diag[diag.Method.eq('NoJump')].Jumps.eq(0).all()
result=dict(Passed=True,Rows=240,FunctionMeansChecked=24,PairedTestsRecomputed=24,HolmFamily=24,GateRecomputed=True,UsesPrivateMAT=False)
(out/'public_verification.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result,indent=2))
