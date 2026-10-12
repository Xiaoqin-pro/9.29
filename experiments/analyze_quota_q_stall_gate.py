"""Check whether stall-only Q intervention preserves Fixed6 and adds learned value."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_gap_20261012'
assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');check=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==200 and new.Status.eq('ok').all() and check['RunsChecked']==200 and check['AllCompleted'] and check['Passed']
funcs={1,3,6,9,12,13,22,30};assert set(new.FunctionID)==funcs and set(new.Seed)==set(range(2201,2206)) and set(new.Condition)=={'gateq','gaterandom','gate2','gate4','gateeps6'}
fixed=pd.read_csv(root/'results/clpso_full_100k_20261012/raw_runs.csv');fixed=fixed[fixed.Condition.eq('CSO-Fixed6')&fixed.FunctionID.isin(funcs)].copy();oldq=pd.read_csv(root/'results/quota_q_full_100k_20261012/raw_runs.csv');oldq=oldq[oldq.FunctionID.isin(funcs)].copy();oldq['Condition']='alwaysQ';fixed['Condition']='fixed6'
fixed['Origin']='cached-Fixed6';oldq['Origin']='cached-originalQ';new['Origin']='new-gated';raw=pd.concat([fixed,oldq,new],ignore_index=True);assert len(raw)==280 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
# Confirm cached population equality, not merely seed metadata.
cached_dirs={'fixed6':root/'results/cec/clpso_full_100k_study_20261012_193032','alwaysQ':root/'results/cec/quota_q_full_100k_study_20261012_194957'}
for row in new[new.Condition=='gateq'].itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True)
 for control in ['fixed6','alwaysQ']:
  z=raw[(raw.Condition==control)&(raw.FunctionID==row.FunctionID)&(raw.Seed==row.Seed)].iloc[0];assert z.InitSeed==row.InitSeed and z.SearchSeed==row.SearchSeed
  c=loadmat(cached_dirs[control]/'runs'/f'job_{int(z.JobID):04d}.mat',simplify_cells=True);assert np.array_equal(c['p0'],d['p0'])
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_gap_20261012/gate_behavior_checks.json',out/'gate_behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_mean_errors.csv')
q=raw[raw.Condition=='gateq'];comparisons=[];pairs=[]
for control in ['fixed6','alwaysQ','gaterandom','gate2','gate4','gateeps6']:
 m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40;m['Control']=control;pairs.append(m)
 fw=int((means.gateq<means[control]).sum());fl=int((means.gateq>means[control]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum());ratio=(means.gateq.clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means.gateq.gt(1e-8)&means[control].gt(1e-8)
 passed=8-fl>=4 and 40-sl>=20 and ranks.gateq<ranks[control] and not severe.any()
 comparisons.append(dict(Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks.gateq),ControlRank=float(ranks[control]),ControlGate=bool(passed)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
result=dict(NewRuns=200,ObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=80,GatePassesAllControls=bool(c.ControlGate.all()),Scope='same-seed eight-function one-intervention development; not new-seed confirmation')
(out/'selection_gate.json').write_text(json.dumps(result,indent=2),encoding='utf-8');new.groupby('Condition')[['FreeDecisions','ForcedFixed6Decisions','PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QUpdates']].mean().to_csv(out/'gate_policy_diagnostics.csv')
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/clpso_full_100k_20261012/raw_runs.csv',root/'results/quota_q_full_100k_20261012/raw_runs.csv',Path(__file__),root/'experiments/verify_quota_q_stall_gate.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),CachedRowsAreNotNewRuns=True,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('quota_q_stall_gate_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==10 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 正常固定6、停滞才介入Q的开发结果（2026-10-12）','', '200新run/20M真实FE，D50/100k八函数五原完整集seed。80Fixed6/alwaysQ同格质量缓存、200Bestrecheck和10smoke单列。默认原版回归及forced/free/真实state/action/reward/nextstate/terminal重放通过，80cachedp0实际一致。','',f'七条件平均排名：{ranks.to_dict()}。',f'预写全部强控制联合门：{"通过" if result["GatePassesAllControls"] else "未通过"}。','']
for c in comparisons:report.append(f"- gateQ vs {c['Control']}：函数{c['FunctionWins']}:{c['FunctionLosses']}，seed{c['SeedWins']}:{c['SeedLosses']}，误差比中位数{c['MedianFunctionErrorRatio']:.4g}，该控制门{'通过' if c['ControlGate'] else '未通过'}。")
report.extend(['','Q表/奖励/动作/搜索方程不变，只将learning触发集中于真实停滞，healthy强制Fixed6。固定fallback是已开发先验，若random/rule同样好，不能把gate作用当学习贡献。','', '五seed开发非显著/非劣，未按失败改变门或删除函数。过门才新seed完整29确认；未过不扫stallthreshold或增加机制。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(pd.DataFrame(comparisons).to_string(index=False));print(ranks.to_string());print(json.dumps(result,indent=2))
