"""Frozen stall-state quota Q vs author-profile CLPSO and the paired no-Q Fixed6 control."""
from pathlib import Path
import argparse,json,hashlib,itertools,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
from scipy.stats import rankdata
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_full_100k_20261012'
assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');check=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==145 and new.Status.eq('ok').all() and check['RunsChecked']==145 and check['AllCompleted'] and check['Passed']
assert set(new.FunctionID)=={1,*range(3,31)} and set(new.Seed)==set(range(2201,2206)) and set(new.Condition)=={'CSO-QuotaQ-Stall1000'} and set(new.Dimension)=={50} and set(new.Budget)=={100000} and new.Population.eq(50).all()
old_dir=root/'results/cec/clpso_full_100k_study_20261012_193032';old=pd.read_csv(root/'results/clpso_full_100k_20261012/raw_runs.csv');assert len(old)==290 and old.Status.eq('ok').all();old['Origin']='cached-previous-batch';old['SourceDirectory']=str(old_dir);new['Origin']='new-Q';new['SourceDirectory']=str(run);raw=pd.concat([old,new],ignore_index=True);assert len(raw)==435 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
keys=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'];prefix_pairs=0
for row in new.itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);p0=d['p0'];T=np.asarray(d['T']).reshape(-1)
 oldrows=old[(old.FunctionID==row.FunctionID)&(old.Seed==row.Seed)]
 for r in oldrows.itertuples():
  assert r.Budget==row.Budget and r.Dimension==row.Dimension and r.InitSeed==row.InitSeed and r.SearchSeed==row.SearchSeed
  cached=loadmat(old_dir/'runs'/f'job_{r.JobID:04d}.mat',simplify_cells=True);assert np.array_equal(np.asarray(cached['p0']),np.asarray(p0)[:r.Population]);prefix_pairs+=1
 for fraction,col in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:assert abs(T[int(100000*fraction)-1]-100*row.FunctionID-getattr(row,col))<=1e-8*max(1,abs(getattr(row,col)))
out.mkdir(exist_ok=True);new.to_csv(out/'raw_runs.csv',index=False);raw.to_csv(out/'all_quality_runs.csv',index=False)
for name in ['job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_full_20261012/source_cache_checks.json',out/'source_cache_checks.json')
(out/'cached_p0_checks.json').write_text(json.dumps(dict(NewQRuns=145,MatchedActualInitialPrefixPairs=prefix_pairs,CachedQualityRuns=290,Passed=True),indent=2),encoding='utf-8')
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),BestError=('FinalError','min'),WorstError=('FinalError','max'),MeanSeconds=('Seconds','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');medians=s.pivot(index='FunctionID',columns='Condition',values='MedianError');means.to_csv(out/'function_mean_errors.csv')
comparisons=[];stats=[];pairs=[];qname='CSO-QuotaQ-Stall1000'
for control in ['CLPSO-AuthorSource40','CSO-Fixed6']:
 m=raw[raw.Condition==qname].merge(raw[raw.Condition==control],on=keys,suffixes=('_q','_control'),validate='one_to_one');assert len(m)==145;m['Control']=control;m['Difference']=m.FinalError_q-m.FinalError_control;m['TimeRatio']=m.Seconds_q/m.Seconds_control;pairs.append(m)
 ma=means[qname];mb=means[control];ratio=(ma.clip(lower=0)+1e-12)/(mb.clip(lower=0)+1e-12);sw=int((m.Difference<0).sum());sl=int((m.Difference>0).sum());fw=int((ma<mb).sum());fl=int((ma>mb).sum())
 comparisons.append(dict(Control=control,QFunctionWins=fw,ControlFunctionWins=fl,FunctionTies=29-fw-fl,QSeedWins=sw,ControlSeedWins=sl,SeedTies=145-sw-sl,QMedianFunctionWins=int((medians[qname]<medians[control]).sum()),ControlMedianFunctionWins=int((medians[qname]>medians[control]).sum()),MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),QAverageRank=float(ranks[qname]),ControlAverageRank=float(ranks[control]),QMeanSeconds=float(raw[raw.Condition==qname].Seconds.mean()),ControlMeanSeconds=float(raw[raw.Condition==control].Seconds.mean()),MedianMatchedTimeRatio=float(m.TimeRatio.median())))
 for fid,g in m.groupby('FunctionID'):
  dif=g.Difference.to_numpy();nz=dif[dif!=0]
  if len(nz):
   r=rankdata(np.abs(nz),method='average');w=r[nz>0].sum();center=r.sum()/2;dist=np.array([np.dot(bits,r) for bits in itertools.product([0,1],repeat=len(nz))]);pv=float((np.abs(dist-center)>=abs(w-center)-1e-12).mean())
  else:w=0;pv=1
  stats.append(dict(Control=control,FunctionID=int(fid),QMean=float(means.loc[fid,qname]),ControlMean=float(means.loc[fid,control]),QSeedWins=int((dif<0).sum()),ControlSeedWins=int((dif>0).sum()),SeedTies=int((dif==0).sum()),MedianDifference=float(np.median(dif)),PValue=pv,WPositive=float(w),NonzeroPairs=len(nz)))
