"""Controlled evaluation of one small Q mechanism against strong simple controls."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np
import pandas as pd
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--output',type=Path,default=root/'results/cso_mode_q_20261012');a=p.parse_args();run=a.run_dir.resolve();out=a.output.resolve()
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');checks=json.loads((run/'independent_artifact_checks.json').read_text())
assert len(raw)==280 and raw.Status.eq('ok').all() and checks['RunsChecked']==280 and checks['AllCompleted'] and checks['Passed']
conditions={'fixed2','fixed4','fixed6','random','phase','epsfixed','q'}
assert set(raw.Condition)==conditions and set(raw.Seed)==set(range(1401,1406)) and set(raw.Budget)=={100000} and set(raw.Dimension)=={50}
assert raw.ObjectiveCalls.eq(raw.Budget).all() and raw.Evaluations.eq(raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
assert not raw.duplicated(['FunctionID','Seed','Condition']).any()
out.mkdir(parents=True,exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/cso_mode_q_20261012/behavior_checks.json',out/'behavior_checks.json')
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),Error20FE=('Error20FE','mean'),Error60FE=('Error60FE','mean'),Error80FE=('Error80FE','mean'),MeanPositiveBlocks=('PositiveRewardBlocks','mean'),MeanAction1Share=('Action1Share','mean'),MeanAction2Share=('Action2Share','mean'),MeanAction3Share=('Action3Share','mean')).reset_index();assert s.Runs.eq(5).all()
s['MeanErrorRank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False)
ranks=s.groupby('Condition').MeanErrorRank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_means.csv')
q=raw[raw.Condition=='q'];comparisons=[];paired=[]
for control in sorted(conditions-{'q'}):
    m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40
    m['Control']=control;m['ErrorRatio']=(m.FinalError_q.clip(lower=0)+1e-12)/(m.FinalError_control.clip(lower=0)+1e-12);m['TimeRatio']=m.Seconds_q/m.Seconds_control;paired.append(m)
    fw=int((means.q<means[control]).sum());fl=int((means.q>means[control]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum())
    ratio=(means.q.clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means.q.gt(1e-8)&means[control].gt(1e-8)
    passed=fw+(8-fw-fl)>=4 and sw+(40-sw-sl)>=20 and ranks.q<ranks[control] and not severe.any()
    comparisons.append(dict(Control=control,QFunctionWins=fw,ControlFunctionWins=fl,FunctionTies=8-fw-fl,QSeedWins=sw,ControlSeedWins=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MedianPairedTimeRatio=float(m.TimeRatio.median()),QMeanRank=float(ranks.q),ControlMeanRank=float(ranks[control]),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(passed)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(paired,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
required=c[c.Control.isin(['fixed6','random','phase','epsfixed'])];passed=bool(required.ControlGate.all());gate=dict(RequiredControls=['fixed6','random','phase','epsfixed'],QPassesDevelopmentGate=passed,NewRuns=280,ActualObjectiveCalls=int(raw.ObjectiveCalls.sum()),Scope='five-seed development; gate is not significance/noninferiority; no parameter sweep or new-seed confirmation automatically triggered')
(out/'selection_gate.json').write_text(json.dumps(gate,indent=2),encoding='utf-8')
raw.groupby('Condition')[['Seconds','Decisions','QUpdates','PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QuotaFallbackRounds']].mean().to_csv(out/'policy_diagnostics.csv')
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
    if f.is_file():
        b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',Path(__file__),root/'experiments/verify_cso_mode_q.py']:
    sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=280,ExtraBestRechecks=280,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
smoke_dir=sorted(run.parent.glob('cso_mode_q_smoke_*'))[-1];smoke=pd.read_csv(smoke_dir/'raw_runs.csv');assert len(smoke)==14 and smoke.Status.eq('ok').all();shutil.copy2(smoke_dir/'raw_runs.csv',out/'smoke_raw_runs.csv')
report=['# B10真实模式配额小Q开发结果（2026-10-12）','', '280次新run完成，D50/100k，八函数×五新seed×七条件；28M真实FE、280Best重查、14smoke分开列。完整轨迹和状态/动作/奖励/Q转移及终端更新独立核验通过。','',f'函数均值平均排名：{ranks.to_dict()}。','',f'预写四强对照开发门：{"通过" if passed else "未通过"}。','']
for row in comparisons:report.append(f"- Q vs {row['Control']}：函数{row['QFunctionWins']}:{row['ControlFunctionWins']}，seed{row['QSeedWins']}:{row['ControlSeedWins']}，函数误差比中位数{row['MedianFunctionErrorRatio']:.4g}，门{'通过' if row['ControlGate'] else '未通过'}。")
report.extend(['','平均排名与均值胜场不是显著性；五seed开发不保证论文结论。全三固定策略、Random、Phase、EpsFixed均报告，不按结果挑弱基线。','', '若未过门：停止扩大alpha/gamma/reward网格；先解释为何观测奖励未支撑调度优势。若过门：允许独立新seed确认，正式标准预算/维度扩展尚未验收。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(gate,indent=2));print('OUTPUT',out)
