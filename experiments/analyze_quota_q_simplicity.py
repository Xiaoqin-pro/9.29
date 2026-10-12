"""Deletion-based simplification of pure evaluation-quota Q with matched controls."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np,pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/quota_q_simplicity_20261012'
assert (run/'COMPLETED.json').exists();new=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(new)==200 and new.Status.eq('ok').all() and ck['RunsChecked']==200 and ck['AllCompleted'] and ck['Passed']
funcs={1,3,6,9,12,13,22,30};assert set(new.FunctionID)==funcs and set(new.Seed)==set(range(2201,2206)) and set(new.Condition)=={'Simple-Q6','Simple-Q3','Random','Phase','EpsFixed6'}
fixed=pd.read_csv(root/'results/clpso_full_100k_20261012/raw_runs.csv');fixed=fixed[fixed.Condition.eq('CSO-Fixed6')&fixed.FunctionID.isin(funcs)].copy();fixed['Condition']='Fixed6';fixed['Origin']='cached-fixed6'
original=pd.read_csv(root/'results/quota_q_full_100k_20261012/raw_runs.csv');original=original[original.FunctionID.isin(funcs)].copy();original['Condition']='Original-Q6-Bonus1';original['Origin']='cached-originalQ'
gated=pd.read_csv(root/'results/quota_q_episode_bonus_20261012/raw_runs.csv');gated=gated[gated.Condition.eq('Bonus10-100')].copy();gated['Condition']='Gated-Q6-Bonus10';gated['Origin']='cached-gatedQ'
new['Origin']='new-deletion';raw=pd.concat([fixed,original,gated,new],ignore_index=True);assert len(raw)==320 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
# Check actual cached p0 equality at least for every candidate/run matched triple.
cdirs={'Fixed6':root/'results/cec/clpso_full_100k_study_20261012_193032','Original-Q6-Bonus1':root/'results/cec/quota_q_full_100k_study_20261012_194957','Gated-Q6-Bonus10':root/'results/cec/quota_q_episode_bonus_study_20261012_213013'}
for row in new[new.Condition=='Simple-Q6'].itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True)
 for cond,folder in cdirs.items():
  z=raw[(raw.Condition==cond)&(raw.FunctionID==row.FunctionID)&(raw.Seed==row.Seed)].iloc[0];assert z.InitSeed==row.InitSeed and z.SearchSeed==row.SearchSeed
  old=loadmat(folder/'runs'/f'job_{int(z.JobID):04d}.mat',simplify_cells=True);assert np.array_equal(d['p0'],old['p0'])
out.mkdir(exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/quota_q_simplicity_20261012/behavior_checks.json',out/'behavior_checks.json');raw.to_csv(out/'all_quality_runs.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),Error20FE=('Error20FE','mean'),Error60FE=('Error60FE','mean'),Error80FE=('Error80FE','mean')).reset_index();assert s.Runs.eq(5).all();s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_mean_errors.csv')
comparisons=[];pairs=[];gates=[]
for cand in ['Simple-Q6','Simple-Q3']:
 for ctl in sorted(set(raw.Condition)-{cand}):
  m=raw[raw.Condition==cand].merge(raw[raw.Condition==ctl],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_q','_control'),validate='one_to_one');assert len(m)==40;m['Candidate']=cand;m['Control']=ctl;pairs.append(m)
  fw=int((means[cand]<means[ctl]).sum());fl=int((means[cand]>means[ctl]).sum());sw=int((m.FinalError_q<m.FinalError_control).sum());sl=int((m.FinalError_q>m.FinalError_control).sum());ratio=(means[cand].clip(lower=0)+1e-12)/(means[ctl].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[cand].gt(1e-8)&means[ctl].gt(1e-8)
  passed=8-fl>=4 and 40-sl>=20 and ranks[cand]<ranks[ctl] and not severe.any()
  comparisons.append(dict(Candidate=cand,Control=ctl,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),CandidateRank=float(ranks[cand]),ControlRank=float(ranks[ctl]),SevereFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(passed)))
 required=[z for z in comparisons if z['Candidate']==cand and z['Control'] in ['Fixed6','Random','Phase','EpsFixed6']];gates.append(dict(Candidate=cand,TableStates=3 if cand=='Simple-Q3' else 6,GatePassed=all(z['ControlGate'] for z in required),Rank=float(ranks[cand])))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False);pd.DataFrame(gates).to_csv(out/'selection_gate.csv',index=False);selected='Simple-Q3' if gates[1]['GatePassed'] else 'Simple-Q6' if gates[0]['GatePassed'] else None
new.groupby('Condition')[['PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QUpdates']].mean().to_csv(out/'policy_diagnostics.csv')
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
 if f.is_file():
  b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'results/clpso_full_100k_20261012/raw_runs.csv',root/'results/quota_q_full_100k_20261012/raw_runs.csv',root/'results/quota_q_episode_bonus_20261012/raw_runs.csv',Path(__file__),root/'experiments/verify_quota_q_simplicity.py']:
 sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=200,ObjectiveCalls=int(new.ObjectiveCalls.sum()),CachedRows=120,ActualCachedP0Matches=120,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('quota_q_simplicity_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==10 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 配额Q机制删除结果（2026-10-12）','', '200新run/20M真实FE，八函数五原开发seed，同search骨架/三quota/reward+10，仅删除gate及进一步删stallbit。120旧质量缓存不算新；200Best重查、10smoke单列。完整MAT/state/reward/Q/FE和实际120cachedp0核验通过。','',f'八条件rank：{ranks.to_dict()}。','']
for g in gates:report.append(f"- {g['Candidate']}表{g['TableStates']}×3，强对照门{'通过' if g['GatePassed'] else '未通过'}，rank{g['Rank']:.3f}。")
report.extend(['',f'按先写门选定：{selected or "无，保留候选/不定版"}。','', 'Q6去门、Q3再去stallbit，均无恢复/holding/visit-rate，Search公式不改；简洁不等于效果保证。Fixed6、全程Random/Phase/Eps提供同chance对照，旧Q和较稳gatedcandidate不删除。五seed同格开发非独立确认，不把平均rank票数说显著。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(pd.DataFrame(gates).to_string(index=False));print('SELECTED',selected)
