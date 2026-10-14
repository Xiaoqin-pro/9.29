"""Audit and summarize the prespecified teacher-inspired 9x4 Seeking pilot."""
from pathlib import Path
import argparse, hashlib, json, shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import wilcoxon
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run');args=p.parse_args();run=Path(args.run)
cfg=json.loads((run/'config.json').read_text(encoding='utf8'));status=json.loads((run/'status.json').read_text(encoding='utf8'))
assert status['Status']=='complete' and status['Completed']==320
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256,h.Path
raw=pd.read_csv(run/'raw_runs.csv');assert len(raw)==320 and raw.Status.eq('ok').all()
assert raw.Evaluations.eq(100000).all() and raw.ObjectiveCalls.eq(100000).all() and raw.OutsideCalls.eq(0).all()
methods=['FO-Base','FO-Rule','FO-Random','FO-Q'];candidate='FO-Q';refs=methods[:-1]
assert set(raw.Method)==set(methods)
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(4).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed','PolicySeed','ProbeSeed']].nunique().eq(1).all().all()
out=ROOT/'results/saq_four_operator_10seed_20261014';out.mkdir(exist_ok=True,parents=True)
cachecfg=json.loads((run/'cache/config.json').read_text(encoding='utf8'));cacheparent=ROOT/'results/cec'/Path(cachecfg['ParentRun']).name
cached=pd.read_csv(run/'cache/all_runs.csv');cached=cached[cached.Method.eq('Fixed6')].set_index(['FunctionID','Seed'])
for key in ['FunctionIDs','Seeds','Dimension','Population','Budget','SeedBase']:
    assert cfg[key]==cachecfg[key],key
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    hp=Path(h.Path)
    if 'cec_data' in hp.parts:
        assert hashlib.sha256((cacheparent/'cec_data'/hp.relative_to(run/'cec_data')).read_bytes()).hexdigest()==h.SHA256
checks=[]
for row in raw.itertuples():
    saved=loadmat(run/'runs'/row.Artifact,simplify_cells=True);I=saved['info'];T=np.asarray(saved['T']).reshape(-1)
    w=np.atleast_2d(I['WindowLog']);Q=np.zeros((9,4));visits=np.zeros_like(Q);stall=0
    assert len(T)==100000 and np.isfinite(T).all() and (np.diff(T)<=0).all()
    assert np.isclose(T[-1],row.FinalCost,rtol=1e-12,atol=1e-10)
    assert int(I['EscapeEvaluations'])==w[:,18].sum()
    assert np.sum(I['OperatorFE'])==I['SeekingEvaluations']
    for k in range(len(w)):
        if k:
            previous_gain=max(0,w[k-1,12]-w[k-1,14])
            stall=0 if previous_gain>=1e-4*w[k-1,5] else stall+1
        assert w[k,4]==stall
        stagnation=1+int(stall>0)+int(stall>=10)
        progress=(w[k,0]-50)/(100000-50)
        phase=1+int(progress>=.3)+int(progress>=.7)
        assert w[k,3]==phase and w[k,2]==3*(phase-1)+stagnation
        assert w[k,6]==int(stagnation==3)
        gain=max(0,w[k,12]-w[k,14]);expected=-1
        if gain>=1e-4*w[k,5]:expected=10
        elif stagnation==3 and w[k,9]>=3 and w[k,18]>0:expected=.5
        assert w[k,15]==expected
        assert 1<=w[k,9]<=4
    if I['EscapeEvaluations']:
        el=np.atleast_2d(I['EscapeLog']);pts=np.atleast_2d(I['EscapePoints'])
        assert len(el)==I['EscapeEvaluations'] and np.isin(el[:,3],[2,3,4]).all()
        assert np.all((pts>=-100)&(pts<=100))
        assert np.array_equal(T[el[:,0].astype(int)-1]<el[:,7],el[:,9]>0)
        assert np.array_equal(w[el[:,1].astype(int)-1,9],el[:,3])
        assert np.array_equal(np.bincount(el[:,1].astype(int),minlength=len(w)+1)[1:],w[:,18])
        assert np.array_equal(np.bincount(el[:,3].astype(int),minlength=5)[2:],np.asarray(I['OperatorFE'])[1:])
    if row.Policy=='q':
        for u in np.atleast_2d(I['UpdateLog']):
            ps,pa=int(u[0])-1,int(u[1])-1;boot=0
            if u[4]==0:
                ix=np.flatnonzero(w[:,0]==u[6]);assert len(ix)==1
                allowed=list(range(4)) if w[ix[0],7]>0 else [0]
                boot=.9**((u[6]-u[5])/100)*Q[int(u[3])-1,allowed].max()
            Q[ps,pa]+=.1*(u[2]+boot-Q[ps,pa]);visits[ps,pa]+=1
        assert I['QUpdates']==len(w)
    assert np.max(np.abs(Q-I['QTable']))<1e-12 and np.array_equal(visits,I['QVisits'])
    equivalent=False
    if row.Method=='FO-Base':
        c=cached.loc[(row.FunctionID,row.Seed)]
        for col in ['InitSeed','SearchSeed','PolicySeed','ProbeSeed']:assert getattr(row,col)==c[col]
        old=loadmat(cacheparent/'runs'/c.Artifact,simplify_cells=True)
        assert np.array_equal(T,np.asarray(old['T']).reshape(-1))
        assert np.array_equal(saved['state']['initialPopulation'],old['state']['initialPopulation'])
        assert saved['Best']['Cost']==old['Best']['Cost'] and np.array_equal(saved['Best']['Vector'],old['Best']['Vector'])
        equivalent=True
    checks.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,Passed=True,BaseExactCacheEquivalent=equivalent,
                       QReplayMaxDiff=float(np.max(np.abs(Q-I['QTable']))),SevereWindows=int(w[:,6].sum()),ShapedWindows=int((w[:,15]==.5).sum())))
