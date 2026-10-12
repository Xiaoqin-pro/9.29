"""Independent ten-seed SMP3 confirmation; preserve all conditions and results."""
from pathlib import Path
import argparse, hashlib, itertools, json, shutil
import numpy as np
import pandas as pd
from scipy.stats import rankdata

root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--output',type=Path,default=root/'results/cso_smp3_confirm_20261012');a=p.parse_args();run=a.run_dir.resolve();out=a.output.resolve()
assert (run/'COMPLETED.json').exists()
raw=pd.read_csv(run/'raw_runs.csv');manifest=pd.read_csv(run/'job_manifest.csv');checks=json.loads((run/'independent_artifact_checks.json').read_text())
assert len(raw)==len(manifest)==160 and raw.Status.eq('ok').all()
assert checks['RunsChecked']==160 and checks['AllCompleted'] and checks['Passed']
assert set(raw.Dimension)=={50} and set(raw.Budget)=={100000} and set(raw.Seed)==set(range(1201,1211))
assert not raw.duplicated(['FunctionID','Seed','Condition']).any()
assert set(raw.Condition)=={'B10','SMP3'}
assert raw.ObjectiveCalls.eq(raw.Budget).all() and raw.Evaluations.eq(raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
assert (raw.TracingEvaluations+raw.SeekingEvaluations).eq(raw.Budget-50).all() and raw.TraceFinite.all() and raw.TraceMonotone.all()
out.mkdir(parents=True,exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:
    shutil.copy2(run/name,out/name)
summary=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean'),MeanCoverage=('MeanSeekCoverage','mean'),TraceGlobalSuccesses=('TraceGlobalSuccesses','mean'),SeekGlobalSuccesses=('SeekGlobalSuccesses','mean')).reset_index()
assert summary.Runs.eq(10).all()
summary['MeanErrorRank']=summary.groupby('FunctionID').MeanError.rank(method='average')
summary.to_csv(out/'summary.csv',index=False)
b=raw[raw.Condition=='B10'];s=raw[raw.Condition=='SMP3']
m=s.merge(b,on=['Budget','FunctionID','Seed','Dimension','InitSeed','SearchSeed'],suffixes=('_smp3','_b10'),validate='one_to_one');assert len(m)==80
m['ErrorDifference']=m.FinalError_smp3-m.FinalError_b10
m['ErrorRatio']=(m.FinalError_smp3.clip(lower=0)+1e-12)/(m.FinalError_b10.clip(lower=0)+1e-12)
m['TimeRatio']=m.Seconds_smp3/m.Seconds_b10
m.to_csv(out/'paired_runs.csv',index=False)

def conditional_signed_rank(d):
    d=np.asarray(d);d=d[d!=0]
    if not len(d):return 1.0,0.0,0
    ranks=rankdata(np.abs(d),method='average'); observed=float(ranks[d>0].sum());center=float(ranks.sum()/2)
    values=np.array([np.dot(bits,ranks) for bits in itertools.product([0,1],repeat=len(d))])
    return float(np.mean(np.abs(values-center)>=abs(observed-center)-1e-12)), observed, len(d)

stats=[]
for fid,g in m.groupby('FunctionID'):
    pv,w,n=conditional_signed_rank(g.ErrorDifference)
    stats.append(dict(FunctionID=int(fid),SMP3SeedWins=int((g.ErrorDifference<0).sum()),B10SeedWins=int((g.ErrorDifference>0).sum()),SeedTies=int((g.ErrorDifference==0).sum()),MeanPairedDifference=float(g.ErrorDifference.mean()),MedianPairedDifference=float(g.ErrorDifference.median()),MedianErrorRatio=float(g.ErrorRatio.median()),MedianTimeRatio=float(g.TimeRatio.median()),WPositive=w,NonzeroPairs=n,PValue=pv))
stats=pd.DataFrame(stats);order=np.argsort(stats.PValue.to_numpy());adj=np.maximum.accumulate([(len(stats)-k)*stats.PValue.iloc[i] for k,i in enumerate(order)])
stats['HolmPValue']=0.0
for i,v in zip(order,adj):stats.loc[i,'HolmPValue']=min(1,float(v))
stats['HolmSignificant05']=stats.HolmPValue.le(.05)
stats.to_csv(out/'function_statistics.csv',index=False)
means=summary.pivot(index='FunctionID',columns='Condition',values='MeanError')
ratio=(means.SMP3.clip(lower=0)+1e-12)/(means.B10.clip(lower=0)+1e-12)
severe=ratio.gt(10)&means.SMP3.gt(1e-8)&means.B10.gt(1e-8)
fw=int((means.SMP3<means.B10).sum());fl=int((means.SMP3>means.B10).sum());ft=8-fw-fl
sw=int((m.ErrorDifference<0).sum());sl=int((m.ErrorDifference>0).sum());st=80-sw-sl
quality=fw+ft>=4 and sw+st>=40 and ratio.median()<=1.10 and not severe.any()
time_ratio=float(m.TimeRatio.median());speed=time_ratio<=.85
comparison=dict(Condition='SMP3',Budget=100000,FunctionWins=fw,FunctionLosses=fl,FunctionTies=ft,SeedWins=sw,SeedLosses=sl,SeedTies=st,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MedianPairedTimeRatio=time_ratio,MeanSMP3Seconds=float(s.Seconds.mean()),MeanB10Seconds=float(b.Seconds.mean()),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),QualityGate=bool(quality),TimeGate=bool(speed),ConfirmationGate=bool(quality and speed),HolmSignificantSMP3Wins=int((stats.HolmSignificant05 & (stats.MedianPairedDifference<0)).sum()),HolmSignificantB10Wins=int((stats.HolmSignificant05 & (stats.MedianPairedDifference>0)).sum()))
pd.DataFrame([comparison]).to_csv(out/'comparison.csv',index=False)
summary.groupby('Condition').MeanErrorRank.mean().reset_index().to_csv(out/'mean_ranks.csv',index=False)
old=pd.read_csv(root/'results/cso_simplify_20261012/comparisons.csv');old=old[(old.Condition=='SMP3')&(old.Budget==100000)].copy();old['Stage']='development_3seed';new=pd.DataFrame([comparison]);new['Stage']='confirmation_10seed';pd.concat([old,new],ignore_index=True).to_csv(out/'development_vs_confirmation.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
    if f.is_file():
        data=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),Bytes=len(data),SHA256=hashlib.sha256(data).hexdigest(),SHA256NormalizedLF=hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',root/'data/cec2017/D50_manifest.csv',Path(__file__),root/'experiments/verify_cso_smp3_confirmation.py']:
    sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),Bytes=f.stat().st_size,SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=160,ActualObjectiveCalls=int(raw.ObjectiveCalls.sum()),ExtraBestRechecks=160,IndependentSeeds=list(range(1201,1211)),Statistics='Exact conditional signed-rank sign-flips; zeros removed; midranks on ties; two-sided; Holm over eight functions; uncorrected/adjusted p published. Selection gate is separate from significance.',Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
