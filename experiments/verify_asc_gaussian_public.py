"""CSV-only reproduction of the A0-A3 numerical comparisons."""
from pathlib import Path
import gzip, hashlib, json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'results/asc_gaussian_10seed_20261015'
raw=pd.read_csv(out/'all_runs.csv');assert len(raw)==320 and raw.Status.eq('ok').all()
assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.OutsideCalls.eq(0).all()
assert raw[['BestDiff','ProbeRecheckMaxDiff','ObservedTraceMaxDiff']].eq(0).all().all()
assert set(raw.Seed)==set(range(6001,6011)) and set(raw.Method)==set(['A0','A1','A2','A3'])
assert not raw.duplicated(['FunctionID','Seed','Method']).any() and raw.groupby(['FunctionID','Seed']).Method.nunique().eq(4).all()
assert raw[raw.Method.eq('A0')].ProbeEvaluations.eq(0).all() and raw[~raw.Method.eq('A0')].ProbeEvaluations.eq(1999).all()
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=['A0','A1','A2','A3'])
assert np.allclose(means,pd.read_csv(out/'function_means.csv',index_col=0),rtol=1e-12,atol=1e-8)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=means.columns)
assert np.allclose(std,pd.read_csv(out/'function_std.csv',index_col=0),rtol=1e-12,atol=1e-8)
c=pd.read_csv(out/'comparisons.csv');detail=pd.read_csv(out/'function_comparisons.csv');assert len(detail)==40 and len(c)==5
for row in c.itertuples():
 b=raw[raw.Method.eq(row.Reference)].set_index(['FunctionID','Seed']).FinalError;a=raw[raw.Method.eq(row.Method)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index)
 delta=a-b;ratio=means[row.Method]/means[row.Reference]
 assert row.MeanWins==(ratio<1).sum() and row.MeanLosses==(ratio>1).sum() and row.MeanTies==(ratio==1).sum()
 assert row.SeedWins==(delta<0).sum() and row.SeedLosses==(delta>0).sum() and row.SeedTies==(delta==0).sum()
 assert np.isclose(row.MedianMeanRatio,ratio.median(),rtol=1e-12)
for row in detail.itertuples():
 z=raw[raw.FunctionID.eq(row.FunctionID)].pivot(index='Seed',columns='Method',values='FinalError');delta=(z[row.Method]-z[row.Reference]).to_numpy()
 pv=1. if np.all(delta==0) else float(wilcoxon(delta,zero_method='wilcox',method='auto').pvalue)
 assert np.isclose(row.WilcoxonP,pv,rtol=1e-12)
pv=detail.WilcoxonP.to_numpy();adj=np.empty(len(pv));running=0
for k,i in enumerate(np.argsort(pv)):running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
assert np.allclose(adj,detail.Holm40,rtol=1e-12)
x=c.set_index(['Method','Reference']);ratio=means.A3/means.A0
checks=dict(A3VsA0=bool(x.loc[('A3','A0'),'MeanWins']>=5 and x.loc[('A3','A0'),'MedianMeanRatio']<=.95),
 A3VsA1=bool(x.loc[('A3','A1'),'MeanWins']>=5 and x.loc[('A3','A1'),'MedianMeanRatio']<=1),
 A3VsA2=bool(x.loc[('A3','A2'),'MeanWins']>=5 and x.loc[('A3','A2'),'MedianMeanRatio']<=1),
 F6F9F24F27Guard=bool((ratio.loc[[6,9,24,27]]<=1.1).all()),AllFunctionsGuard=bool((ratio<=1.2).all()))
g=json.loads((out/'gate_decision.json').read_text(encoding='utf8'));assert g['GateChecks']==checks and g['Passed']==all(checks.values())
assert g['OptimizationCalls']==raw.ObjectiveCalls.sum() and g['AuditCalls']==raw.PostRunRecheckCalls.sum()
curves=pd.read_csv(out/'convergence_nodes.csv');assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
last=curves[curves.FE.eq(100000)].set_index(['FunctionID','Seed','Method']).BestError
assert len(last)==320 and np.allclose(last,raw.set_index(['FunctionID','Seed','Method']).FinalError.reindex(last.index),rtol=1e-12,atol=1e-8)
integrity=pd.read_csv(out/'integrity_checks.csv');assert len(integrity)==320 and integrity.Passed.all()
archive=json.loads((out/'probe_events_archive.json').read_text(encoding='utf8'))
h=hashlib.sha256(); size=0
with gzip.open(out/'probe_events.csv.gz','rb') as stream:
 for block in iter(lambda:stream.read(1024*1024),b''):h.update(block);size+=len(block)
assert h.hexdigest()==archive['UncompressedSHA256'] and size==archive['UncompressedBytes']
for name in ['ASC_NoFarness.m','ASC_NoFarness_EliteGaussian.m','run_asc_gaussian_job.m','run_asc_gaussian_study.m']:
 manifest=pd.read_csv(out/'prelaunch_hashes.csv');entry=manifest[manifest.RelativePath.str.replace('\\','/',regex=False).eq('source/'+name)]
 assert len(entry)==1 and hashlib.sha256((out/'source'/name).read_bytes()).hexdigest()==entry.iloc[0].SHA256
probes=pd.read_csv(out/'probe_events.csv.gz');assert len(probes)==raw.ProbeEvaluations.sum()==479760
assert set(probes.Method)==set(['A1','A2','A3']) and probes.groupby(['FunctionID','Seed','Method']).size().eq(1999).all()
rep=dict(Passed=True,Rows=320,FunctionMeansChecked=32,PairedTestsRecomputed=40,HolmTestsRecomputed=40,ProbeRowsChecked=len(probes),GateRecomputed=True,PrivateMATRequired=False,ProbeArchiveSHA256Verified=True,SourceSnapshotsVerified=True)
(out/'public_verification.json').write_text(json.dumps(rep,indent=2),encoding='utf8');print(json.dumps(rep,indent=2))
