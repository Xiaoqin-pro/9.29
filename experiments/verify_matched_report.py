"""Reproduce report numbers from uploaded raw per-seed data only."""
from pathlib import Path
import argparse,json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);a=p.parse_args();out=a.directory
raw=pd.read_csv(out/'all_quality_runs.csv');summary=pd.read_csv(out/'summary.csv');tests=pd.read_csv(out/'function_comparison.csv');protocol=json.loads((out/'statistics_protocol.json').read_text())
assert len(raw)==raw.Condition.nunique()*870 and raw.Status.eq('ok').all() and raw.ObjectiveCalls.eq(100000).all()
computed=raw.groupby(['FunctionID','Condition']).FinalError.agg(['size','mean','std','median'])
for r in summary.itertuples():
 s=computed.loc[(r.FunctionID,r.Condition)];assert r.N==s['size']==30 and np.allclose([r.MeanError,r.StdError,r.MedianError],s[['mean','std','median']],rtol=1e-12,atol=1e-7)
rank=computed['mean'].unstack().rank(axis=1).mean();reported=pd.read_csv(out/'mean_ranks.csv',index_col=0).iloc[:,0];assert np.allclose(rank.reindex(reported.index),reported,rtol=1e-13,atol=1e-13)
for r in tests.itertuples():
 s=raw[raw.FunctionID==r.FunctionID].pivot(index='Seed',columns='Condition',values='FinalError');diff=s[r.Left].to_numpy()-s[r.Right].to_numpy()
 pv=1 if np.all(diff==0) else wilcoxon(diff,zero_method='wilcox',correction=True,alternative='two-sided',method='approx').pvalue
 assert np.isclose(pv,r.PValue,rtol=1e-12,atol=1e-16) and (int((diff<0).sum()),int((diff>0).sum()),int((diff==0).sum()))==(r.SeedWins,r.SeedLosses,r.SeedTies)
order=np.argsort(tests.PValue.to_numpy());expected=np.empty(len(tests));expected[order]=np.minimum(1,np.maximum.accumulate(tests.PValue.to_numpy()[order]*np.arange(len(tests),0,-1)))
assert np.allclose(expected,tests.HolmAll,rtol=1e-12,atol=1e-16) and len(tests)==protocol['HolmFamily']
r={'Passed':True,'QualityRecords':len(raw),'Methods':raw.Condition.nunique(),'PerFunctionTests':len(tests),'Reproduced':'mean/std/median/rank/pairedWilcoxon/Holm','Scope':'Numeric tables only, independent source/MAT verification separately required'}
(out/'csv_reanalysis_verification.json').write_text(json.dumps(r,indent=2),encoding='utf-8');print(json.dumps(r,indent=2))
