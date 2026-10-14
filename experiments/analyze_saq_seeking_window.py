"""Frozen protocol analysis for whole-window Seeking operator selection."""
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
cfg=json.loads((run/'config.json').read_text());stage=cfg['Stage']
assert json.loads((run/'status.json').read_text())['Status']=='complete'
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256
new=pd.read_csv(run/'raw_runs.csv');assert len(new)==160 and new.Status.eq('ok').all()
assert new.Evaluations.eq(100000).all() and new.ObjectiveCalls.eq(100000).all() and new.OutsideCalls.eq(0).all()
if stage=='mechanism':
    raw=new;methods=['SW-Base','SW-Rule'];candidate='SW-Rule';refs=['SW-Base']
else:
    parent=ROOT/'results/cec'/Path(cfg['ParentRun']).name
    assert json.loads((parent/'gate_decision.json').read_text())['Passed']
    oldcfg=json.loads((parent/'config.json').read_text())
    for k in ['FunctionIDs','Seeds','Dimension','Population','Budget','ProgressWindowFE','ProgressThreshold','EpisodeFE','SeedBase']:
        assert cfg[k]==oldcfg[k]
    assert hashlib.sha256((run/'source/SAQ_CSO_SeekingWindow.m').read_bytes()).digest()==hashlib.sha256((parent/'source/SAQ_CSO_SeekingWindow.m').read_bytes()).digest()
    raw=pd.concat([pd.read_csv(parent/'raw_runs.csv'),new],ignore_index=True)
    methods=['SW-Base','SW-Rule','SW-Random','SW-Q'];candidate='SW-Q';refs=methods[:-1]
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(len(methods)).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed','PolicySeed','ProbeSeed']].nunique().eq(1).all().all()
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
out=ROOT/f'results/saq_seeking_window_{stage}_10seed_20261014';out.mkdir(exist_ok=True,parents=True)
audit=[]
# Historical no-probe traces are reused only to verify the newly executed base.
cached=pd.read_csv(run/'cache/all_runs.csv');cached=cached[cached.Method.eq('Fixed6')].set_index(['FunctionID','Seed'])
cachecfg=json.loads((run/'cache/config.json').read_text());cacheparent=ROOT/'results/cec'/Path(cachecfg['ParentRun']).name
for k in ['FunctionIDs','Seeds','Dimension','Population','Budget','ProgressWindowFE','ProgressThreshold','EpisodeFE','SeedBase']:
    assert cfg[k]==cachecfg[k]
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    hp=Path(h.Path)
    if 'cec_data' in hp.parts:
        assert hashlib.sha256((cacheparent/'cec_data'/hp.relative_to(run/'cec_data')).read_bytes()).hexdigest()==h.SHA256
