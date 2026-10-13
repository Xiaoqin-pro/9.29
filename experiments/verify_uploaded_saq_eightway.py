"""Recompute published SAQ-CSO statistics from the uploaded per-seed CSV only.
MATLAB run artifacts remain local; this verifies the numeric reporting layer.
"""
from pathlib import Path
import argparse,json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
p=argparse.ArgumentParser();p.add_argument('result_dir',type=Path);a=p.parse_args();out=a.result_dir
raw=pd.read_csv(out/'all_quality_runs.csv');summary=pd.read_csv(out/'summary.csv');pairs=pd.read_csv(out/'function_comparison.csv');ranks=pd.read_csv(out/'mean_ranks.csv',index_col=0).iloc[:,0]
assert len(raw)==6960 and raw.Status.eq('ok').all() and raw.Budget.eq(100000).all()
assert raw.Evaluations.eq(100000).all() and raw.ObjectiveCalls.eq(100000).all()
assert raw.PostRunRecheckCalls.eq(1).all() and raw.OutsideCalls.eq(0).all()
assert not raw.duplicated(['FunctionID','Seed','Condition']).any()
computed=raw.groupby(['FunctionID','Condition']).FinalError.agg(['size','mean','std','median'])
for row in summary.itertuples():
    s=computed.loc[(row.FunctionID,row.Condition)];assert s['size']==row.N==30
    assert np.allclose([s['mean'],s['std'],s['median']],[row.MeanError,row.StdError,row.MedianError],rtol=1e-12,atol=1e-7)
means=computed['mean'].unstack();rank=means.rank(axis=1,method='average').mean()
assert np.allclose(rank.reindex(ranks.index),ranks,rtol=1e-13,atol=1e-13)
calculated=[]
for row in pairs.itertuples():
    group=raw[raw.FunctionID==row.FunctionID].pivot(index='Seed',columns='Condition',values='FinalError')
    diff=group['SAQ-CSO'].to_numpy()-group[row.Control].to_numpy()
    pv=1. if np.all(diff==0) else wilcoxon(diff,zero_method='wilcox',correction=True,method='approx',alternative='two-sided').pvalue
    assert np.isclose(pv,row.PValue,rtol=1e-12,atol=1e-16)
    assert ((diff<0).sum(),(diff>0).sum(),(diff==0).sum())==(row.SeedWins,row.SeedLosses,row.SeedTies)
    calculated.append(pv)
arr=np.asarray(calculated);order=np.argsort(arr);holm=np.zeros(len(arr));holm[order]=np.minimum(1,np.maximum.accumulate(arr[order]*np.arange(len(arr),0,-1)))
assert np.allclose(holm,pairs.HolmAll,rtol=1e-12,atol=1e-16)
result={'Rows':len(raw),'Functions':29,'Seeds':30,'Methods':8,'PerFunctionComparisons':len(pairs),'MeanStdMedianRanksAndHolmReproduced':True,'Scope':'Numeric reporting layer from uploaded CSV; not a substitute for source/MATLAB checks','Passed':True}
(out/'csv_reanalysis_verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
