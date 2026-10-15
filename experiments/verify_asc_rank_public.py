"""Recompute released ASC comparison statistics from public CSVs only."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon, friedmanchisquare
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'results/asc_comparison_30seed_20261015'
raw=pd.read_csv(out/'all_runs.csv');cfg=json.loads((out/'config.json').read_text(encoding='utf8'))
methods=cfg['FreshMethods']+cfg['ReferenceMethods'];assert len(methods)==8 and len(raw)==6960
assert not raw.duplicated(['FunctionID','Seed','Method']).any() and raw.groupby(['FunctionID','Seed']).Method.nunique().eq(8).all()
assert raw.Status.eq('ok').all() and raw.Evaluations.eq(100000).all() and raw.ObjectiveCalls.eq(100000).all() and raw.OutsideCalls.eq(0).all()
assert set(raw.Method)==set(methods) and not any('HIDMS' in m or m=='Original-CSO-MR02' for m in methods)
assert set(raw.FunctionID)==set([1]+list(range(3,31))) and set(raw.Seed)==set(range(3001,3031))
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
assert np.allclose(means,pd.read_csv(out/'function_means.csv',index_col=0),rtol=1e-12,atol=1e-8)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
assert np.allclose(std,pd.read_csv(out/'function_std.csv',index_col=0),rtol=1e-12,atol=1e-8)
rank=means.rank(axis=1).mean().sort_values();published=pd.read_csv(out/'mean_ranks.csv',index_col=0).iloc[:,0]
assert np.allclose(rank,published.reindex(rank.index),rtol=1e-12)
detail=pd.read_csv(out/'function_comparisons.csv');assert len(detail)==377
for row in detail.itertuples():
 p=raw[raw.FunctionID.eq(row.FunctionID)].pivot(index='Seed',columns='Method',values='FinalError')
 d=(p[row.Method]-p[row.Reference]).to_numpy();assert len(d)==30
 pv=1. if np.all(d==0) else float(wilcoxon(d,zero_method='wilcox',correction=True,method='approx').pvalue)
 assert np.isclose(pv,row.WilcoxonP,rtol=1e-10,atol=1e-15)
 assert row.SeedWins==(d<0).sum() and row.SeedLosses==(d>0).sum() and row.SeedTies==(d==0).sum()
def holm(p):
 p=np.asarray(p);a=np.empty(len(p));running=0
 for k,i in enumerate(np.argsort(p)):running=max(running,(len(p)-k)*p[i]);a[i]=min(1.,running)
 return a
assert np.allclose(holm(detail.WilcoxonP),detail.Holm377,rtol=1e-10,atol=1e-15)
mech=detail[detail.Method.eq('ASC-PositionRank')&detail.Reference.eq('ASC-NoFarness')]
assert len(mech)==29 and np.allclose(holm(mech.WilcoxonP),mech.Holm29Mechanism,rtol=1e-10,atol=1e-15)
overall=pd.read_csv(out/'overall_comparisons.csv');assert len(overall)==13
for row in overall.itertuples():
 d=detail[detail.Method.eq(row.Method)&detail.Reference.eq(row.Reference)]
 assert row.MeanWins==(d.MethodMean<d.ReferenceMean).sum() and row.MeanLosses==(d.MethodMean>d.ReferenceMean).sum()
 assert row.SeedWins==d.SeedWins.sum() and row.SeedLosses==d.SeedLosses.sum() and row.SeedTies==d.SeedTies.sum()
 assert row.SignificantBetter377==((d.Holm377<.05)&(d.MethodMean<d.ReferenceMean)).sum()
 assert row.SignificantWorse377==((d.Holm377<.05)&(d.MethodMean>d.ReferenceMean)).sum()
f=friedmanchisquare(*[means[m].to_numpy() for m in methods]);summary=json.loads((out/'analysis_validation.json').read_text(encoding='utf8'))
assert np.isclose(f.statistic,summary['FriedmanStatistic']) and np.isclose(f.pvalue,summary['FriedmanP'])
checks=pd.read_csv(out/'artifact_checks.csv');assert len(checks)==6960 and checks.TracePassed.all() and checks.SharedInitialPrefix.all() and checks.BestMatches.all()
curves=pd.read_csv(out/'convergence_nodes.csv');assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
last=curves[curves.FE.eq(100000)].set_index(['FunctionID','Seed','Method']).BestError
assert len(last)==6960 and np.allclose(last,raw.set_index(['FunctionID','Seed','Method']).FinalError.reindex(last.index),rtol=1e-12,atol=1e-8)
result={'Passed':True,'Rows':6960,'FreshRuns':1740,'CachedRuns':5220,'MeansChecked':232,'MainHolmTestsRecomputed':377,'MechanismHolmTestsRecomputed':29,'RankAndFriedmanRecomputed':True,'PrivateMATRequired':False}
(out/'public_verification.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result,indent=2))