pd.DataFrame(checks).to_csv(out/'integrity_checks.csv',index=False)
raw.to_csv(out/'all_runs.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');std.to_csv(out/'function_std.csv')
means.rank(axis=1).mean().sort_values().rename('AverageRank').to_csv(out/'mean_ranks.csv')
comp=[];detail=[]
for ref in refs:
    b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError
    v=raw[raw.Method.eq(candidate)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index);d=v-b
    ratio=means[candidate]/means[ref]
    comp.append(dict(Reference=ref,MeanWins=int((ratio<1).sum()),MeanLosses=int((ratio>1).sum()),MeanTies=int((ratio==1).sum()),
                     MedianMeanRatio=float(ratio.median()),SeedWins=int((d<0).sum()),SeedLosses=int((d>0).sum()),SeedTies=int((d==0).sum())))
    for fid in means.index:
        delta=d.loc[fid].to_numpy();pv=1. if np.all(delta==0) else float(wilcoxon(delta,zero_method='wilcox',method='auto').pvalue)
        detail.append(dict(FunctionID=int(fid),Reference=ref,Candidate=candidate,CandidateMean=float(means.loc[fid,candidate]),ReferenceMean=float(means.loc[fid,ref]),
                           MeanRatio=float(ratio.loc[fid]),WilcoxonP=pv,SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),SeedTies=int((delta==0).sum())))
comp=pd.DataFrame(comp);comp.to_csv(out/'comparisons.csv',index=False);detail=pd.DataFrame(detail)
pv=detail.WilcoxonP.to_numpy();order=np.argsort(pv);adj=np.empty(len(pv));running=0.
for k,i in enumerate(order):running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
detail['HolmP']=adj;detail.to_csv(out/'function_comparisons.csv',index=False)
x=comp.set_index('Reference');healthy=means.loc[[1,13,30],candidate]/means.loc[[1,13,30],'FO-Base']
base_ok=bool(x.loc['FO-Base','MeanWins']>=5 and x.loc['FO-Base','MedianMeanRatio']<=.95)
health_ok=bool((healthy<=1).sum()>=2 and not (healthy>1.2).any())
policy_ok=bool(all(x.loc[ref,'MeanWins']>=5 and x.loc[ref,'MedianMeanRatio']<=1 for ref in ['FO-Rule','FO-Random']))
pre=pd.read_csv(run/'preflight.csv').iloc[0]
gate=dict(Passed=base_ok and health_ok and policy_ok,BaseGate=base_ok,HealthyGate=health_ok,PolicyGate=policy_ok,
          FreshRuns=320,FreshOptimizationCalls=int(raw.ObjectiveCalls.sum()),AuditCalls=int(raw.PostRunRecheckCalls.sum()),
          PreflightOptimizationCalls=int(pre.ObjectiveCalls),PreflightAuditCalls=int(pre.PostRunRecheckCalls),
          ExactBaseCacheChecks=80,IndependentConfirmation=False,Comparisons=comp.to_dict('records'))
