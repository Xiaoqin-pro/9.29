"""Evaluate one causal mode-efficiency state against all simple and previous-Q controls."""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/cso_mode_efficiency_20261012'
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(raw)==440 and raw.Status.eq('ok').all() and ck['RunsChecked']==440 and ck['AllCompleted'] and ck['Passed']
conditions={'fixed2','fixed4','fixed6','random','phase','epsfixed','previousQ','stallQ','effQ','effrule','reverseeff'}
assert set(raw.Condition)==conditions and set(raw.Seed)==set(range(1801,1806)) and set(raw.Dimension)=={50} and set(raw.Budget)=={100000}
assert raw.ObjectiveCalls.eq(raw.Budget).all() and raw.OutsideCalls.eq(0).all() and not raw.duplicated(['FunctionID','Seed','Condition']).any()
out.mkdir(parents=True,exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
shutil.copy2(root/'work/cso_mode_efficiency_20261012/behavior_checks.json',out/'behavior_checks.json')
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),Error20FE=('Error20FE','mean'),Error60FE=('Error60FE','mean'),Error80FE=('Error80FE','mean'),PositiveBlocks=('PositiveRewardBlocks','mean'),Action1Share=('Action1Share','mean'),Action2Share=('Action2Share','mean'),Action3Share=('Action3Share','mean')).reset_index();assert s.Runs.eq(5).all()
s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_means.csv')
best_fixed=ranks[['fixed2','fixed4','fixed6']].idxmin();q=raw[raw.Condition=='effQ'];comparisons=[];pairs=[]
for control in sorted(conditions-{'effQ'}):
    m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_candidate','_control'),validate='one_to_one');assert len(m)==40;m['Control']=control;pairs.append(m)
    fw=int((means.effQ<means[control]).sum());fl=int((means.effQ>means[control]).sum());sw=int((m.FinalError_candidate<m.FinalError_control).sum());sl=int((m.FinalError_candidate>m.FinalError_control).sum())
    ratio=(means.effQ.clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means.effQ.gt(1e-8)&means[control].gt(1e-8)
    gate=8-fl>=4 and 40-sl>=20 and ranks.effQ<ranks[control] and not severe.any()
    comparisons.append(dict(Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MedianTimeRatio=float((m.Seconds_candidate/m.Seconds_control).median()),CandidateRank=float(ranks.effQ),ControlRank=float(ranks[control]),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(gate)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
required=[best_fixed,'random','phase','epsfixed','effrule'];passed=bool(c[c.Control.isin(required)].ControlGate.all());gate=dict(Candidate='effQ',RequiredControls=required,BestUnifiedFixed=best_fixed,DevelopmentGate=passed,NewRuns=440,ObjectiveCalls=int(raw.ObjectiveCalls.sum()),Scope='five-seed development; pure FE quota; original search equations; no new-seed confirmation automatically triggered')
(out/'selection_gate.json').write_text(json.dumps(gate,indent=2),encoding='utf-8')
raw.groupby('Condition')[['Seconds','PositiveRewardBlocks','Action1Share','Action2Share','Action3Share']].mean().to_csv(out/'policy_diagnostics.csv')
feedback=[];rows=[]
for row in raw[raw.Condition.isin(['effQ','effrule','reverseeff'])].itertuples():
    d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);F=np.asarray(d['I']['ModeFeedbackLog']);L=np.asarray(d['I']['DecisionLog']);Q=np.asarray(d['I']['QTable']);V=np.asarray(d['I']['QVisits'])
    for ph in range(3):
        for bit in [0,1]:
            ix=(L[:,5]==ph)&(F[:,8]>0 if bit else F[:,8]<=0)
            if not ix.any():continue
            for ac in [1,2,3]:feedback.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,Phase=ph,Bit=bit,Action=ac,Share=float((L[ix,3]==ac).mean()),Blocks=int(ix.sum()),PositiveRate=float((L[ix,9]>0).mean()),TieRate=float((F[ix,8]==0).mean())))
    if row.Condition=='effQ':
        for st in range(6):
            for ac in range(3):rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,State=st+1,Action=ac+1,QValue=float(Q[st,ac]),Visits=int(V[st,ac])))
pd.DataFrame(feedback).to_csv(out/'state_action_feedback.csv',index=False);pd.DataFrame(rows).to_csv(out/'final_q_tables.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
    if f.is_file():
        b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',Path(__file__),root/'experiments/verify_cso_mode_efficiency.py']:
    sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=440,ExtraBestRechecks=440,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
sm=sorted(run.parent.glob('cso_mode_efficiency_smoke_*'))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==22 and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/'smoke_runs.csv')
report=['# 纯配额Q过去模式效率状态开发结果（2026-10-12）','', '440次新优化完成，D50/100k、八函数×五新seed×十一条件；44M真实预算内FE、440Best重查与22smoke单列。全部旧策略逐点回归、真实窗口与Q重放检查通过。','',f'十一条件平均排名：{ranks.to_dict()}。',f'最佳统一固定={best_fixed}；五强控制联合开发门：{"通过" if passed else "未通过"}。','']
for row in comparisons:report.append(f"- effQ对{row['Control']}：函数{row['FunctionWins']}:{row['FunctionLosses']}，seed{row['SeedWins']}:{row['SeedLosses']}，误差比中位数{row['MedianFunctionErrorRatio']:.4g}，控制门{'通过' if row['ControlGate'] else '未通过'}。")
report.extend(['','只改变状态的一个bit：phase3×过去1000FE真实全局增益/模式真实FE相对关系。Q表6×3、三配额、旧半径/搜索公式、reward±1和超参全部固定。窗口不含当前动作回报，ties与首块明确；Trace先Seek后的顺序偏差仍是观测反馈局限。','', '五seed开发不是显著/非劣结论。过门才冻结独立确认；未过不扫描更多window/阈值或追加搜索机制。原Q/停滞Q、反向规则、不利函数全部公开。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(gate,indent=2))
