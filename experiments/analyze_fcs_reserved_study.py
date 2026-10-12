from pathlib import Path
import sys,json,hashlib
import numpy as np,pandas as pd
from scipy.io import loadmat

def md(df):
 def value(x):return format(x,'.6g') if isinstance(x,(float,np.floating)) else str(x)
 rows=['| '+' | '.join(map(str,df.columns))+' |','| '+' | '.join(['---']*len(df.columns))+' |'];rows.extend('| '+' | '.join(value(x) for x in row)+' |' for row in df.itertuples(index=False,name=None));return chr(10).join(rows)
root=Path(__file__).resolve().parents[1];out=Path(sys.argv[1]).resolve();raw=pd.read_csv(out/'raw_runs.csv');jobs=pd.read_csv(out/'job_manifest.csv');mode=str(jobs.Cohort.iloc[0]);expected=320 if mode=='study' else 560
assert (out/'COMPLETED.json').exists() and len(raw)==len(jobs)==expected and raw.JobID.is_unique and raw.Status.eq('ok').all()
pd.testing.assert_frame_equal(raw[jobs.columns].sort_values('JobID').reset_index(drop=True),jobs.sort_values('JobID').reset_index(drop=True),check_dtype=False)
assert (raw.ObjectiveCalls==raw.Budget).all() and (raw.Evaluations==raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
initials={}
for _,r in raw.iterrows():
 saved=loadmat(out/'runs'/f'job_{int(r.JobID):04d}.mat',simplify_cells=True);I=saved['I'];B=saved['B'];T=np.asarray(saved['T'],dtype=float).ravel();p0=np.asarray(saved['p0'],dtype=float)
 assert len(T)==r.Budget and np.isfinite(T).all() and (np.diff(T)<=0).all() and T[-1]==float(B['Cost']) and (np.abs(B['Vector'])<=100).all()
 assert int(I['TracingEvaluations'])+int(I['SeekingEvaluations'])==r.Budget-50
 key=(int(r.FunctionID),int(r.Seed));h=hashlib.sha256(p0.tobytes()).hexdigest()
 if key in initials:assert initials[key]==h
 else:initials[key]=h
 if r.Policy=='b10':continue
 assert I['Policy']==r.Policy and float(I['RewardBonus'])==r.RewardBonus and float(I['Gamma'])==r.Gamma and not I['PendingAtEnd']
 assert int(I['ActualMaxParentEvaluations'])<=2
 ac=np.asarray(I['ActionCounts'],dtype=float);visits=np.asarray(I['QVisits'],dtype=float)
 assert ac.sum()==int(I['Decisions'])==int(I['FreeDecisions'])+int(I['ForcedKeep'])
 assert I['MeanPlannedCoverage']-1e-12<=I['MeanParentCoverage']<=I['MeanPlannedCoverage']+1+1e-12
 if r.Policy=='q':assert int(I['QUpdates'])==visits.sum()==int(I['FreeDecisions'])
 else:assert I['QUpdates']==0
 assert int(I['PolicySeed'])==(int(r.SearchSeed)+2000003)%(2**32-1)
 if int(I['Decisions'])==int(I['Rounds']):
  last=np.arange(60,int(r.Budget)+1,10);gain=T[last-2]-T[last-1]
  assert int(I['GlobalLastSuccesses'])==int((gain>0).sum()) and np.isclose(float(I['GlobalLastGain']),gain.sum(),rtol=1e-12,atol=1e-8)
 q=np.asarray(I['QTable'],dtype=float);assert q.shape==(6,2) and np.isfinite(q).all()
 if r.Gamma<1:assert q.min()>=-1/(1-r.Gamma)-1e-8 and q.max()<=r.RewardBonus/(1-r.Gamma)+1e-8
raw['Source']='new-'+mode;raw['RunKey']=raw.Source+'-'+raw.JobID.astype(str)
if mode=='study':
 old=pd.read_csv(root/'results/fcs_repaired_20261012/raw_runs.csv');old=old[old.Cohort.eq('pilot') & old.Method.isin(['FCS-batch','B10-Reference'])].copy();assert len(old)==80
 old['Condition']=old.Method.map({'FCS-batch':'Keep','B10-Reference':'B10'});old['Source']='exact-S0-cache';old['RunKey']=old.Source+'-'+old.JobID.astype(str)
 allruns=pd.concat([raw,old],ignore_index=True);assert len(allruns)==400
else:allruns=raw.copy()
assert allruns.RunKey.is_unique and allruns.groupby(['Condition','FunctionID']).size().eq(5 if mode=='study' else 10).all()
summary=allruns.groupby(['FunctionID','Condition','Source']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),MedianError=('FinalError','median'),StdError=('FinalError','std')).reset_index();means=summary.pivot(index='FunctionID',columns='Condition',values='MeanError');ranks=means.rank(axis=1)
summary.to_csv(out/'summary_by_function.csv',index=False);allruns.to_csv(out/'combined_quality_runs.csv',index=False);means.to_csv(out/'mean_error_table.csv')
overall=pd.DataFrame([{'Condition':c,'AverageFunctionRank':float(ranks[c].mean()),'FunctionsBest':int(means[c].eq(means.min(axis=1)).sum()),'Source':str(allruns.loc[allruns.Condition.eq(c),'Source'].iloc[0])} for c in means]).sort_values('AverageFunctionRank');overall.to_csv(out/'overall_summary.csv',index=False)
conditions=[c for c in means if c.startswith('Q')];gate=[];pairrows=[]
for c in conditions:
 row={'Condition':c};ok=True
 for control in ['Keep','Explore','Random','Progress','Reverse','B10']:
  if c==control:continue
  d=allruns[allruns.Condition.isin([c,control])].pivot(index=['FunctionID','Seed'],columns='Condition',values='FinalError');diff=d[c]-d[control]
  fw=int((means[c]<means[control]).sum());fl=int((means[c]>means[control]).sum());sw=int((diff<0).sum());sl=int((diff>0).sum())
  pairrows.append(dict(Condition=c,Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=int((means[c]==means[control]).sum()),SeedWins=sw,SeedLosses=sl,SeedTies=int((diff==0).sum())))
  if control in ['Keep','Random','Progress']:
   row[control+'FunctionWins']=fw;row[control+'FunctionLosses']=fl;row[control+'SeedWins']=sw;row[control+'SeedLosses']=sl;ok=ok and fw>fl and sw>sl
 row['EligibleForConfirmation']=bool(ok);gate.append(row)
