"""Effective 3x2 Q, matched two-action controls and preserved prior candidates."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_compact_20261012';assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==160 and new.Status.eq('ok').all() and ck['RunsChecked']==160 and ck['AllCompleted'] and ck['Passed']
old=pd.read_csv(root/'results/quota_q_simplicity_20261012/all_quality_runs.csv');assert len(old)==320;old['Origin']='cached-deletion-controls';new['Origin']='new-compact';raw=pd.concat([old,new],ignore_index=True);assert len(raw)==480 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
out.mkdir(exist_ok=True)
cache_dirs={'Fixed6':root/'results/cec/clpso_full_100k_study_20261012_193032','Original-Q6-Bonus1':root/'results/cec/quota_q_full_100k_study_20261012_194957','Gated-Q6-Bonus10':root/'results/cec/quota_q_episode_bonus_study_20261012_213013'}
actual_matches=0
for row in new[new.Condition=='Compact-Q'].itertuples():
 data=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True)
 for method,folder in cache_dirs.items():
  z=old[(old.Condition==method)&(old.FunctionID==row.FunctionID)&(old.Seed==row.Seed)].iloc[0]
  assert z.InitSeed==row.InitSeed and z.SearchSeed==row.SearchSeed
  cached=loadmat(folder/'runs'/f'job_{int(z.JobID):04d}.mat',simplify_cells=True);assert np.array_equal(data['p0'],cached['p0']);actual_matches+=1
(out/'cached_p0_checks.json').write_text(json.dumps(dict(ActualCachedP0Matches=actual_matches,Passed=True),indent=2),encoding='utf-8')
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_compact_20261012/behavior_checks.json',out/'behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_mean_errors.csv')
candidate='Compact-Q';q=raw[raw.Condition==candidate];comp=[];pairs=[]
for ctl in sorted(set(raw.Condition)-{candidate}):
 m=q.merge(raw[raw.Condition==ctl],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40;m['Control']=ctl;pairs.append(m)
 fw=int((means[candidate]<means[ctl]).sum());fl=int((means[candidate]>means[ctl]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum());ratio=(means[candidate].clip(lower=0)+1e-12)/(means[ctl].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[ctl].gt(1e-8)
 passed=8-fl>=4 and 40-sl>=20 and ranks[candidate]<ranks[ctl] and not severe.any()
 comp.append(dict(Control=ctl,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[ctl]),SevereFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(passed)))
c=pd.DataFrame(comp);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False);required=['Fixed6','Compact-Random','Compact-Eps6','Compact-Rule4'];passed=bool(c[c.Control.isin(required)].ControlGate.all())
result=dict(Candidate='Compact-Q',EffectiveQShape=[3,2],NewRuns=160,ActualObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=320,GatePassed=passed,Scope='same-seed two-deletion development; not independent confirmation')
(out/'selection_gate.json').write_text(json.dumps(result,indent=2),encoding='utf-8');new.groupby('Condition')[['PositiveRewardBlocks','QUpdates']].mean().to_csv(out/'policy_diagnostics.csv')
policy=[]
for r in new.itertuples():
 d=loadmat(run/'runs'/f'job_{r.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['DecisionLog']);G=np.asarray(d['I']['GateLog']);free=G[:,1]==1
 policy.append(dict(FunctionID=r.FunctionID,Seed=r.Seed,Condition=r.Condition,FourTraceShare=float((L[:,4]==4).mean()),SixTraceShare=float((L[:,4]==6).mean()),FreeRate=float(free.mean()),FreeFourTraceShare=float((L[free,4]==4).mean()) if free.any() else np.nan,FreePositiveRate=float((L[free,9]>0).mean()) if free.any() else np.nan))
pd.DataFrame(policy).to_csv(out/'actual_quota_policy.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/quota_q_simplicity_20261012/all_quality_runs.csv',Path(__file__),root/'experiments/verify_quota_q_compact.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8');sm=sorted(run.parent.glob('quota_q_compact_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==8 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 有效3×2配额Q简化结果（2026-10-12）','', '160新run/16MFE，原320deletionquality cached不算新；160Best重查/8smoke单列。删正常state空行threequota精确等价，真正改变行为仅删2T8S action；Q只有phase3×twoaction，realstall detector与healthyFixed6保留一次。','',f'十二条件rank：{ranks.to_dict()}。',f'同两action强控制联合门：{"通过" if passed else "未通过"}。','']
for r in comp:report.append(f"- Compact-Q vs {r['Control']}：函数{r['FunctionWins']}:{r['FunctionLosses']}，seed{r['SeedWins']}:{r['SeedLosses']}，误差比中位{r['MedianFunctionErrorRatio']:.4g}，该控制门{'通过' if r['ControlGate'] else '未通过'}。")
report.extend(['','Q only真实配额4T6S/6T4S，所有控制same2action/no search modifications。若门未过保留简洁候选不定版，不能只因容易画图就说学习有效。五seed同格开发非独立confirm/significant/noninferior，原弱/不利函数保留。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(result,indent=2))
