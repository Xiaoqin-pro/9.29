"""Compare shared-search adaptation and action-linked recovery without conflating Q gains."""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
import pandas as pd
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('route_a',type=Path);p.add_argument('route_b',type=Path);a=p.parse_args();ra=a.route_a.resolve();rb=a.route_b.resolve();out=root/'results/cso_two_routes_20261012'
allrows=[];manifests=[]
for route,run,expected in [('A',ra,360),('B',rb,160)]:
    assert (run/'COMPLETED.json').exists();r=pd.read_csv(run/'raw_runs.csv');manifest=pd.read_csv(run/'job_manifest.csv');check=json.loads((run/'independent_artifact_checks.json').read_text())
    assert len(r)==len(manifest)==expected and r.Status.eq('ok').all() and check['RunsChecked']==expected and check['Passed'] and check['AllCompleted']
    assert set(r.Seed)==set(range(1701,1706)) and set(r.Dimension)=={50} and set(r.Budget)=={100000}
    assert r.ObjectiveCalls.eq(r.Budget).all() and r.OutsideCalls.eq(0).all() and r.PostRunRecheckCalls.eq(1).all()
    r['Route']=route;r['SourceDirectory']=str(run);allrows.append(r);manifest['Route']=route;manifests.append(manifest)
raw=pd.concat(allrows,ignore_index=True);assert len(raw)==520 and not raw.duplicated(['FunctionID','Seed','Condition']).any()
# Same initialization/search seeds across routes; later trajectories may legitimately differ.
assert raw.groupby(['FunctionID','Seed']).InitSeed.nunique().eq(1).all() and raw.groupby(['FunctionID','Seed']).SearchSeed.nunique().eq(1).all()
out.mkdir(parents=True,exist_ok=True);raw.to_csv(out/'raw_runs.csv',index=False);pd.concat(manifests,ignore_index=True).to_csv(out/'job_manifest.csv',index=False)
s=raw.groupby(['FunctionID','Condition']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean'),Error20FE=('Error20FE','mean'),Error60FE=('Error60FE','mean'),Error80FE=('Error80FE','mean'),PositiveBlocks=('PositiveRewardBlocks','mean'),Action1Share=('Action1Share','mean'),Action2Share=('Action2Share','mean'),Action3Share=('Action3Share','mean')).reset_index();assert s.Runs.eq(5).all()
s['Rank']=s.groupby('FunctionID').MeanError.rank(method='average');s.to_csv(out/'summary.csv',index=False);ranks=s.groupby('Condition').Rank.mean().sort_values();ranks.to_csv(out/'mean_ranks.csv');means=s.pivot(index='FunctionID',columns='Condition',values='MeanError');means.to_csv(out/'function_means.csv')
fixed=['Adapt-fixed2','Adapt-fixed4','Adapt-fixed6'];best_fixed=ranks[fixed].idxmin();comparisons=[];paired=[]
queries=[('Adapt-Q',c) for c in [best_fixed,'Adapt-random','Adapt-phase','Adapt-epsfixed','Old-Q','Old-fixed6','Q-reset']]+[('Q-reset',c) for c in ['Rule-reset','Random-reset','EpsFixed-reset','Old-Q','Old-fixed6','Adapt-Q']]+[('Adapt-fixed6','Old-fixed6'),('Adapt-fixed2','Old-fixed6'),('Adapt-fixed4','Old-fixed6')]
for candidate,control in queries:
    m=raw[raw.Condition==candidate].merge(raw[raw.Condition==control],on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_candidate','_control'),validate='one_to_one');assert len(m)==40
    m['Candidate']=candidate;m['Control']=control;paired.append(m)
    fw=int((means[candidate]<means[control]).sum());fl=int((means[candidate]>means[control]).sum());sw=int((m.FinalError_candidate<m.FinalError_control).sum());sl=int((m.FinalError_candidate>m.FinalError_control).sum())
    ratio=(means[candidate].clip(lower=0)+1e-12)/(means[control].clip(lower=0)+1e-12);severe=ratio.gt(10)&means[candidate].gt(1e-8)&means[control].gt(1e-8)
    passed=8-fl>=4 and 40-sl>=20 and ranks[candidate]<ranks[control] and not severe.any()
    comparisons.append(dict(Candidate=candidate,Control=control,FunctionWins=fw,FunctionLosses=fl,FunctionTies=8-fw-fl,SeedWins=sw,SeedLosses=sl,SeedTies=40-sw-sl,MedianFunctionErrorRatio=float(ratio.median()),GeometricMeanFunctionErrorRatio=float(np.exp(np.log(ratio).mean())),MedianTimeRatio=float((m.Seconds_candidate/m.Seconds_control).median()),CandidateRank=float(ranks[candidate]),ControlRank=float(ranks[control]),SevereRegressionFunctions=','.join('F'+str(i) for i in means.index[severe]),ControlGate=bool(passed)))
c=pd.DataFrame(comparisons);c.to_csv(out/'comparisons.csv',index=False);pd.concat(paired,ignore_index=True).to_csv(out/'paired_runs.csv',index=False)
gates=[]
for candidate,route,required in [('Adapt-Q','A',[best_fixed,'Adapt-random','Adapt-phase','Adapt-epsfixed']),('Q-reset','B',['Rule-reset','Random-reset','EpsFixed-reset','Old-fixed6'])]:
    q=c[(c.Candidate==candidate)&c.Control.isin(required)];assert len(q)==4;gates.append(dict(Route=route,Candidate=candidate,RequiredControls=required,GatePassed=bool(q.ControlGate.all()),Rank=float(ranks[candidate])))
passing=[x for x in gates if x['GatePassed']];selected=None
if len(passing)==1:selected=passing[0]['Route']
elif len(passing)==2:selected='A' if gates[0]['Rank']<=gates[1]['Rank']+.25 else 'B'
(out/'selection_gate.json').write_text(json.dumps(dict(Routes=gates,SelectedRoute=selected,BestUnifiedAdaptFixed=best_fixed,NewRuns=520,ObjectiveCalls=int(raw.ObjectiveCalls.sum()),Scope='five-seed route development only; independent confirmation not yet run'),indent=2),encoding='utf-8')
raw.groupby('Condition')[['Seconds','PositiveRewardBlocks','Action1Share','Action2Share','Action3Share','QuotaFallbackRounds']].mean().to_csv(out/'policy_diagnostics.csv')
source=[]
for route,run in [('A',ra),('B',rb)]:
    for f in sorted((run/'source_snapshot').rglob('*')):
        if f.is_file():
            b=f.read_bytes();source.append(dict(Route=route,Path=str(f.relative_to(run/'source_snapshot')).replace('\\','/'),SHA256=hashlib.sha256(b).hexdigest(),SHA256NormalizedLF=hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()))
    shutil.copy2(run/'independent_artifact_checks.json',out/f'route_{route}_artifact_checks.json');shutil.copy2(run/'environment.json',out/f'route_{route}_environment.json')
for f in [Path(__file__),root/'experiments/verify_cso_two_routes.py',root/'data/cec2017/cec17_func.mexw64']:
    source.append(dict(Route='analysis',Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()))
(out/'source_manifest.json').write_text(json.dumps(dict(RouteARunDirectory=str(ra),RouteBRunDirectory=str(rb),Sources=source),ensure_ascii=False,indent=2),encoding='utf-8')
shutil.copy2(root/'work/cso_two_routes_20261012/shared_checks.json',out/'shared_behavior_checks.json');shutil.copy2(root/'work/cso_mode_q_reheat_20261012/behavior_checks.json',out/'linked_behavior_checks.json')
for pattern,label,n in [('cso_search_adapt_smoke_*','A',18),('cso_linked_radius_smoke_*','B',8)]:
    sm=sorted(ra.parent.glob(pattern))[-1];smr=pd.read_csv(sm/'raw_runs.csv');assert len(smr)==n and smr.Status.eq('ok').all();shutil.copy2(sm/'raw_runs.csv',out/f'route_{label}_smoke_runs.csv')
report=['# 两路线独立配对开发结果（2026-10-12）','', '520新run完成，D50/100k，八函数五新seed，52M真实预算内FE；520额外Best重查、A18/B8smoke单列。两路线共用InitSeed/SearchSeed，搜索轨迹可随方法分化。真实FE/状态/奖励/Q replay/半径与scale触发独立核验通过。','',f'整体13条件平均排名：{ranks.to_dict()}。','']
for g in gates:report.append(f"- 路线{g['Route']}：{g['Candidate']}，强控制开发门{'通过' if g['GatePassed'] else '未通过'}，rank={g['Rank']:.3f}。")
report.extend(['',f'依预写门选定路线：{selected or "无"}；统一适配中最强固定：{best_fixed}。','', 'A中Q仅配额，半径公式所有控制相同；B中action1在停滞时同时触发恢复，不能把两路线混称同一机制。若简单规则更强，不能宣称Q必要。五seed不是显著/非劣结论，全部条件公开。','', '过门后可冻结一条做独立新seed确认；都未过则报告不确定和失败，不马上扩半径网格或加Tracing。原算法/Old-Q结果完整保留。'])
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8');print(c.to_string(index=False));print(ranks.to_string());print(json.dumps(gates,indent=2));print('SELECTED',selected)