for row in new.itertuples():
    saved=loadmat(run/'runs'/row.Artifact,simplify_cells=True);I=saved['info'];T=np.asarray(saved['T']).reshape(-1)
    w=np.atleast_2d(I['WindowLog']);Q=np.zeros((6,2));visits=np.zeros_like(Q)
    expected=np.where(np.maximum(0,w[:,12]-w[:,14])>=cfg['ProgressThreshold']*w[:,5],10,np.where((w[:,6]>0)&(w[:,18]>0),.5,-1))
    assert np.array_equal(w[:,15],expected)
    assert len(T)==100000 and np.isfinite(T).all() and (np.diff(T)<=0).all()
    assert np.isclose(T[-1],row.FinalCost,rtol=1e-12,atol=1e-10)
    assert int(I['EscapeEvaluations'])==w[:,18].sum()
    if int(I['EscapeEvaluations']):
        el=np.atleast_2d(I['EscapeLog']);pts=np.atleast_2d(I['EscapePoints']);bases=np.atleast_2d(I['EscapeBases'])
        assert len(el)==I['EscapeEvaluations']
        dims=el[:,3].astype(int)-1
        mask=np.ones_like(pts,dtype=bool);mask[np.arange(len(pts)),dims]=False
        assert np.array_equal(pts[mask],bases[mask])
        assert np.all((pts>=-100)&(pts<=100))
        assert np.array_equal(T[el[:,0].astype(int)-1]<el[:,7],el[:,9]>0)
        for window,number in enumerate(w[:,18],1):
            assert (el[:,1]==window).sum()==number
    if row.Policy=='q' and I['QUpdates']:
        for u in np.atleast_2d(I['UpdateLog']):
            ps,pa=int(u[0])-1,int(u[1])-1;boot=0.
            if u[4]==0:
                ix=np.flatnonzero(w[:,0]==u[6]);assert len(ix)==1
                allowed=[0,1] if w[ix[0],7]>0 else [0]
                boot=.9**((u[6]-u[5])/100)*Q[int(u[3])-1,allowed].max()
            Q[ps,pa]+=.1*(u[2]+boot-Q[ps,pa]);visits[ps,pa]+=1
    assert np.max(np.abs(Q-I['QTable']))<1e-12 and np.array_equal(visits,I['QVisits'])
    equivalent=False
    if row.Method=='SW-Base':
        c=cached.loc[(row.FunctionID,row.Seed)]
        for col in ['InitSeed','SearchSeed','PolicySeed','ProbeSeed']:assert getattr(row,col)==c[col]
        old=loadmat(cacheparent/'runs'/c.Artifact,simplify_cells=True)
        assert np.array_equal(T,np.asarray(old['T']).reshape(-1))
        assert np.array_equal(saved['state']['initialPopulation'],old['state']['initialPopulation'])
        assert saved['Best']['Cost']==old['Best']['Cost'] and np.array_equal(saved['Best']['Vector'],old['Best']['Vector'])
        equivalent=True
    audit.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,Passed=True,
                      BaseExactCacheEquivalent=equivalent,EscapeFE=int(I['EscapeEvaluations']),
                      MaxEscapeFEPerWindow=int(w[:,18].max()),ImprovedWindows=int((expected==10).sum()),ShapedWindows=int((expected==.5).sum()),
                      QReplayMaxDiff=float(np.max(np.abs(Q-I['QTable'])))))
pd.DataFrame(audit).to_csv(out/'integrity_checks.csv',index=False)
raw.to_csv(out/'all_runs.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');std.to_csv(out/'function_std.csv')
context=pd.read_csv(run/'cache/all_runs.csv')
context=context[context.Method.isin(['ELS-Replace','ELS-Q'])].groupby(['FunctionID','Method']).FinalError.mean().unstack()
context.join(means).to_csv(out/'historical_probe_context.csv')  # descriptive package comparison only
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
x=comp.set_index('Reference');h=means.loc[[1,13,30],candidate]/means.loc[[1,13,30],'SW-Base']
base_ok=bool(x.loc['SW-Base','MeanWins']>=5 and x.loc['SW-Base','MedianMeanRatio']<=.95)
health_ok=bool((h<=1).sum()>=2 and not (h>1.2).any())
policy_ok=True if stage=='mechanism' else bool(all(x.loc[ref,'MeanWins']>=5 and x.loc[ref,'MedianMeanRatio']<=1 for ref in ['SW-Rule','SW-Random']))
pre=pd.read_csv(run/'preflight.csv').iloc[0]
gate=dict(Passed=base_ok and health_ok and policy_ok,Stage=stage,BaseGate=base_ok,HealthyGate=health_ok,PolicyGate=policy_ok if stage=='policy' else None,
          FreshRuns=160,FreshOptimizationCalls=int(new.ObjectiveCalls.sum()),AuditCalls=int(new.PostRunRecheckCalls.sum()),
          PreflightOptimizationCalls=int(pre.ObjectiveCalls),PreflightAuditCalls=int(pre.PostRunRecheckCalls),
          ExactBaseCacheChecks=80 if stage=='mechanism' else 0,IndependentConfirmation=False,Comparisons=comp.to_dict('records'))