smoke_dir=sorted(run.parent.glob('cso_smp3_smoke_*'))[-1];smoke=pd.read_csv(smoke_dir/'raw_runs.csv');assert len(smoke)==4 and smoke.Status.eq('ok').all();shutil.copy2(smoke_dir/'raw_runs.csv',out/'smoke_raw_runs.csv')
report=['# SMP3独立确认结果（2026-10-12）','',f'160次新run完成，D50/100k，八函数×十新seed×两骨架，共{int(raw.ObjectiveCalls.sum()):,}次预算内真实目标调用。另160次Best重查、四次smoke单列。所有独立MAT/CSV检查通过。','',f'SMP3对B10：函数均值{fw}胜/{fl}负/{ft}平，逐seed{sw}胜/{sl}负/{st}平；函数误差比中位数{ratio.median():.4g}，配对时间比中位数{time_ratio:.4f}。','',f"先写质量门：{'通过' if quality else '未通过'}；时间门：{'通过' if speed else '未通过'}；确认门：{'通过' if quality and speed else '未通过'}。",'',f"八函数Holm校正后0.05显著：SMP3优势{comparison['HolmSignificantSMP3Wins']}，B10优势{comparison['HolmSignificantB10Wins']}。未显著不证明等效；工程选择门与显著性分别解释。",'', '全部逐函数均值/方差/中位数及配对统计公开。三seed开发与十seed确认分别报告，不合并当独立确认。未新增Q、删精英、或调搜索参数。','', '过门仅允许作为下一阶段低预算骨架，尚非全29函数、D100或标准预算的正式结论。若未过门，B10保持锚点；效率收益可以报告，但不能把更快直接写成精度更好。']
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
print(pd.DataFrame([comparison]).to_string(index=False));print(stats.to_string(index=False));print('OUTPUT',out)
