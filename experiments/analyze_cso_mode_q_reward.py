"""Analyze two reward changes against the unchanged cached seven controls."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np
import pandas as pd
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/cso_mode_q_reward_20261012'
assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');check=json.loads((run/'independent_artifact_checks.json').read_text())
assert len(new)==80 and new.Status.eq('ok').all() and check['RunsChecked']==80 and check['AllCompleted'] and check['Passed']
old=pd.read_csv(root/'results/cso_mode_q_20261012/raw_runs.csv');old['Condition']=old.Condition.replace({'q':'binaryQ'});old['Origin']='cached-original';new['Origin']='new-reward';raw=pd.concat([old,new],ignore_index=True)
assert len(raw)==360 and not raw.duplicated(['FunctionID','Seed','Condition']).any() and set(new.Seed)==set(range(1401,1406)) and set(new.Condition)=={'positive','gain'}
out.mkdir(parents=True,exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/cso_mode_q_reward_20261012/behavior_checks.json',out/'behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),MeanPositiveBlocks=('PositiveRewardBlocks','mean'),Action1Share=('Action1Share','mean'),Action2Share=('Action2Share','mean'),Action3Share=('Action3Share','mean')).reset_index();assert s.Runs.eq(5).all()
s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_means.csv')
comparisons=[];paired=[];gates=[]
for candidate in ['positive','gain']:
    q=raw[raw.Condition==candidate]
    for control in ['fixed2','fixed4','fixed6','random','phase','epsfixed','binaryQ']:
        m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_candidate','_control'),validate='one_to_one');assert len(m)==40;m['Candidate']=candidate;m['Control']=control;paired.append(m)
        fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.FinalError_candidate<m.FinalError_control).sum());sl=int((m.FinalError_candidate>m.FinalError_control).sum())
        ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8)
        passed=fw+8-fw-fl>=4 and sw+40-sw-sl>=20 and ranks[candidate]<ranks[control] and not severe.any()
        comparisons.append(dict(Candidate=candidate,Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),ControlGate=bool(passed)))
    required=[x for x in comparisons if x['Candidate']==candidate and x['Control'] in ['fixed6','random','phase','epsfixed']];gates.append(dict(Candidate=candidate,GatePassed=all(x['ControlGate'] for x in required),Rank=float(ranks[candidate])))
pd.DataFrame(comparisons).to_csv(out/'comparisons.csv',index=False);pd.concat(paired,ignore_index=True).to_csv(out/'paired_runs.csv',index=False);pd.DataFrame(gates).to_csv(out/'selection_gate.csv',index=False)
raw.groupby('Condition')[['PositiveRewardBlocks','Action1Share','Action2Share','Action3Share']].mean().to_csv(out/'policy_diagnostics.csv')
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
    if f.is_file():
        b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=80,NewObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=280,CachedSource='results/cso_mode_q_20261012/raw_runs.csv',Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
smoke_dir=sorted(run.parent.glob('cso_mode_q_reward_smoke_*'))[-1];smoke=pd.read_csv(smoke_dir/'raw_runs.csv');assert len(smoke)==4 and smoke.Status.eq('ok').all();shutil.copy2(smoke_dir/'raw_runs.csv',out/'smoke_raw_runs.csv')
report=['# 模式Q单因素奖励开发（2026-10-12）','', '80次新优化完成，D50/100k，两奖励×八函数×五原开发seed；8M真实调用，80Best重查，四smoke单列。原七组280质量记录缓存复用，不算本轮新增或独立确认。','', f'九条件平均排名：{ranks.to_dict()}。','']
for g in gates:report.append(f"- {g['Candidate']} 强四对照联合门：{'通过' if g['GatePassed'] else '未通过'}。")
report.extend(['','状态/动作/搜索公式未改；仅奖励不同。真实fitness范围归一化不读取CEC最优值。多样性仅记录，不给指定动作虚构成功奖励。完整轨迹、Q重放与奖励锚点检查通过。','', '过门才开展独立新seed强对照确认；未过门不扩大倍率和学习率网格。前述种群与停滞趋势为诊断，不是因果证明。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(pd.DataFrame(comparisons).to_string(index=False));print(ranks.to_string());print(pd.DataFrame(gates).to_string(index=False))
