from pathlib import Path
import sys,json,hashlib
import numpy as np,pandas as pd
from scipy.io import loadmat

def md(df):
 def value(x):return format(x,'.6g') if isinstance(x,(float,np.floating)) else str(x)
 rows=['| '+' | '.join(map(str,df.columns))+' |','| '+' | '.join(['---']*len(df.columns))+' |'];rows.extend('| '+' | '.join(value(x) for x in row)+' |' for row in df.itertuples(index=False,name=None));return chr(10).join(rows)
root=Path(__file__).resolve().parents[1];out=Path(sys.argv[1]).resolve();raw=pd.read_csv(out/'raw_runs.csv');jobs=pd.read_csv(out/'job_manifest.csv');mode=str(jobs.Cohort.iloc[0]);expected=160 if mode=='study' else 480
assert (out/'COMPLETED.json').exists() and len(raw)==len(jobs)==expected and raw.JobID.is_unique and raw.Status.eq('ok').all()
pd.testing.assert_frame_equal(raw[jobs.columns].sort_values('JobID').reset_index(drop=True),jobs.sort_values('JobID').reset_index(drop=True),check_dtype=False)
assert (raw.ObjectiveCalls==raw.Budget).all() and (raw.Evaluations==raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
initials={}
for _,r in raw.iterrows():
 saved=loadmat(out/'runs'/f'job_{int(r.JobID):04d}.mat',simplify_cells=True);I=saved['I'];B=saved['B'];T=np.asarray(saved['T'],dtype=float).ravel();p0=np.asarray(saved['p0'],dtype=float)
 assert len(T)==r.Budget and np.isfinite(T).all() and (np.diff(T)<=0).all() and T[-1]==float(B['Cost'])
 assert (np.abs(B['Vector'])<=100).all() and int(I['TracingEvaluations'])+int(I['SeekingEvaluations'])==r.Budget-50
 key=(int(r.FunctionID),int(r.Seed));h=hashlib.sha256(p0.tobytes()).hexdigest()
 if key in initials:assert initials[key]==h
 else:initials[key]=h
 if r.Policy=='b10':continue
 assert I['StateMode']==r.StateMode
 assert I['RewardMode']==r.RewardMode and float(I['RewardBonus'])==r.RewardBonus and float(I['Gamma'])==r.Gamma
 assert int(I['ActionMismatchCount'])==int(I['FallbackCount'])==int(I['QFallbackUpdates'])==0 and int(I['ActualMaxParentEvaluations'])<=2
 ac=np.asarray(I['ExecutedActionCounts'],dtype=float);signals=np.asarray(I['StateSignalCounts'],dtype=float)
 assert ac.sum()==signals.sum()
 if r.Policy=='signal':assert np.array_equal(ac,signals)
 if r.Policy=='reverse_signal':assert np.array_equal(ac,signals[::-1])
 n=float(ac.sum());local=float(np.asarray(I['ConditionalFollowSuccesses'],dtype=float).sum());global_hits=float(np.asarray(I['ConditionalFollowGlobalSuccesses'],dtype=float).sum())
 assert float(I['PositiveRewards'])+float(I['NegativeRewards'])==n
 hits=local if r.RewardMode=='parent_binary' else global_hits;assert float(I['PositiveRewards'])==hits
 bound=r.RewardBonus*hits-(n-hits)
 if r.RewardMode=='global_gain':assert float(I['RewardTotal'])<=bound+1e-8 and float(I['RewardTotal'])>=-(n-hits)-1e-8
 else:assert abs(float(I['RewardTotal'])-bound)<1e-8
raw['Source']='new-'+mode;raw['RunKey']=raw.Source+'-'+raw.JobID.astype(str)
if mode=='study':
 old=pd.read_csv(root/'results/fcs_repaired_20261012/raw_runs.csv');old=old[old.Cohort.eq('pilot') & old.Method.ne('FCS-q')].copy()
 labels={'B10-Reference':'B10','FCS-batch':'Batch','FCS-continue':'Continue','FCS-switch':'Switch','FCS-random':'Random','FCS-success':'Success','FCS-reverse':'Reverse'}
 old['Condition']=old.Method.map(labels);assert old.Condition.notna().all();old['Source']='S0-cache';old['RunKey']=old.Source+'-'+old.JobID.astype(str)
 reward=pd.read_csv(root/'results/fcs_reward_20261012/raw_runs.csv');reward=reward[reward.Condition.eq('G1-g0')].copy();assert len(reward)==40
 reward['Condition']='Q-success';reward['Source']='reward-cache';reward['RunKey']=reward.Source+'-'+reward.JobID.astype(str)
 allruns=pd.concat([raw,old,reward],ignore_index=True);assert len(allruns)==480
else:allruns=raw.copy()
assert allruns.RunKey.is_unique and allruns.groupby(['Condition','FunctionID']).size().eq(5 if mode=='study' else 10).all()
summary=allruns.groupby(['FunctionID','Condition','Source']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),MedianError=('FinalError','median'),StdError=('FinalError','std')).reset_index();means=summary.pivot(index='FunctionID',columns='Condition',values='MeanError');ranks=means.rank(axis=1)
summary.to_csv(out/'summary_by_function.csv',index=False);allruns.to_csv(out/'combined_quality_runs.csv',index=False);means.to_csv(out/'mean_error_table.csv')
overall=pd.DataFrame([{'Condition':c,'AverageFunctionRank':float(ranks[c].mean()),'FunctionsBest':int(means[c].eq(means.min(axis=1)).sum()),'Source':str(allruns.loc[allruns.Condition.eq(c),'Source'].iloc[0])} for c in means]).sort_values('AverageFunctionRank');overall.to_csv(out/'overall_summary.csv',index=False)
conditions=[c for c in ['Q-success','Q-phase','Q-quality'] if c in means];gate=[];pairrows=[]
for c in conditions:
 row={'Condition':c};ok=True
 for control in ['Batch','Random','Rule-quality','Q-success','B10']:
  if c==control:continue
  d=allruns[allruns.Condition.isin([c,control])].pivot(index=['FunctionID','Seed'],columns='Condition',values='FinalError');diff=d[c]-d[control]
  fw=int((means[c]<means[control]).sum());fl=int((means[c]>means[control]).sum());sw=int((diff<0).sum());sl=int((diff>0).sum())
  pairrows.append(dict(Condition=c,Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=int((means[c]==means[control]).sum()),SeedWins=sw,SeedLosses=sl,SeedTies=int((diff==0).sum())))
  if control in ['Batch','Random','Rule-quality']:
   row[control+'FunctionWins']=fw;row[control+'FunctionLosses']=fl;row[control+'SeedWins']=sw;row[control+'SeedLosses']=sl;ok=ok and fw>fl and sw>sl
 row['DevelopmentComparisonsPassed']=bool(ok);row['EligibleForConfirmation']=bool(ok and c=='Q-quality');gate.append(row)
