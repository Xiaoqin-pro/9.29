"""One held-action interval change against duration-matched controls and cached original versions."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_episode_20261012'
assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==200 and new.Status.eq('ok').all() and ck['RunsChecked']==200 and ck['Passed'] and ck['AllCompleted']
old=pd.read_csv(root/'results/quota_q_gap_20261012/all_quality_runs.csv');assert len(old)==280
old['Condition']=old.Condition.replace({x:'100-'+x for x in ['gateq','gaterandom','gate2','gate4','gateeps6']});new['Condition']='500-'+new.Condition;old['Origin']='cached-old';new['Origin']='new-held';raw=pd.concat([old,new],ignore_index=True);assert len(raw)==480 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
assert set(new.Seed)==set(range(2201,2206)) and set(new.Budget)=={100000} and set(new.Dimension)=={50} and set(new.EpisodeFE)=={500}
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_episode_20261012/behavior_checks.json',out/'behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),MeanError20FE=('Error20FE','mean'),MeanError60FE=('Error60FE','mean'),MeanError80FE=('Error80FE','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_mean_errors.csv')
candidate='500-gateq';q=raw[raw.Condition==candidate];comparisons=[];pairs=[]
for control in sorted(set(raw.Condition)-{candidate}):
 m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40;m['Control']=control;pairs.append(m)
 fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum());ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8)
 passed=8-fl>=4 and 40-sl>=20 and ranks[candidate]<ranks[control] and not severe.any()
 comparisons.append(dict(Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),ControlGate=bool(passed)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False);required=['fixed6','alwaysQ','100-gateq','500-gaterandom','500-gate2','500-gate4','500-gateeps6'];passed=bool(c[c.Control.isin(required)].ControlGate.all())
result=dict(NewRuns=200,NewObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=280,RequiredControls=required,GatePassed=passed,Scope='same-seed held-action duration development; current Q is not assumed fixed')
(out/'selection_gate.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
new.groupby('Condition')[['Decisions','FreeDecisions','ForcedFixed6Decisions','QUpdates','PositiveRewardBlocks']].mean().to_csv(out/'episode_policy_diagnostics.csv')
# Action shares must be weighted by actual interval FE, not decision counts.
policy=[]
for row in new.itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['DecisionLog']);G=np.asarray(d['I']['GateLog']);duration=L[:,1]-L[:,0]
 z=dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FreeFERate=float(duration[G[:,1]==1].sum()/duration.sum()),FreePositiveRate=float((L[G[:,1]==1,9]>0).mean()) if G[:,1].any() else np.nan,MeanFreeDuration=float(duration[G[:,1]==1].mean()) if G[:,1].any() else np.nan)
 for ac in [1,2,3]:z['Action'+str(ac)+'FEShare']=float(duration[L[:,3]==ac].sum()/duration.sum())
 policy.append(z)
pd.DataFrame(policy).to_csv(out/'episode_fe_weighted_policy.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/quota_q_gap_20261012/all_quality_runs.csv',Path(__file__),root/'experiments/verify_quota_q_episode.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),CachedRowsAreNotNew=True,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('quota_q_episode_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==10 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 停滞Q动作保持500FE结果（2026-10-12）','', '200新run/20MFE，D50/100k八函数五原seed，原280quality缓存不重复计新；200Bestrecheck/10smoke单列。100FE兼容、holding duration/discount/actualstate/action/terminal与真实FE全部独立核验。','',f'十二条件平均排名：{ranks.to_dict()}。',f'预写强对照联合门：{"通过" if passed else "未通过"}。','']
for row in comparisons:report.append(f"- 500FE-Q vs {row['Control']}：函数{row['FunctionWins']}:{row['FunctionLosses']}，seed{row['SeedWins']}:{row['SeedLosses']}，误差比中位数{row['MedianFunctionErrorRatio']:.4g}，对照门{'通过' if row['ControlGate'] else '未通过'}。")
report.extend(['','只改free attempt保持时长，bootstrap按实际FE的gamma^(duration/100)，healthyFixed6，reward±1和所有搜索公式不变。相同holding提供给Random/规则，不能把holding收益自动归Q。','', '同seed开发非独立确认，五seed票数非显著/非劣。过门才新seed完整集确认，未过不扫更多holding时长或同时改reward/state。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(pd.DataFrame(comparisons).to_string(index=False));print(ranks.to_string());print(json.dumps(result,indent=2))
