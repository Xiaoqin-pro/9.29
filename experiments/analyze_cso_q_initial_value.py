"""One return-bound Q initialization candidate with unchanged cached controls."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/cso_q_learning_20261012'
assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');checks=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==40 and new.Status.eq('ok').all() and checks['RunsChecked']==40 and checks['AllCompleted'] and checks['Passed']
old=pd.read_csv(root/'results/cso_mode_efficiency_20261012/raw_runs.csv');old['Origin']='cached-efficiency';new['Origin']='new-initialization';raw=pd.concat([old,new],ignore_index=True);assert len(raw)==480 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
assert set(new.InitialQ)=={-10} and set(new.Seed)==set(range(1801,1806)) and set(new.Budget)=={100000} and set(new.Dimension)=={50}
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/cso_q_learning_20261012/initial_value_checks.json',out/'initial_value_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),PositiveBlocks=('PositiveRewardBlocks','mean'),Action1Share=('Action1Share','mean'),Action2Share=('Action2Share','mean'),Action3Share=('Action3Share','mean')).reset_index();assert s.Runs.eq(5).all()
s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_means.csv')
candidate='LowerInit-effQ';q=raw[raw.Condition==candidate];best_fixed=ranks[['fixed2','fixed4','fixed6']].idxmin();comparisons=[];pairs=[]
for control in sorted(set(raw.Condition)-{candidate}):
 m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_candidate','_control'),validate='one_to_one');assert len(m)==40;m['Control']=control;pairs.append(m)
 fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.FinalError_candidate<m.FinalError_control).sum());sl=int((m.FinalError_candidate>m.FinalError_control).sum());ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8)
 gate=8-fl>=4 and 40-sl>=20 and ranks[candidate]<ranks[control] and not severe.any()
 comparisons.append(dict(Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(gate)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
required=[best_fixed,'random','phase','epsfixed','effrule'];passed=bool(c[c.Control.isin(required)].ControlGate.all());result=dict(Candidate=candidate,InitialQ=-10,RequiredControls=required,GatePassed=passed,NewRuns=40,NewObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=440,Scope='same-seed single-factor development; not independent confirmation')
(out/'selection_gate.json').write_text(json.dumps(result,indent=2),encoding='utf-8');raw.groupby('Condition')[['PositiveRewardBlocks','Action1Share','Action2Share','Action3Share']].mean().to_csv(out/'policy_diagnostics.csv')
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/cso_mode_efficiency_20261012/raw_runs.csv',Path(__file__),root/'experiments/verify_cso_q_initial_value.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),CachedSource='results/cso_mode_efficiency_20261012/raw_runs.csv',Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('cso_q_initial_value_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==2 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 统一Q初值单因素结果（2026-10-12）','', '40新优化完成，D50/100k、八函数×五原开发seed；4M真实FE、40Best重查与两smoke单列。原十一组440控制缓存质量同格复用，不算新增独立证据。仅Q初值统一从0到−10，其余公式/状态/动作/reward/alpha/gamma/epsilon未改。','',f'十二条件平均排名：{ranks.to_dict()}。',f'预写五强对照门：{"通过" if passed else "未通过"}。','']
for row in comparisons:report.append(f"- LowerInit对{row['Control']}：函数{row['FunctionWins']}:{row['FunctionLosses']}，seed{row['SeedWins']}:{row['SeedLosses']}，误差比中位数{row['MedianFunctionErrorRatio']:.4g}，对照门{'通过' if row['ControlGate'] else '未通过'}。")
report.extend(['','原40Q日志40000决策精确RNG重放：exploration~9.94%，greedy状态重访换动作~63.8%，上次负reward后~75.7%；零未访optimistic每run仅~7次，不能把全部轮换归零初始化。减少换动作不是成功标准，真实质量与同信号规则必须比较。','', '未过门不扫更多init，过门才独立新seed確認；全部不利条件公开，五seed开发不是显著/非劣或论文最终结论。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(result,indent=2))
