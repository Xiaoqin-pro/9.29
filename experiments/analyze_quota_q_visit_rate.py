"""Last bounded update-estimator test; all prior matched controls retained."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_visit_rate_20261012';assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==40 and new.Status.eq('ok').all() and ck['RunsChecked']==40 and ck['AllCompleted'] and ck['Passed']
old=pd.read_csv(root/'results/quota_q_episode_bonus_20261012/all_quality_runs.csv');assert len(old)==560;new['Origin']='new-visit-rate';old['Origin']='cached-controls';raw=pd.concat([old,new],ignore_index=True);assert len(raw)==600 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_visit_rate_20261012/behavior_checks.json',out/'behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_mean_errors.csv')
candidate='VisitRate-Bonus10-100';q=raw[raw.Condition==candidate];comparisons=[];pairs=[]
for control in sorted(set(raw.Condition)-{candidate}):
 m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40;m['Control']=control;pairs.append(m)
 fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum());ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8);passed=8-fl>=4 and 40-sl>=20 and ranks[candidate]<ranks[control] and not severe.any()
 comparisons.append(dict(Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),ControlGate=bool(passed)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False);required=['fixed6','alwaysQ','100-gateq','Bonus10-100','100-gaterandom','100-gate2','100-gate4','100-gateeps6','500-gaterandom'];passed=bool(c[c.Control.isin(required)].ControlGate.all())
result=dict(NewRuns=40,NewObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=560,RequiredControls=required,GatePassed=passed,Scope='same-seed visit-dependent update development, no independent confirmation yet')
(out/'selection_gate.json').write_text(json.dumps(result,indent=2),encoding='utf-8');sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/quota_q_episode_bonus_20261012/all_quality_runs.csv',Path(__file__),root/'experiments/verify_quota_q_visit_rate.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8');sm=sorted(run.parent.glob('quota_q_visit_rate_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==2 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 停滞Q按访问次数学习率结果（2026-10-12）','', '40新run/4MFE，原560质量cached不算新；40Best重查与2smoke单列。仅同Bonus10-100 setting的α由.1改为1/eligibleVisits，Qstate/table/action/reward/bone不变。','',f'十五条件rank：{ranks.to_dict()}。',f'预写联合强控制门：{"通过" if passed else "未通过"}。','', '所有actual RateLog按eligible visits独立重算并重放Q/terminal，默认fixedbranch逐点回归。门未过本轮停止，不继续reward/window/radius网格；报告修正局部收益但不称Q已修好。五seed是same-seed开发，非significance/noninferiority。']
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(result,indent=2))