for directory in [out,run]:(directory/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf-8')
curves=pd.read_csv(run/'convergence_nodes.csv');states=pd.read_csv(run/'policy_state_diagnostics.csv')
if stage=='policy':
    curves=pd.concat([pd.read_csv(parent/'convergence_nodes.csv'),curves],ignore_index=True)
    states=pd.concat([pd.read_csv(parent/'policy_state_diagnostics.csv'),states],ignore_index=True)
curves.to_csv(out/'convergence_nodes.csv',index=False);states.to_csv(out/'policy_state_diagnostics.csv',index=False)
pol=states.groupby('Method')[['NormalChoicesWhenFeasible','ProbeChoicesWhenFeasible','FeasibleWindows']].sum()
pol['EscapeActionFraction']=pol.ProbeChoicesWhenFeasible/pol.FeasibleWindows.clip(lower=1);pol.to_csv(out/'policy_summary.csv')
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
colors={'SW-Base':'#333333','SW-Rule':'#2166ac','SW-Random':'#1b9e77','SW-Q':'#d6604d'}
fig,axes=plt.subplots(2,4,figsize=(13,6.2));g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
for ax,fid in zip(axes.flat,means.index):
    for m in methods:
        series=g.loc[(fid,m)];ax.semilogy(series.index/1000,series.clip(lower=1e-12),color=colors[m],label=m,lw=1.5)
    ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
handles,ls=axes.flat[0].get_legend_handles_labels();fig.legend(handles,ls,loc='lower center',ncol=len(methods),frameon=False)
fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
for name in ['config.json','validation.json','checks.csv','prelaunch_hashes.csv']:shutil.copyfile(run/name,out/name)
report=[f'# Seeking窗口算子切换：{stage}阶段（2026-10-14）','',
        'D50/100k真实评价，8函数×10个开发种子8101–8110，4 worker。常规Seeking或gbest单维高斯扰动，动作持续100FE；同一几何筛选和贪心接受，未追加保护探测/再播种。',
        '',f'本阶段160次新运行、16M真实优化调用。额外复核调用{gate["AuditCalls"]:,}，另有预检优化{gate["PreflightOptimizationCalls"]:,}、预检复核{gate["PreflightAuditCalls"]:,}。',
        '', '| 对照 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 |','|---|---:|---:|---:|']
for c in comp.to_dict('records'):report.append(f"| {c['Reference']} | {c['MeanWins']}/{c['MeanLosses']}/{c['MeanTies']} | {c['SeedWins']}/{c['SeedLosses']}/{c['SeedTies']} | {c['MedianMeanRatio']:.4f} |")
report += ['',f"预定开发门：{'通过' if gate['Passed'] else '未通过'}。Base={base_ok}；健康函数={health_ok}；调度对照={'尚未运行' if stage=='mechanism' else policy_ok}。",'',
           '所有运行的奖励标签、单维结构、实际计数和真实成本复核通过。Q更新重放仅适用于调度阶段；本次机制阶段未运行Q。普通版80条轨迹与旧Fixed6逐点评价轨迹、初始群体和Best精确一致（仅机制阶段）。',
           '', '胜负是描述性均值比较；逐函数配对Wilcoxon及全族Holm见function_comparisons.csv。已知开发函数与种子不是独立确认。',
           '', '| FunctionID | '+' | '.join(methods)+' |','|---|'+'---:|'*len(methods)]
for fid,row in means.iterrows():report.append('| '+str(fid)+' | '+' | '.join(f'{value:.5g}' for value in row)+' |')
report += ['', '机制阶段可见F1/F13改善，F6/F9恶化；8项Holm校正后F1/F13显著更好、F6/F9显著更差。不能将这种两极表现概括为整体解决了局部最优。' if stage=='mechanism' else '', '', 'historical_probe_context.csv另列此前单点评价探测规则版/旧Q，属于机制包差异的描述性比较，不能把差异单独归因于动作作用范围。', '', '机制阶段未通过则停止，不能靠接Q或调奖励把无效动作包装成改进。调度阶段未通过则不进入新种子确认。','',f'本地原始MAT与代码快照：{run}','']
(out/'REPORT.md').write_text('\n'.join(report),encoding='utf-8')
print(comp.to_string(index=False));print(json.dumps(gate,ensure_ascii=False,indent=2));print('Output:',out)
