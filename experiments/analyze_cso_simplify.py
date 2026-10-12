"""Analyze the completed single-deletion study; never fills missing results."""
from pathlib import Path
import argparse, hashlib, json, shutil
import numpy as np
import pandas as pd

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('run_dir', type=Path)
parser.add_argument('--output', type=Path, default=root/'results/cso_simplify_20261012')
args = parser.parse_args()
run_dir = args.run_dir.resolve()
assert (run_dir/'COMPLETED.json').exists(), 'Batch not complete.'
raw = pd.read_csv(run_dir/'raw_runs.csv')
manifest = pd.read_csv(run_dir/'job_manifest.csv')
assert len(raw)==len(manifest)==144 and raw.Status.eq('ok').all()
keys=['FunctionID','Seed','Budget','Condition']
assert not raw.duplicated(keys).any()
assert set(raw.Dimension)=={50} and set(raw.Budget)=={100000,500000}
assert set(raw.Seed)=={1101,1102,1103}
assert raw.ObjectiveCalls.eq(raw.Budget).all() and raw.Evaluations.eq(raw.Budget).all()
assert raw.PostRunRecheckCalls.eq(1).all() and raw.OutsideCalls.eq(0).all()
assert (raw.TracingEvaluations+raw.SeekingEvaluations).eq(raw.Budget-50).all()
assert raw.TraceFinite.all() and raw.TraceMonotone.all() and raw.MaxParentEvaluations.le(2).all()
assert np.allclose(raw.FinalCost-100*raw.FunctionID,raw.FinalError,rtol=0,atol=1e-8)
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
shutil.copy2(run_dir/'raw_runs.csv',out/'raw_runs.csv')
shutil.copy2(run_dir/'job_manifest.csv',out/'job_manifest.csv')
shutil.copy2(run_dir/'environment.json',out/'environment.json')
shutil.copy2(root/'work/cso_simplify_20261012/behavior_checks.json',out/'behavior_checks.json')
summary=raw.groupby(['Budget','FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean'),MeanSeekingCoverage=('MeanSeekCoverage','mean'),TraceGlobalSuccesses=('TraceGlobalSuccesses','mean'),SeekGlobalSuccesses=('SeekGlobalSuccesses','mean')).reset_index()
summary['MeanErrorRank']=summary.groupby(['Budget','FunctionID']).MeanError.rank(method='average')
summary.to_csv(out/'summary.csv',index=False)
base=raw[raw.Condition=='B10']
paired=[];comparisons=[];gates=[]
for condition in ['SMP3','NoSeekingElite']:
    cand=raw[raw.Condition==condition]
    m=cand.merge(base,on=['Budget','FunctionID','Seed','Dimension','InitSeed','SearchSeed'],suffixes=('_candidate','_b10'),validate='one_to_one')
    assert len(m)==48
    m['ErrorRatio']=(m.FinalError_candidate.clip(lower=0)+1e-12)/(m.FinalError_b10.clip(lower=0)+1e-12)
    m['TimeRatio']=m.Seconds_candidate/m.Seconds_b10
    paired.append(m)
    for budget,g in m.groupby('Budget'):
        means=summary[(summary.Budget==budget)&(summary.Condition.isin([condition,'B10']))].pivot(index='FunctionID',columns='Condition',values='MeanError')
        ratio=(means[condition].clip(lower=0)+1e-12)/(means.B10.clip(lower=0)+1e-12)
        near=(means[condition]<=1e-8)&(means.B10<=1e-8)
        severe=ratio.gt(10)&~near
        fw=int((means[condition]<means.B10).sum());fl=int((means[condition]>means.B10).sum());ft=8-fw-fl
        sw=int((g.FinalError_candidate<g.FinalError_b10).sum());sl=int((g.FinalError_candidate>g.FinalError_b10).sum());st=len(g)-sw-sl
        median_ratio=float(ratio.median());time_ratio=float(g.TimeRatio.median())
        quality=fw+ft>=4 and sw+st>=12 and median_ratio<=1.10 and not severe.any()
        speed=time_ratio<=.85 if condition=='SMP3' else True
        row=dict(Condition=condition,Budget=int(budget),FunctionWins=fw,FunctionLosses=fl,FunctionTies=ft,SeedWins=sw,SeedLosses=sl,SeedTies=st,MedianFunctionErrorRatio=median_ratio,GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MedianPairedTimeRatio=time_ratio,MeanCandidateSeconds=float(g.Seconds_candidate.mean()),MeanB10Seconds=float(g.Seconds_b10.mean()),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),QualityGate=bool(quality),SimplificationTimeGate=bool(speed),BudgetGate=bool(quality and speed))
        comparisons.append(row)
    selected=[r for r in comparisons if r['Condition']==condition]
    gates.append(dict(Condition=condition,BothBudgetGate=all(r['BudgetGate'] for r in selected),Evidence='development only; three seeds; not a noninferiority or significance test'))
