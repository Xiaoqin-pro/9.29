"""Independent ten-seed confirmation of causal sustained-stagnation ModeQ."""
from pathlib import Path
import argparse,hashlib,json,shutil,itertools
import numpy as np
import pandas as pd
from scipy.stats import rankdata
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir.resolve();out=root/'results/cso_mode_q_state_confirm_20261012'
assert (run/'COMPLETED.json').exists();raw=pd.read_csv(run/'raw_runs.csv');ck=json.loads((run/'independent_artifact_checks.json').read_text());assert len(raw)==640 and raw.Status.eq('ok').all() and ck['RunsChecked']==640 and ck['AllCompleted'] and ck['Passed']
conditions={'fixed2','fixed4','fixed6','random','phase','epsfixed','binaryQ','stag1000'}
assert set(raw.Condition)==conditions and set(raw.Seed)==set(range(1501,1511)) and set(raw.Dimension)=={50} and set(raw.Budget)=={100000}
assert not raw.duplicated(['FunctionID','Seed','Condition']).any() and raw.ObjectiveCalls.eq(raw.Budget).all() and raw.OutsideCalls.eq(0).all()
out.mkdir(parents=True,exist_ok=True)
for name in ['raw_runs.csv','job_manifest.csv','environment.json','independent_artifact_checks.json']:shutil.copy2(run/name,out/name)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),Error20FE=('Error20FE','mean'),Error60FE=('Error60FE','mean'),Error80FE=('Error80FE','mean'),PositiveBlocks=('PositiveRewardBlocks','mean'),Action1Share=('Action1Share','mean'),Action2Share=('Action2Share','mean'),Action3Share=('Action3Share','mean')).reset_index();assert s.Runs.eq(10).all()
s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_means.csv')

def signed_rank(d):
    d=np.asarray(d);d=d[d!=0]
    if not len(d):return 1.0,0.0,0
    rank=rankdata(np.abs(d),method='average');wp=rank[d>0].sum();center=rank.sum()/2
    distribution=np.array([np.dot(bits,rank) for bits in itertools.product([0,1],repeat=len(d))])
    return float(np.mean(np.abs(distribution-center)>=abs(wp-center)-1e-12)),float(wp),len(d)
def holm(values):
    values=np.asarray(values);order=np.argsort(values);result=np.zeros(len(values));running=0
    for k,i in enumerate(order):running=max(running,(len(values)-k)*values[i]);result[i]=min(1,running)
    return result

comparisons=[];stats=[];pairs=[];candidate='stag1000';q=raw[raw.Condition==candidate]
for control in sorted(conditions-{candidate}):
    m=q.merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_candidate','_control'),validate='one_to_one');assert len(m)==80
    m['Control']=control;m['Difference']=m.FinalError_candidate-m.FinalError_control;m['ErrorRatio']=(m.FinalError_candidate.clip(lower=0)+1e-12)/(m.FinalError_control.clip(lower=0)+1e-12);pairs.append(m)
    fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.Difference<0).sum());sl=int((m.Difference>0).sum())
    ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8)
    gate=8-fl>=4 and 80-sl>=40 and ranks[candidate]<ranks[control] and not severe.any()
    comparisons.append(dict(Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=80-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MedianTimeRatio=float((m.Seconds_candidate/m.Seconds_control).median()),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(gate)))
    for fid,g in m.groupby('FunctionID'):
        pv,wp,n=signed_rank(g.Difference);stats.append(dict(Control=control,FunctionID=int(fid),SeedWins=int((g.Difference<0).sum()),SeedLosses=int((g.Difference>0).sum()),MeanDifference=float(g.Difference.mean()),MedianDifference=float(g.Difference.median()),PValue=pv,WPositive=wp,NonzeroPairs=n))
stats=pd.DataFrame(stats);stats['HolmWithinComparison']=np.nan
for control,g in stats.groupby('Control'):stats.loc[g.index,'HolmWithinComparison']=holm(g.PValue)
required_names=['fixed6','random','phase','epsfixed'];stats['HolmAcrossFourStrongControls']=np.nan;ix=stats.Control.isin(required_names);stats.loc[ix,'HolmAcrossFourStrongControls']=holm(stats.loc[ix,'PValue'])
stats.to_csv(out/'function_statistics.csv',index=False);c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(pairs,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
passed=bool(c[c.Control.isin(required_names)].ControlGate.all());gate=dict(ConfirmationGate=passed,Candidate='stag1000',NewRuns=640,ObjectiveCalls=int(raw.ObjectiveCalls.sum()),RequiredControls=required_names,Scope='independent ten-seed eight-function D50/100k confirmation; not full suite or standard-budget evidence')
(out/'selection_gate.json').write_text(json.dumps(gate,indent=2),encoding='utf-8');raw.groupby('Condition')[['Seconds','PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QuotaFallbackRounds']].mean().to_csv(out/'policy_diagnostics.csv')
dev=pd.read_csv(root/'results/cso_mode_q_state_20261012/comparisons.csv');dev=dev[dev.Candidate==candidate].copy();dev['Stage']='development_5seed';c['Stage']='confirmation_10seed';pd.concat([dev,c],ignore_index=True).to_csv(out/'development_vs_confirmation.csv',index=False)
sources=[]
for f in sorted((run/'source_snapshot').rglob('*')):
    if f.is_file():
        b=f.read_bytes();sources.append(dict(Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
for f in [root/'data/cec2017/cec17_func.mexw64',Path(__file__),root/'experiments/verify_cso_mode_q_state_confirmation.py']:
    sources.append(dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RunDirectory=str(run),NewRuns=640,ExtraBestRechecks=640,Sources=sources),ensure_ascii=False,indent=2),encoding='utf-8')
smoke_dir=sorted(run.parent.glob('cso_mode_q_state_confirmation_smoke_*'))[-1];smoke=pd.read_csv(smoke_dir/'raw_runs.csv');assert len(smoke)==16 and smoke.Status.eq('ok').all();shutil.copy2(smoke_dir/'raw_runs.csv',out/'smoke_raw_runs.csv')
report=['# 连续停滞小Q独立确认（2026-10-12）','', '640次新优化完成，D50/100k、八函数×十新seed×八条件；64M真实调用、640次Best重查与16smoke单列。真实stall从T重算、动作/奖励/块回退/下一状态/终端Q表全部独立核验。','',f'八条件平均排名：{ranks.to_dict()}。',f'预写四强对照确认门：{"通过" if passed else "未通过"}。','']
for row in comparisons:report.append(f"- stag1000对{row['Control']}：函数{row['FunctionWins']}:{row['FunctionLosses']}，seed{row['SeedWins']}:{row['SeedLosses']}，函数误差比中位数{row['MedianFunctionErrorRatio']:.4g}，该对照门{'通过' if row['ControlGate'] else '未通过'}。")
report.extend(['','逐函数精确符号秩、比较内八函数Holm及四强对照32检验Holm均公开。未显著不等效、过工程门不等于正式非劣；开发与确认只并列不合并。全部原Q和不利函数保留。','', '若确认通过，可继续全29函数和500k/D100验证；若未通过，本批不追加有利seed、不改阈值/奖励或加算子。真实多样性和停滞趋势只能支撑有范围的机制解释。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(gate,indent=2))
