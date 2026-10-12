"""CLPSO provenance/variant audit: independent MAT checks and honest small-scope comparisons."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/clpso_audit_20261012';out.mkdir(exist_ok=True)
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');assert len(raw)==108 and raw.Status.eq('ok').all()
assert set(raw.Condition)=={'B10','Legacy','PaperBoundary','Init20','AuthorSource50','AuthorSource40'} and set(raw.Budget)=={60000,300000} and set(raw.FunctionID)=={1,6,13} and set(raw.Seed)=={2101,2102,2103}
assert not raw.duplicated(['FunctionID','Seed','Budget','Condition']).any() and raw.ObjectiveCalls.eq(raw.Budget).all() and raw.Evaluations.eq(raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
starts={};rechecked=0
for r in raw.itertuples():
 d=loadmat(run/'runs'/f'job_{r.JobID:04d}.mat',simplify_cells=True);T=np.asarray(d['T']).reshape(-1);B=d['B'];I=d['I'];p0=np.asarray(d['p0'])
 assert len(T)==r.Budget and np.isfinite(T).all() and (np.diff(T)<=0).all() and T[-1]==B['Cost'] and I['Evaluations']==r.Budget
 assert abs(B['Cost']-r.FinalCost)<=1e-8*max(1,abs(r.FinalCost)) and abs(r.FinalCost-100*r.FunctionID-r.FinalError)<1e-7
 assert p0.shape==(r.Population,30) and np.all((p0>=-100)&(p0<=100)) and np.all((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100))
 key=(r.FunctionID,r.Seed,r.Budget);prev=starts.get(key)
 if prev is not None:assert np.array_equal(prev[:min(len(prev),len(p0))],p0[:min(len(prev),len(p0))])
 if prev is None or len(p0)>len(prev):starts[key]=p0
 for frac,col in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:assert abs(T[int(round(frac*r.Budget))-1]-100*r.FunctionID-getattr(r,col))<=1e-8*max(1,abs(getattr(r,col)))
 rechecked+=1
(out/'independent_artifact_checks.json').write_text(json.dumps(dict(Runs=rechecked,SharedInitialGroups=len(starts),Passed=True,Scope='All MAT/CSV, actual FE, legal evaluations, monotone complete trace and common initial-prefix audit. Author source variants are adapters, not exact 2006-table reproductions.'),indent=2),encoding='utf-8')
for name in ['raw_runs.csv','job_manifest.csv']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/clpso_audit_20261012/behavior_checks.json',out/'behavior_checks.json');shutil.copy2(root/'work/clpso_audit_20261012/source_provenance.json',out/'author_source_provenance.json')
s=raw.groupby(['Budget','FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),MeanIterations=('Iterations','mean'),MeanSkippedOutside=('SkippedOutside','mean'),MeanBoundaryClips=('BoundaryClips','mean'),MeanRefresh=('RefreshCount','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean')).reset_index();s.to_csv(out/'summary.csv',index=False)
comparisons=[];pairrows=[]
for ca,cb in [('PaperBoundary','Legacy'),('Init20','Legacy'),('AuthorSource50','Legacy'),('AuthorSource40','Legacy'),('B10','Legacy'),('B10','PaperBoundary'),('B10','AuthorSource50'),('B10','AuthorSource40')]:
 m=raw[raw.Condition==ca].merge(raw[raw.Condition==cb],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_a','_b'),validate='one_to_one');assert len(m)==18;m['A']=ca;m['B']=cb;pairrows.append(m)
 for budget,g in m.groupby('Budget'):
  ga=g.groupby('FunctionID').FinalError_a.mean();gb=g.groupby('FunctionID').FinalError_b.mean();ratio=(ga.clip(lower=0)+1e-12)/(gb.clip(lower=0)+1e-12)
  comparisons.append(dict(Budget=int(budget),A=ca,B=cb,FunctionAWins=int((ga<gb).sum()),FunctionBWins=int((ga>gb).sum()),SeedAWins=int((g.FinalError_a<g.FinalError_b).sum()),SeedBWins=int((g.FinalError_a>g.FinalError_b).sum()),MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MeanASeconds=float(g.Seconds_a.mean()),MeanBSeconds=float(g.Seconds_b.mean())))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairrows,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',Path(__file__),root/'work/clpso_audit_20261012/author_bundle/TEC matlab code/CLPSO_new_func.m',root/'work/clpso_audit_20261012/CLPSO_AuthorOracle.m']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=108,ActualObjectiveCalls=int(raw.ObjectiveCalls.sum()),ExtraBestRechecks=108,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('clpso_audit_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==6 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
print(c.to_string(index=False));print(s.pivot(index=['Budget','FunctionID'],columns='Condition',values='MeanError').to_string());print('OUTPUT',out)