pd.concat(paired,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
pd.DataFrame(comparisons).to_csv(out/'comparisons.csv',index=False)
pd.DataFrame(gates).to_csv(out/'selection_gate.csv',index=False)
summary.groupby(['Budget','Condition']).MeanErrorRank.mean().reset_index().to_csv(out/'mean_ranks.csv',index=False)
sources=[]
for p in sorted((run_dir/'source_snapshot').rglob('*')):
    if p.is_file():
        b=p.read_bytes();sources.append(dict(Path=str(p.relative_to(run_dir/'source_snapshot')).replace('\\','/'),Bytes=len(b),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for p in [root/'data/cec2017/cec17_func.mexw64',root/'data/cec2017/D50_manifest.csv',Path(__file__).resolve()]:
    sources.append(dict(Path=str(p.relative_to(root)).replace('\\','/'),Bytes=p.stat().st_size,SHA256=hashlib.sha256(p.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run_dir),NewOptimizationRuns=144,SmokeRuns=6,ActualObjectiveCalls=int(raw.ObjectiveCalls.sum()),ExtraBestRechecks=int(raw.PostRunRecheckCalls.sum()),ZeroErrorClipping='Only ratios use max(error,0)+1e-12. Raw costs/errors unchanged.',Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
report=['# CSO骨架删减结果（2026-10-12）','',f'144次新开发run完成，D50，100k/500k，八函数，每格三个新seed。独立真实调用共{int(raw.ObjectiveCalls.sum()):,}次，另有144次Best重查；smoke六次单列。未发生域外或预算错误。','', '以下为函数均值和配对seed胜负，不是统计显著性或正式非劣结论。','']
for r in comparisons:
    report.append(f"- {r['Condition']} / {r['Budget']}FE：函数{r['FunctionWins']}胜/{r['FunctionLosses']}负/{r['FunctionTies']}平，seed{r['SeedWins']}胜/{r['SeedLosses']}负/{r['SeedTies']}平；函数误差比中位数{r['MedianFunctionErrorRatio']:.4g}；配对时间比中位数{r['MedianPairedTimeRatio']:.4f}；严重退化函数{r['SevereRegressionFunctions'] or '无'}；该预算开发门{'通过' if r['BudgetGate'] else '未通过'}。")
report.extend(['','## 按预写协议的选择',''])
for g in gates:report.append(f"- {g['Condition']} 两预算门：{'通过' if g['BothBudgetGate'] else '未通过'}。")
report.extend(['','三seed不用于证明等效或宣称效果稳定；过门只表示可进入独立确认/后续配额实验。候选数变动也改变随机数消耗与后续模式抽样。NoSeekingElite只删一个公式并保留原来的随机抽样。完整所有条件均公开，未按结果删除函数或seed。','', '源快照、完整T/轮级反馈/初始种群保存在本地RunDirectory；公开raw、summary、paired_runs、门限判断与哈希。审计开关预检通过；计时不包含保存MAT和额外Best重查。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
print(pd.DataFrame(comparisons).to_string(index=False))
print(pd.DataFrame(gates).to_string(index=False))
print('OUTPUT',out)
