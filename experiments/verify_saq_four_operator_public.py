"""Recompute public CSV summaries without private MAT artifacts or MATLAB."""
from pathlib import Path
import json,hashlib
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'results/saq_four_operator_10seed_20261014'
raw=pd.read_csv(out/'all_runs.csv');assert len(raw)==320 and raw.Status.eq('ok').all()
assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.OutsideCalls.eq(0).all()
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(4).all()
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
methods=['FO-Base','FO-Rule','FO-Random','FO-Q']
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
published=pd.read_csv(out/'function_means.csv',index_col=0)
assert np.allclose(means,published,rtol=1e-12,atol=1e-10)
comparisons=pd.read_csv(out/'comparisons.csv').set_index('Reference')
for ref in methods[:-1]:
    b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError
    q=raw[raw.Method.eq('FO-Q')].set_index(['FunctionID','Seed']).FinalError.reindex(b.index)
    ratio=means['FO-Q']/means[ref];d=q-b;c=comparisons.loc[ref]
    for key,value in [('MeanWins',(ratio<1).sum()),('MeanLosses',(ratio>1).sum()),('MeanTies',(ratio==1).sum()),
                      ('SeedWins',(d<0).sum()),('SeedLosses',(d>0).sum()),('SeedTies',(d==0).sum())]:assert int(c[key])==int(value)
    assert np.isclose(c.MedianMeanRatio,ratio.median(),rtol=1e-12)
detail=pd.read_csv(out/'function_comparisons.csv')
for row in detail.itertuples():
    subset=raw[raw.FunctionID.eq(row.FunctionID)].pivot(index='Seed',columns='Method',values='FinalError')
    delta=(subset['FO-Q']-subset[row.Reference]).to_numpy()
    expected=1. if np.all(delta==0) else wilcoxon(delta,zero_method='wilcox',method='auto').pvalue
    assert np.isclose(expected,row.WilcoxonP,rtol=1e-12)
pv=detail.WilcoxonP.to_numpy();order=np.argsort(pv);adj=np.empty(len(pv));running=0.
for k,i in enumerate(order):running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
assert np.allclose(adj,detail.HolmP,rtol=1e-12)
health=means.loc[[1,13,30],'FO-Q']/means.loc[[1,13,30],'FO-Base']
base=bool(comparisons.loc['FO-Base','MeanWins']>=5 and comparisons.loc['FO-Base','MedianMeanRatio']<=.95)
policy=bool(all(comparisons.loc[ref,'MeanWins']>=5 and comparisons.loc[ref,'MedianMeanRatio']<=1 for ref in ['FO-Rule','FO-Random']))
healthy=bool((health<=1).sum()>=2 and not (health>1.2).any())
gate=json.loads((out/'gate_decision.json').read_text(encoding='utf8'))
assert gate['BaseGate']==base and gate['PolicyGate']==policy and gate['HealthyGate']==healthy and gate['Passed']==(base and policy and healthy)
assert gate['FreshOptimizationCalls']==raw.ObjectiveCalls.sum() and gate['AuditCalls']==raw.PostRunRecheckCalls.sum()
integrity=pd.read_csv(out/'integrity_checks.csv');assert len(integrity)==320 and integrity.Passed.all()
assert integrity.BaseExactCacheEquivalent.sum()==80 and integrity.QReplayMaxDiff.max()<1e-12
curves=pd.read_csv(out/'convergence_nodes.csv');assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
final=curves[curves.FE.eq(100000)].set_index(['FunctionID','Seed','Method']).BestError
ref=raw.set_index(['FunctionID','Seed','Method']).FinalError.reindex(final.index)
assert len(final)==320 and np.allclose(final,ref,rtol=1e-12,atol=1e-10)
result={'Passed':True,'Rows':320,'MeansRecomputed':32,'ComparisonFamilies':3,'HolmTestsRecomputed':24,
        'FinalTraceNodesChecked':320,'GateRecomputed':True,'UsesPrivateMAT':False,
        'Limitation':'This verifies public numerical consistency; private engine/Q/state checks are recorded by the separate full audit.'}
(out/'public_verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(result,ensure_ascii=False,indent=2))
