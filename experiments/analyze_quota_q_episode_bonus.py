"""A single positive reward multiplier in two separately controlled action-duration settings."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_episode_bonus_20261012';assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==80 and new.Status.eq('ok').all() and ck['RunsChecked']==80 and ck['AllCompleted'] and ck['Passed']
old=pd.read_csv(root/'results/quota_q_episode_20261012/all_quality_runs.csv');assert len(old)==480;old['Origin']='cached-duration-controls';new['Origin']='new-bonus10';raw=pd.concat([old,new],ignore_index=True);assert len(raw)==560 and not raw.duplicated(['FunctionID','Seed','Condition']).any() and set(new.RewardBonus)=={10} and set(new.EpisodeFE)=={100,500}
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_episode_bonus_20261012/behavior_checks.json',out/'behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_mean_errors.csv')
comparisons=[];pairs=[];gates=[]
for duration in [100,500]:
 candidate='Bonus10-'+str(duration);q=raw[raw.Condition==candidate];required=['fixed6','alwaysQ',str(duration)+'-gateq',str(duration)+'-gaterandom',str(duration)+'-gate2',str(duration)+'-gate4',str(duration)+'-gateeps6']
 for control in required:
  m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40;m['Candidate']=candidate;m['Control']=control;pairs.append(m)
  fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum());ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8)
  passed=8-fl>=4 and 40-sl>=20 and ranks[candidate]<ranks[control] and not severe.any();comparisons.append(dict(Candidate=candidate,Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),ControlGate=bool(passed)))
 subset=[x for x in comparisons if x['Candidate']==candidate];gates.append(dict(Candidate=candidate,GatePassed=all(x['ControlGate'] for x in subset),Rank=float(ranks[candidate])))
pd.DataFrame(comparisons).to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False);pd.DataFrame(gates).to_csv(out/'selection_gate.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/quota_q_episode_20261012/all_quality_runs.csv',Path(__file__),root/'experiments/verify_quota_q_episode_bonus.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=80,NewObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=480,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8');sm=sorted(run.parent.glob('quota_q_episode_bonus_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==4 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 停滞Q真实改善奖励倍率单因素结果（2026-10-12）','', '80新run/8MFE，原480duration/control质量缓存不算新；80Bestrecheck、四smoke单列。只将两种原窗口设置各自reward+1改+10（失败−1），其余方法和window不同时改变。','',f'十四条件rank：{ranks.to_dict()}。','']
for g in gates:report.append(f"- {g['Candidate']}强对照门：{'通过' if g['GatePassed'] else '未通过'}，rank{g['Rank']:.3f}。")
report.extend(['','100/500两个候选各对应自己固定窗口全控制；不是先从两candidate择优再同一弱control比。五seed同格development非独立证据，不用倍率变化当成功。未过不扫更多奖励倍率，所有不利结果公开。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(pd.DataFrame(comparisons).to_string(index=False));print(ranks.to_string());print(pd.DataFrame(gates).to_string(index=False))
