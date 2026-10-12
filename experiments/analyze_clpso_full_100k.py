"""Independent full-CEC paired five-seed audit against author-profile CLPSO."""
from pathlib import Path
import argparse,hashlib,itertools,json,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
from scipy.stats import rankdata
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/clpso_full_100k_20261012'
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');assert len(raw)==290 and raw.Status.eq('ok').all()
conds={'CSO-Fixed6','CLPSO-AuthorSource40'};assert set(raw.Condition)==conds and set(raw.FunctionID)=={1,*range(3,31)} and set(raw.Seed)==set(range(2201,2206)) and set(raw.Dimension)=={50} and set(raw.Budget)=={100000}
assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.PostRunRecheckCalls.eq(1).all() and raw.OutsideCalls.eq(0).all() and not raw.duplicated(['FunctionID','Seed','Condition']).any()
prefix={};checked=0
for row in raw.itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);T=np.asarray(d['T']).reshape(-1);B=d['B'];I=d['I'];p0=np.asarray(d['p0']);assert len(T)==100000 and np.isfinite(T).all() and (np.diff(T)<=0).all() and T[-1]==B['Cost'] and I['Evaluations']==100000
 assert p0.shape==(row.Population,50) and np.all((p0>=-100)&(p0<=100)) and np.all((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100))
 assert abs(row.FinalCost-B['Cost'])<=1e-8*max(1,abs(row.FinalCost)) and abs(row.FinalError-(row.FinalCost-100*row.FunctionID))<1e-7
 key=(row.FunctionID,row.Seed);other=prefix.get(key)
 if other is not None:assert np.array_equal(other[:min(len(other),len(p0))],p0[:min(len(other),len(p0))])
 if other is None or len(other)<len(p0):prefix[key]=p0
 for frac,col in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:assert abs(T[int(frac*100000)-1]-100*row.FunctionID-getattr(row,col))<=1e-8*max(1,abs(getattr(row,col)))
 if row.Condition=='CSO-Fixed6':
  R=np.asarray(I['RoundLog']).reshape(-1,13);assert I['ModeTraceQuota']==6 and I['MaxParentEvaluations']<=2 and row.Population==50
  assert row.TracingEvaluations+row.SeekingEvaluations==99950 and R[:,2].sum()==row.TracingEvaluations and R[:,3].sum()==row.SeekingEvaluations
 else:assert row.Population==40 and row.SkippedOutside==I['SkippedOutside'] and row.Iterations==I['Iterations']
 checked+=1
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json']:shutil.copy2(run/name,out/name)
checks=dict(Runs=checked,CommonInitialPrefixGroups=len(prefix),ActualObjectiveCalls=int(raw.ObjectiveCalls.sum()),ExtraBestRechecks=int(raw.PostRunRecheckCalls.sum()),Passed=True,Checks='All MAT/CSV, source p0 prefix, legal objective calls, exact real-FE cap, monotone complete T, mode counts, Best/nodes')
(out/'independent_artifact_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8');shutil.copy2(root/'work/clpso_full_20261012/preflight.json',out/'preflight.json');shutil.copy2(root/'work/clpso_audit_20261012/source_provenance.json',out/'author_source_provenance.json')
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),BestError=('FinalError','min'),WorstError=('FinalError','max'),MeanSeconds=('Seconds','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean'),MeanIterations=('Iterations','mean'),MeanSkippedOutside=('SkippedOutside','mean'),MeanFirstImprovementFE=('FirstImprovementEvaluation','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False)
means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');medians=s.pivot(index='FunctionID',columns='Condition',values='MedianError');means.to_csv(out/'function_mean_errors.csv');ranks=s.groupby('Condition').Rank.mean();ranks.to_csv(out/'mean_ranks.csv')
m=raw[raw.Condition=='CSO-Fixed6'].merge(raw[raw.Condition=='CLPSO-AuthorSource40'],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_cso','_clpso'),validate='one_to_one');assert len(m)==145;m['Difference']=m.FinalError_cso-m.FinalError_clpso;m['ErrorRatio']=(m.FinalError_cso.clip(lower=0)+1e-12)/(m.FinalError_clpso.clip(lower=0)+1e-12);m['TimeRatio']=m.Seconds_cso/m.Seconds_clpso;m.to_csv(out/'paired_runs.csv',index=False)
stats=[]
for fid,g in m.groupby('FunctionID'):
 diff=g.Difference.to_numpy();nz=diff[diff!=0]
 if len(nz):
  r=rankdata(np.abs(nz),method='average');w=r[nz>0].sum();mid=r.sum()/2;dist=np.array([np.dot(bits,r) for bits in itertools.product([0,1],repeat=len(nz))]);pv=float((np.abs(dist-mid)>=abs(w-mid)-1e-12).mean())
 else:w=0;pv=1
 csoMean=float(means.loc[fid,'CSO-Fixed6']);clMean=float(means.loc[fid,'CLPSO-AuthorSource40']);ratio=(max(0,csoMean)+1e-12)/(max(0,clMean)+1e-12)
 stats.append(dict(FunctionID=int(fid),CSOMean=csoMean,CLPSOMean=clMean,MeanWinner='CSO' if csoMean<clMean else 'CLPSO' if csoMean>clMean else 'Tie',CSOSeedWins=int((diff<0).sum()),CLPSOSeedWins=int((diff>0).sum()),SeedTies=int((diff==0).sum()),MedianPairedDifference=float(np.median(diff)),MeanErrorRatio=ratio,MedianTimeRatio=float(g.TimeRatio.median()),PValue=pv,WPositive=float(w),NonzeroPairs=len(nz)))
stats=pd.DataFrame(stats);order=np.argsort(stats.PValue.to_numpy());adj=np.maximum.accumulate([(len(stats)-k)*stats.PValue.iloc[i] for k,i in enumerate(order)]);stats['HolmPValue']=0.
for ix,v in zip(order,adj):stats.loc[ix,'HolmPValue']=min(1,float(v))
stats['HolmSignificant05']=stats.HolmPValue<=.05;stats.to_csv(out/'function_comparison.csv',index=False)
fw=int((means['CSO-Fixed6']<means['CLPSO-AuthorSource40']).sum());fl=int((means['CSO-Fixed6']>means['CLPSO-AuthorSource40']).sum());sw=int((m.Difference<0).sum());sl=int((m.Difference>0).sum())
overall=dict(Dimension=50,Budget=100000,Functions=29,Seeds=5,NewRuns=290,ObjectiveCalls=int(raw.ObjectiveCalls.sum()),CSOPopulation=50,CLPSOPopulation=40,CSOFunctionWins=fw,CLPSOFunctionWins=fl,FunctionTies=29-fw-fl,CSOSeedWins=sw,CLPSOSeedWins=sl,SeedTies=145-sw-sl,CSOMedianFunctionWins=int((medians['CSO-Fixed6']<medians['CLPSO-AuthorSource40']).sum()),CLPSOMedianFunctionWins=int((medians['CSO-Fixed6']>medians['CLPSO-AuthorSource40']).sum()),CSOAverageRank=float(ranks['CSO-Fixed6']),CLPSOAverageRank=float(ranks['CLPSO-AuthorSource40']),CSOMeanSeconds=float(raw[raw.Condition=='CSO-Fixed6'].Seconds.mean()),CLPSOMeanSeconds=float(raw[raw.Condition=='CLPSO-AuthorSource40'].Seconds.mean()),MedianPairedTimeRatio=float(m.TimeRatio.median()),HolmSignificantFunctions=int(stats.HolmSignificant05.sum()),Scope='Full 29-function D50 low-budget five-seed screening; author-public-code CLPSO profile, N40 vsCSO50; not complete original-paper reproduction or statistical superiority')
(out/'overall.json').write_text(json.dumps(overall,indent=2),encoding='utf-8')
node_rows=[]
for col in ['MeanError20FE','MeanError60FE','MeanError80FE','MeanError']:
 z=s.pivot(index='FunctionID',columns='Condition',values=col);node_rows.append(dict(Node=col,CSOFunctionWins=int((z['CSO-Fixed6']<z['CLPSO-AuthorSource40']).sum()),CLPSOFunctionWins=int((z['CSO-Fixed6']>z['CLPSO-AuthorSource40']).sum())))
pd.DataFrame(node_rows).to_csv(out/'node_function_wins.csv',index=False)
source=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();source.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',root/'data/cec2017/D50_manifest.csv',Path(__file__)]:source.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),Sources=source),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('clpso_full_100k_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==4 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# Fixed6-CSO vs作者源码CLPSO完整29函数（2026-10-12）','', 'D50/100k、五新seed，290run/29M真实FE完成；290Best重查与四smoke单列。所有独立MAT/真实FE/合法目标域/共享初始前缀核验通过。','',f'函数均值CSO/CLPSO胜负{fw}/{fl}（平{29-fw-fl}），逐seed{sw}/{sl}（平{145-sw-sl}）；中位数函数胜场{overall["CSOMedianFunctionWins"]}/{overall["CLPSOMedianFunctionWins"]}。',f'平均时间CSO{overall["CSOMeanSeconds"]:.3f}秒、CLPSO{overall["CLPSOMeanSeconds"]:.3f}秒；平均函数排名{overall["CSOAverageRank"]:.3f}/{overall["CLPSOAverageRank"]:.3f}。','', '五seed精确双侧符号秩最小p=.0625，不能在0.05检出；本批29函数Holm无显著函数。均值胜场不是显著性，未显著不等效。','', 'CSO固定6T4S/NP50，没有Q；CLPSO作者公开代码profile/NP40，源码参数与2006论文文本不同，不能贴精确论文复现标签。NP40是从原论文D30群体设置沿用，D50本轮适配。两者同FE、相同初始化池前缀，人口不同明确保留。','', '所有函数与不利结果公开，不用旧clip边界CLPSO成绩支撑新版优势。100k低预算结果不自动推广到标准500k、其它维度或SOTA。']
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(json.dumps(overall,indent=2));print(stats[['FunctionID','MeanWinner','CSOMean','CLPSOMean','CSOSeedWins','CLPSOSeedWins']].to_string(index=False));print('OUTPUT',out)