stats=pd.DataFrame(stats);stats['HolmPValue']=0.
for control,g in stats.groupby('Control'):
 order=np.argsort(g.PValue.to_numpy());adj=np.maximum.accumulate([(len(g)-k)*g.PValue.iloc[i] for k,i in enumerate(order)])
 for ix,v in zip(g.index.to_numpy()[order],adj):stats.loc[ix,'HolmPValue']=min(1,float(v))
stats['HolmSignificant05']=stats.HolmPValue<=.05;stats.to_csv(out/'function_comparison.csv',index=False);pd.DataFrame(comparisons).to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
raw[raw.Condition==qname].groupby('FunctionID')[['PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QuotaFallbackRounds']].mean().to_csv(out/'q_policy_by_function.csv');diagnostics=raw[raw.Condition==qname][['PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QuotaFallbackRounds']].mean().to_dict()
(out/'overall.json').write_text(json.dumps(dict(Dimension=50,Budget=100000,Functions=29,Seeds=5,NewQOptimizationRuns=145,NewObjectiveCalls=int(new.ObjectiveCalls.sum()),ExtraBestRechecks=145,CachedQualityRows=290,AllQualityRows=435,Comparisons=comparisons,QPolicy=diagnostics,HolmSignificantFunctions=int(stats.HolmSignificant05.sum()),Scope='Full-suite five-seed low-budget screening; comparisons to no-Q and author-profile CLPSO; timing cached across batches'),indent=2),encoding='utf-8')
nodes=[]
for control in ['CLPSO-AuthorSource40','CSO-Fixed6']:
 for col in ['MeanError20FE','MeanError60FE','MeanError80FE','MeanError']:
  z=s.pivot(index='FunctionID',columns='Condition',values=col);nodes.append(dict(Control=control,Node=col,QFunctionWins=int((z[qname]<z[control]).sum()),ControlFunctionWins=int((z[qname]>z[control]).sum())))
pd.DataFrame(nodes).to_csv(out/'node_function_wins.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/clpso_full_100k_20261012/raw_runs.csv',root/'results/clpso_full_100k_20261012/source_manifest.json',root/'data/cec2017/cec17_func.mexw64',root/'data/cec2017/D50_manifest.csv',Path(__file__),root/'experiments/verify_quota_q_full_100k.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(NewRunDirectory=str(run),CachedRunDirectory=str(old_dir),CachedRowsAreNotNewRuns=True,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('quota_q_full_100k_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==2 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 小Q纯配额版vsCLPSO同规模完整CEC（2026-10-12）','', 'D50/100k、F1/F3–F30、五相同seed2201–2205。新增145次Q运行/14.5M真实FE；此前CLPSO和Fixed6各145run缓存复用，三条件435质量记录，不重复算新run。完整真实T/Q/state/reward/terminal及290个cachedp0前缀匹配通过。','',f'平均函数rank：{ranks.to_dict()}。','']
for c in comparisons:report.append(f"- Q vs {c['Control']}：函数均值{c['QFunctionWins']}:{c['ControlFunctionWins']}，seed{c['QSeedWins']}:{c['ControlSeedWins']}，中位数函数胜{c['QMedianFunctionWins']}:{c['ControlMedianFunctionWins']}；平均秒{c['QMeanSeconds']:.3f}:{c['ControlMeanSeconds']:.3f}。")
report.extend(['','五seed精确双侧最小p=.0625，29Holm没有0.05显著函数；均值胜场不改写显著。CLPSO为作者公开codeprofileCEC适配/NP40（与2006paper文字参数不同），Q/Fixed6 NP50，shared初始化池prefix而非相同群体。','', 'Q原样phase3×真实持续1000FE停滞bit6×3表、100FE块、±1奖励、alpha.1/gamma.9/eps.1，原B10搜索方程/半径完全不变。对CLPSO优势不直接证明Q增益，必须与同骨架Fixed6分别解读。','', '缓存时间来自前一批，新Q带div/state日志有开销，微小秒差不能单归学习。所有29函数和五seed完整报告，未据结果替换Q版本、调参或增seed。本批非全预算/其它维度/发表验收。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(pd.DataFrame(comparisons).to_string(index=False));print(ranks.to_string());print(json.dumps(diagnostics,indent=2));print('OUTPUT',out)