for directory in [out,run]:(directory/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf-8')
curves=pd.read_csv(run/'convergence_nodes.csv');states=pd.read_csv(run/'policy_state_diagnostics.csv');runs=pd.read_csv(run/'run_diagnostics.csv')
for name,df in [('convergence_nodes.csv',curves),('policy_state_diagnostics.csv',states),('run_diagnostics.csv',runs)]:df.to_csv(out/name,index=False)
policy=states.groupby(['Method','Action'])[['Windows','SeekingFE','AlternativeFE','QVisits']].sum();policy.to_csv(out/'policy_summary.csv')
policy_function=states.groupby(['FunctionID','Method','Action'])[['Windows','SeekingFE','AlternativeFE','QVisits']].sum()
policy_function.to_csv(out/'policy_by_function.csv')
phase=[]
for (fid,method),group in curves.groupby(['FunctionID','Method']):
    wide=group.pivot(index='Seed',columns='FE',values='BestError')
    for start,end in [(20000,40000),(40000,60000),(60000,80000),(80000,100000)]:
        a=wide[start].mean();b=wide[end].mean()
        phase.append(dict(FunctionID=int(fid),Method=method,StartFE=start,EndFE=end,StartMeanError=float(a),EndMeanError=float(b),RelativeDrop=float((a-b)/max(a,np.finfo(float).tiny))))
pd.DataFrame(phase).to_csv(out/'phase_progress.csv',index=False)
context=pd.read_csv(run/'cache/all_runs.csv')
context=context[context.Method.isin(['ELS-Replace','ELS-Q'])].groupby(['FunctionID','Method']).FinalError.mean().unstack()
context.join(means).to_csv(out/'historical_probe_context.csv')
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
colors={'FO-Base':'#333333','FO-Rule':'#2166ac','FO-Random':'#1b9e77','FO-Q':'#d6604d'}
fig,axes=plt.subplots(2,4,figsize=(13,6.2));g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
for ax,fid in zip(axes.flat,means.index):
    for m in methods:
        series=g.loc[(fid,m)];ax.semilogy(series.index/1000,series.clip(lower=1e-12),color=colors[m],label=m,lw=1.5)
    ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
handles,ls=axes.flat[0].get_legend_handles_labels();fig.legend(handles,ls,loc='lower center',ncol=4,frameon=False)
fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
for name in ['config.json','validation.json','checks.csv','prelaunch_hashes.csv']:shutil.copyfile(run/name,out/name)
report=['# 四算子Seeking调度开发结果（2026-10-14）','',
        'D50/100k真实评价，8函数×10个开发种子8101–8110，4 worker。3阶段×3停滞状态，4个Seeking动作：常规、同伴差分、高斯、部分坐标反向。只在Seeking使用；不是老师原PSO的逐项复现。',
        '',f'320次新运行、32M真实优化调用。额外复核调用{gate["AuditCalls"]:,}，另有预检优化{gate["PreflightOptimizationCalls"]:,}、预检复核{gate["PreflightAuditCalls"]:,}。',
        '', '| Q相对 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 |','|---|---:|---:|---:|']
for c in comp.to_dict('records'):report.append(f"| {c['Reference']} | {c['MeanWins']}/{c['MeanLosses']}/{c['MeanTies']} | {c['SeedWins']}/{c['SeedLosses']}/{c['SeedTies']} | {c['MedianMeanRatio']:.4f} |")
report += ['',f"预定开发门：{'通过' if gate['Passed'] else '未通过'}。Base={base_ok}；健康函数={health_ok}；规则/随机调度={policy_ok}。",'',
           '11项合成正确性检查通过。320条运行的状态、奖励、Q更新、动作实评与真实成本复核通过。普通版80条轨迹与旧Fixed6逐点轨迹、初始群体和Best精确一致。',
           '', '胜负是均值描述；逐函数配对Wilcoxon及24项Holm见function_comparisons.csv。已知开发函数与种子不是独立确认。',
           '', '| FunctionID | '+' | '.join(methods)+' |','|---|'+'---:|'*len(methods)]
for fid,row in means.iterrows():report.append('| '+str(fid)+' | '+' | '.join(f'{value:.5g}' for value in row)+' |')
report += ['', '## 动作实评与状态选择','',
           'policy_summary.csv和policy_by_function.csv分别记录各动作的窗口数与真实Seeking评价数。run_diagnostics.csv包含各动作观察到的全局改善次数；不同动作处于不同状态，不能把改善率直接解释为动作因果优劣。',
           'phase_progress.csv记录20k之后分段进展，避免把最终误差差距全部归为局部停滞。','']
report += ['', '历史单点探测对照见historical_probe_context.csv，是多项机制包差异的描述性比较，不单独归因于四动作。',
           '', '成功需独立新种子确认；失败则停止此批，不能通过删除函数、修改门或调奖励补救。',f'本地原始MAT与代码快照：{run}','']
(out/'REPORT.md').write_text('\n'.join(report),encoding='utf-8')
print(comp.to_string(index=False));print(json.dumps(gate,ensure_ascii=False,indent=2));print('Output:',out)
