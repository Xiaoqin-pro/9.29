"""Independently verify published CSV statistics without private MAT files."""
from pathlib import Path
import argparse,json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
p=argparse.ArgumentParser();p.add_argument('result_directory',type=Path);a=p.parse_args();out=a.result_directory
raw=pd.read_csv(out/'all_runs.csv',float_precision='round_trip')
assert len(raw)==2320 and raw.Status.eq('ok').all() and raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all()
assert raw.OutsideCalls.eq(0).all() and raw.groupby(['FunctionID','Method']).size().eq(10).all()
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Seed']).InitSeed.nunique().eq(1).all()
assert raw.groupby(['FunctionID','Seed']).SearchSeed.nunique().eq(1).all()
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack()
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack()
reported=pd.read_csv(out/'function_means.csv',index_col=0,float_precision='round_trip')
reported_std=pd.read_csv(out/'function_stds.csv',index_col=0,float_precision='round_trip')
assert np.allclose(means[reported.columns],reported,rtol=1e-12,atol=1e-12)
assert np.allclose(std[reported_std.columns],reported_std,rtol=1e-12,atol=1e-12)
ranks=means.rank(axis=1).mean();rpt=pd.read_csv(out/'mean_ranks.csv',index_col=0).iloc[:,0]
assert np.allclose(ranks.reindex(rpt.index),rpt,atol=1e-12)
q=raw[raw.Method.eq('ELS-Q')].set_index(['FunctionID','Seed']).FinalError
cp=pd.read_csv(out/'function_comparisons.csv');newp=[]
for r in cp.itertuples():
    values=raw[(raw.Method==r.Control)&(raw.FunctionID==r.FunctionID)].set_index('Seed').FinalError
    d=q.loc[r.FunctionID]-values.reindex(q.loc[r.FunctionID].index)
    pv=1.0 if np.all(d.to_numpy()==0) else float(wilcoxon(d.to_numpy(),zero_method='wilcox',method='auto').pvalue)
    assert abs(pv-r.WilcoxonP)<1e-12
    assert (d<0).sum()==r.PairedSeedWins and (d>0).sum()==r.PairedSeedLosses
    newp.append(pv)
newp=np.array(newp);order=np.argsort(newp);adjusted=np.empty(len(newp));running=0
for k,i in enumerate(order):running=max(running,newp[i]*(len(newp)-k));adjusted[i]=min(1,running)
assert np.allclose(adjusted,cp.HolmAdjustedP,atol=1e-12)
curves=pd.read_csv(out/'convergence_nodes.csv',float_precision='round_trip')
assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
ph=pd.read_csv(out/'phase_gap_nodes.csv')
for r in ph.itertuples():
    assert abs(g.loc[(r.FunctionID,'ELS-Q',r.FE)]-r.QError)<=1e-10*max(1,abs(r.QError))
    assert abs(g.loc[(r.FunctionID,r.Control,r.FE)]-r.ControlError)<=1e-10*max(1,abs(r.ControlError))
report={'Passed':True,'Rows':2320,'Methods':8,'Functions':29,'Seeds':10,'PairedFunctionTests':len(cp),
 'Checks':'Raw-key/FE/pairing/mean/std/ranks/paired-Wilcoxon/Holm/phase-node reanalysis using released CSV only',
 'RequiresLocalMAT':False,'NewObjectiveCalls':0}
(out/'public_csv_reanalysis_verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
