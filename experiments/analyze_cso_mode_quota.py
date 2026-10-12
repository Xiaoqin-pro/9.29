"""Diagnose fixed true-FE quotas before introducing Q-learning."""
from pathlib import Path
import argparse,hashlib,json,shutil,itertools
import numpy as np
import pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--output',type=Path,default=root/'results/cso_mode_quota_20261012');a=p.parse_args();run=a.run_dir.resolve();out=a.output.resolve()
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');checks=json.loads((run/'independent_artifact_checks.json').read_text())
assert len(raw)==120 and raw.Status.eq('ok').all() and checks['RunsChecked']==120 and checks['AllCompleted'] and checks['Passed']
assert set(raw.Condition)=={'2T8S','4T6S','6T4S'} and set(raw.Budget)=={100000} and set(raw.Dimension)=={50} and set(raw.Seed)==set(range(1301,1306))
assert raw.ObjectiveCalls.eq(raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
assert raw.MaxParentEvaluations.le(2).all() and not raw.duplicated(['FunctionID','Seed','Condition']).any()
out.mkdir(parents=True,exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/cso_mode_quota_20261012/behavior_checks.json',out/'behavior_checks.json')
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),Error20FE=('Error20FE','mean'),Error60FE=('Error60FE','mean'),Error80FE=('Error80FE','mean'),MeanCoverage=('MeanSeekCoverage','mean')).reset_index();assert s.Runs.eq(5).all()
s['MeanErrorRank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False)
ranks=s.groupby('Condition').MeanErrorRank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv')
means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');best=means.idxmin(axis=1);means['BestFixedQuota']=best;means.to_csv(out/'function_means.csv');best_counts=best.value_counts()
pair_rows=[];dominating=[]
for ca,cb in itertools.combinations(['2T8S','4T6S','6T4S'],2):
    m=raw[raw.Condition==ca].merge(raw[raw.Condition==cb],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_a','_b'),validate='one_to_one');assert len(m)==40
    aw=int((means[ca]<means[cb]).sum());bw=int((means[ca]>means[cb]).sum());sw=int((m.FinalError_a<m.FinalError_b).sum());sl=int((m.FinalError_a>m.FinalError_b).sum())
    pair_rows.append(dict(A=ca,B=cb,FunctionAWins=aw,FunctionBWins=bw,FunctionTies=8-aw-bw,SeedAWins=sw,SeedBWins=sl,SeedTies=40-sw-sl,MedianPairedTimeRatio=float((m.Seconds_a/m.Seconds_b).median())))
for ca in ['2T8S','4T6S','6T4S']:
    if all((means[ca]<=means[cb]).all() for cb in ['2T8S','4T6S','6T4S'] if cb!=ca):
        ok=True
        for cb in ['2T8S','4T6S','6T4S']:
            if cb==ca:continue
            m=raw[raw.Condition==ca].merge(raw[raw.Condition==cb],on=['FunctionID','Seed'],suffixes=('_a','_b'))
            ok=ok and int((m.FinalError_a<=m.FinalError_b).sum())>=20
        if ok:dominating.append(ca)
pd.DataFrame(pair_rows).to_csv(out/'pair_comparisons.csv',index=False)
node_rows=[]
for fid,g in s.groupby('FunctionID'):
    row={'FunctionID':int(fid)}
    for col in ['Error20FE','Error60FE','Error80FE','MeanError']:
        row[col+'Best']=g.loc[g[col].idxmin(),'Condition']
    row['BestQuotaChangesAcrossNodes']=len(set(row[k] for k in row if k.endswith('Best')))>1
    node_rows.append(row)
nodes=pd.DataFrame(node_rows);nodes.to_csv(out/'node_best_quotas.csv',index=False)
feedback=[]
for row in raw.itertuples():
    d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['RoundLog']).reshape(-1,13);T=np.asarray(d['T']).reshape(-1)
    # Mode-specific feedback is observed only; it is not a counterfactual score.
    fr=dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,TraceFE=row.TracingEvaluations,SeekFE=row.SeekingEvaluations,TraceLocalPerFE=row.TraceLocalSuccesses/row.TracingEvaluations,SeekMarginalLocalPerFE=row.SeekMarginalSuccesses/row.SeekingEvaluations,TraceGlobalPerFE=row.TraceGlobalSuccesses/row.TracingEvaluations,SeekGlobalPerFE=row.SeekGlobalSuccesses/row.SeekingEvaluations,GlobalPositiveRounds=int(((L[:,9]+L[:,10])>0).sum()),RoundCount=len(L))
    ends=np.arange(150,row.Budget+1,100);starts=ends-100
    improved=T[ends-1]<T[starts-1]
    fr['Complete100FEBlocks']=len(ends);fr['GlobalPositive100FEBlocks']=int(improved.sum());fr['GlobalPositive100FEBlockRate']=float(improved.mean())
    feedback.append(fr)
pd.DataFrame(feedback).to_csv(out/'feedback_runs.csv',index=False)
pd.DataFrame(feedback).groupby('Condition').mean(numeric_only=True).to_csv(out/'feedback_summary.csv')
complementary=int((best_counts>=2).sum())>=2;node_changed=int(nodes.BestQuotaChangesAcrossNodes.sum())
ready=not dominating and complementary and node_changed>=2
result=dict(NewRuns=120,ActualObjectiveCalls=int(raw.ObjectiveCalls.sum()),DominatingQuota=dominating,BestFunctionCounts={str(k):int(v) for k,v in best_counts.items()},FunctionsWithBestQuotaChangingAcrossNodes=node_changed,MultipleQuotasBestOnAtLeastTwoFunctions=complementary,ActionComplementarityGate=bool(ready),BestUnifiedFixedQuota=str(ranks.index[0]),Scope='five-seed development; mean-node changes do not prove learnable states or causal mode complementarity; no Q run yet')
(out/'action_gate.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
    if f.is_file():
        b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',Path(__file__),root/'experiments/verify_cso_mode_quota.py']:
    sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),ExtraBestRechecks=120,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
smoke_dir=sorted(run.parent.glob('cso_mode_quota_smoke_*'))[-1];smoke=pd.read_csv(smoke_dir/'raw_runs.csv');assert len(smoke)==6 and smoke.Status.eq('ok').all();shutil.copy2(smoke_dir/'raw_runs.csv',out/'smoke_raw_runs.csv')
report=['# B10固定模式评价配额预试（2026-10-12）','', '120次新优化完成，D50/100k，八函数×五新seed×三固定配额，无Q；12M真实预算内FE、120次额外Best重查、六次smoke分开列出。MR与全部候选公式固定，4T6S逐点等价B10。所有轨迹/计数独立核验通过。','',f'统一固定配额按八函数均值平均排名：{ranks.to_dict()}；最佳统一配额{ranks.index[0]}。各函数最佳配额计数{result["BestFunctionCounts"]}。','',f'节点最佳配额改变的函数数{node_changed}；预写动作可调性门：{"通过" if ready else "未通过"}；支配配额{dominating or "无"}。','', '以上是开发观察，不是显著优势、不证明Q必要。每函数事后最佳不作为可部署控制器。100FE正奖励事件只统计过去真实gbest改善，local和global模式贡献分开列出。一个配额会改变后续状态，模式单位FE成功率不能当未选择动作的反事实。','', '下一步若进入Q，保留最佳统一固定配额、4T6S、Random、Phase、EpsFixed；另写小Q协议与新增seed，不仅比较弱固定配额。尚未运行Q。']
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
print(pd.DataFrame(pair_rows).to_string(index=False));print(json.dumps(result,ensure_ascii=False,indent=2));print('OUTPUT',out)