pairs=pd.DataFrame(pairrows);pairs.to_csv(out/'pairwise_comparison.csv',index=False);gates=pd.DataFrame(gate);gates.to_csv(out/'confirmation_gate.csv',index=False)
eligible=gates[gates.EligibleForConfirmation].copy();selected=None
if len(eligible):
 def score(r):
  c=r.Condition;complexity=(10 if c.startswith('Q10') else 1)+(.25 if c.endswith('g9') else 0)
  return (r.KeepFunctionWins+r.RandomFunctionWins+r.ProgressFunctionWins,r.KeepSeedWins+r.RandomSeedWins+r.ProgressSeedWins,-complexity)
 selected=max((r for _,r in eligible.iterrows()),key=score).Condition
selection={'Mode':mode,'NewRuns':len(raw),'CachedRuns':len(allruns)-len(raw),'SelectedCondition':selected,'EligibleConditions':eligible.Condition.tolist(),'Rule':'Strictly more function-mean and paired-seed wins than losses against Keep, Random AND Progress; tie-break sum function wins, seed wins, then smaller bonus/gamma.','ClaimStatus':'Development selection only; requires independent-seed confirmation' if mode=='study' else 'Independent-seed check; not a full 29-function claim'}
(out/'selection.json').write_text(json.dumps(selection,indent=2),encoding='utf-8');checks={'NewRuns':len(raw),'InitialPopulationsChecked':len(initials),'ActualCalls':int(raw.ObjectiveCalls.sum()),'GridAndTracePassed':True,'QCreditAndLastFEMetricsPassed':True,'AllDomainChecksPassed':True,'Fallbacks':0,'ActionMismatches':0};(out/'integrity_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
hashes={}
for p in (out/'source_snapshot').rglob('*'):
 if p.is_file():
  b=p.read_bytes();hashes[str(p.relative_to(out/'source_snapshot'))]={'sha256_execution_bytes':hashlib.sha256(b).hexdigest(),'sha256_LF_normalized':hashlib.sha256(b.replace(bytes([13,10]),bytes([10]))).hexdigest()}
(out/'source_manifest.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
report=['# FCS单保留名额结果','',f'新增{len(raw)}次，缓存对照{len(allruns)-len(raw)}次。协议：docs/FCS_RESERVED_STUDY_PROTOCOL_20261012.md。','',md(overall),'','## 预定确认门槛','',md(gates),'','## 两两比较','',md(pairs),'','选择：'+str(selected),'','每轮只控制最后1Seeking FE，先保持batch前缀。Keep与旧Batch逐点等价；Explore选前缀未覆盖父代。Q1/Q10为末FE global改善正奖励1/10否则-1，g0/g9为gamma0/.9。Q更新对应下一实际决策，终止0bootstrap，政策随机流独立。缓存时间不作速度比较；开发排名不是独立验证或新颖性通过。']
(out/'RESULTS_REPORT.md').write_text(chr(10).join(report),encoding='utf-8');print(overall.to_string(index=False));print(gates.to_string(index=False));print(json.dumps(selection,indent=2))
if len(sys.argv)>2:
 public=Path(sys.argv[2]).resolve();public.mkdir(parents=True,exist_ok=True)
 for name in ['raw_runs.csv','job_manifest.csv','summary_by_function.csv','combined_quality_runs.csv','mean_error_table.csv','overall_summary.csv','pairwise_comparison.csv','confirmation_gate.csv','selection.json','integrity_checks.json','source_manifest.json','RESULTS_REPORT.md']:
  (public/name).write_text(chr(10).join((out/name).read_text(encoding='utf-8').splitlines())+chr(10),encoding='utf-8')
 witness=root/'work/fcs_repair_20261012/reserved_checks.json';(public/'reserved_checks.json').write_text(witness.read_text(encoding='utf-8'),encoding='utf-8')
 (public/'README.md').write_text('# FCS单保留名额证据'+chr(10)+chr(10)+'新实现以source_manifest为准，Keep缓存来自2efb00c的FCS-batch，另含B10参考。'+chr(10)+'Keep/Batch经40组逐点/Best/T/RNG严格回归，所有351配置均保持同一搜索随机流。新增运行完整轨迹在本地results/cec/'+out.name+'/runs/；此处包含所有条件、原始CSV、选择门槛与源码指纹。'+chr(10)+'复现：MATLAB run_fcs_reserved_study；分析：python experiments/analyze_fcs_reserved_study.py <run-dir> <public-dir>，需要numpy/pandas/scipy。'+chr(10),encoding='utf-8')
 h={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in public.iterdir() if p.is_file() and p.name!='published_sha256.json'};(public/'published_sha256.json').write_text(json.dumps(h,indent=2),encoding='utf-8')