pairs=pd.DataFrame(pairrows);pairs.to_csv(out/'pairwise_comparison.csv',index=False);gates=pd.DataFrame(gate);gates.to_csv(out/'confirmation_gate.csv',index=False)
eligible=gates[gates.EligibleForConfirmation].copy();selected='Q-quality' if len(eligible) else None
selection={'Mode':mode,'NewRuns':len(raw),'CachedRuns':len(allruns)-len(raw),'SelectedCondition':selected,'EligibleConditions':eligible.Condition.tolist(),'Rule':'Only Q-quality is the prespecified candidate; it must win more function means and paired seeds than it loses against Batch, Random AND Rule-quality.','ClaimStatus':'Development selection only; requires independent-seed confirmation' if mode=='study' else 'Independent-seed check; not a full 29-function claim'}
(out/'selection.json').write_text(json.dumps(selection,indent=2),encoding='utf-8');checks={'NewRuns':len(raw),'InitialPopulationsChecked':len(initials),'ActualCalls':int(raw.ObjectiveCalls.sum()),'GridAndTracePassed':True,'RewardModeAndPositiveCreditCountsPassed':True,'AllDomainChecksPassed':True,'Fallbacks':0,'ActionMismatches':0};(out/'integrity_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
hashes={}
for p in (out/'source_snapshot').rglob('*'):
 if p.is_file():
  b=p.read_bytes();hashes[str(p.relative_to(out/'source_snapshot'))]={'sha256_execution_bytes':hashlib.sha256(b).hexdigest(),'sha256_LF_normalized':hashlib.sha256(b.replace(bytes([13,10]),bytes([10]))).hexdigest()}
(out/'source_manifest.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
report=['# FCS相对质量状态结果','',f'新增{len(raw)}次，缓存对照{len(allruns)-len(raw)}次。协议：docs/FCS_STATE_STUDY_PROTOCOL_20261012.md。','',md(overall),'','## 预定确认门槛','',md(gates),'','## 两两比较','',md(pairs),'','选择：'+str(selected),'','Q-quality用首访实测候选在真实fitness前20%的质量位；Q-success是同奖励/参数的原成功位；Q-phase删去反馈位；Rule-quality/反向为匹配固定规则。reward固定global±1，gamma0，仍6状态2动作，无额外FE。缓存时间不作速度比较。开发排名不是独立验证或新颖性通过。']
(out/'RESULTS_REPORT.md').write_text(chr(10).join(report),encoding='utf-8');print(overall.to_string(index=False));print(gates.to_string(index=False));print(json.dumps(selection,indent=2))
if len(sys.argv)>2:
 public=Path(sys.argv[2]).resolve();public.mkdir(parents=True,exist_ok=True)
 for name in ['raw_runs.csv','job_manifest.csv','summary_by_function.csv','combined_quality_runs.csv','mean_error_table.csv','overall_summary.csv','pairwise_comparison.csv','confirmation_gate.csv','selection.json','integrity_checks.json','source_manifest.json','RESULTS_REPORT.md']:
  (public/name).write_text(chr(10).join((out/name).read_text(encoding='utf-8').splitlines())+chr(10),encoding='utf-8')
 witness=root/'work/fcs_repair_20261012/state_checks.json';(public/'state_checks.json').write_text(witness.read_text(encoding='utf-8'),encoding='utf-8')
 (public/'README.md').write_text('# FCS相对质量状态证据'+chr(10)+chr(10)+'新源码以source_manifest为准，奖励缓存来自774b4f3/S0缓存来自2efb00c。'+chr(10)+'旧状态与固定控制等价经19组精确回归验证。新增运行完整轨迹在本地results/cec/'+out.name+'/runs/；此处包含所有条件、原始CSV、选择门槛与源码指纹。'+chr(10)+'复现：MATLAB run_fcs_state_study；分析：python experiments/analyze_fcs_state_study.py <run-dir> <public-dir>，需要numpy/pandas/scipy。'+chr(10),encoding='utf-8')
 h={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in public.iterdir() if p.is_file() and p.name!='published_sha256.json'};(public/'published_sha256.json').write_text(json.dumps(h,indent=2),encoding='utf-8')
