"""Analyze the prespecified reward-only development pilot and its frozen controls."""
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
p=argparse.ArgumentParser();p.add_argument('run');args=p.parse_args()
run=Path(args.run);cfg=json.loads((run/'config.json').read_text(encoding='utf-8'))
assert json.loads((run/'status.json').read_text())['Status']=='complete'
out=ROOT/'results/saq_teacher_reward_10seed_20261014';out.mkdir(parents=True,exist_ok=True)
controls=['Fixed6','ELS-Replace','ELS-Random','ELS-Q'];newname='ELS-TeacherQ';methods=controls+[newname]
oldcfg=json.loads((run/'cache/config.json').read_text())
for key in ['FunctionIDs','Seeds','Dimension','Population','Budget','LowerBound','UpperBound','ProgressWindowFE','ProgressThreshold','EpisodeFE','SeedBase']:
    assert cfg[key]==oldcfg[key],key
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256,h.Path
new=pd.read_csv(run/'raw_runs.csv');old=pd.read_csv(run/'cache/all_runs.csv');old=old[old.Method.isin(controls)].copy()
assert len(new)==80 and len(old)==320 and new.Status.eq('ok').all() and old.Status.eq('ok').all()
raw=pd.concat([old,new],ignore_index=True)
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(5).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed','PolicySeed','ProbeSeed']].nunique().eq(1).all().all()
assert raw.Evaluations.eq(100000).all() and raw.ObjectiveCalls.eq(100000).all()
assert raw.OutsideCalls.eq(0).all()
# Check the archived CEC runtime and original engine match the validated reference.
validation=json.loads((run/'validation.json').read_text())
parent=ROOT/'results/cec'/Path(oldcfg['ParentRun']).name
assert parent.is_dir(), 'Archived parent run is missing'
for origin in [parent/'source/SAQ_CSO_EliteProbe.m',ROOT/'src/SAQ_CSO_EliteProbe.m']:
    assert hashlib.sha256(origin.read_bytes()).hexdigest()==validation['OriginalEngineSHA256']
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    hpath=Path(h.Path)
    if 'cec_data' in hpath.parts:
        rel=hpath.relative_to(run/'cec_data')
        assert hashlib.sha256((parent/'cec_data'/rel).read_bytes()).hexdigest()==h.SHA256
# Independent replay: both reward labels and Q updates, including terminal transition.
audit=[]
for row in new.itertuples():
    saved=loadmat(run/'runs'/row.Artifact,simplify_cells=True)
    I=saved['info'];w=np.atleast_2d(I['WindowLog']);u=np.atleast_2d(I['UpdateLog']);Q=np.zeros((6,2));visits=np.zeros((6,2))
    expected=np.where(np.maximum(0,w[:,12]-w[:,14])>=cfg['ProgressThreshold']*w[:,5],10,np.where((w[:,6]>0)&(w[:,18]>0),.5,-1))
    assert np.array_equal(w[:,15],expected)
    assert np.isclose(np.asarray(saved['T']).reshape(-1)[-1],row.FinalCost,rtol=1e-12,atol=1e-10)  # CSV uses fewer significant digits than MAT
    assert np.asarray(saved['T']).size==cfg['Budget']
    for update in u:
        ps,pa=int(update[0])-1,int(update[1])-1
        bootstrap=0.
        if update[4]==0:
            ix=np.flatnonzero(w[:,0]==update[6]);assert len(ix)==1
            allowed=[0,1] if w[ix[0],7]>0 else [0]
            bootstrap=.9**((update[6]-update[5])/100)*Q[int(update[3])-1,allowed].max()
        Q[ps,pa]+=.1*(update[2]+bootstrap-Q[ps,pa]);visits[ps,pa]+=1
    assert np.max(np.abs(Q-I['QTable']))<1e-12
    assert np.array_equal(visits,I['QVisits'])
    audit.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Passed=True,
                      ShapedWindows=int((expected==.5).sum()),ImprovedWindows=int((expected==10).sum()),
                      PenaltyWindows=int((expected==-1).sum()),QReplayMaxDiff=float(np.max(np.abs(Q-I['QTable'])))))
pd.DataFrame(audit).to_csv(out/'reward_q_audit.csv',index=False)
raw.to_csv(out/'all_runs.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');std.to_csv(out/'function_std.csv')
means.rank(axis=1).mean().sort_values().rename('AverageRank').to_csv(out/'mean_ranks.csv')
comparisons=[];detail=[]
for ref in controls:
    b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError
    v=raw[raw.Method.eq(newname)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index)
    d=v-b;ratio=means[newname]/means[ref]
    comparisons.append(dict(Reference=ref,MeanWins=int((ratio<1).sum()),MeanLosses=int((ratio>1).sum()),MeanTies=int((ratio==1).sum()),
                            MedianFunctionMeanRatio=float(ratio.median()),SeedWins=int((d<0).sum()),SeedLosses=int((d>0).sum()),SeedTies=int((d==0).sum())))
    for fid in means.index:
        delta=d.loc[fid].to_numpy()
        pv=1. if np.all(delta==0) else float(wilcoxon(delta,zero_method='wilcox',method='auto').pvalue)
        detail.append(dict(FunctionID=int(fid),Reference=ref,CandidateMean=float(means.loc[fid,newname]),ReferenceMean=float(means.loc[fid,ref]),
                           MeanRatio=float(ratio.loc[fid]),WilcoxonP=pv,SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),SeedTies=int((delta==0).sum())))
comp=pd.DataFrame(comparisons);comp.to_csv(out/'comparisons.csv',index=False)
detail=pd.DataFrame(detail);pv=detail.WilcoxonP.to_numpy();order=np.argsort(pv);adj=np.empty(len(pv));running=0.
for k,i in enumerate(order):
    running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
detail['HolmP']=adj;detail.to_csv(out/'function_comparisons.csv',index=False)
x=comp.set_index('Reference');health=means.loc[[1,13,30],newname]/means.loc[[1,13,30],'Fixed6']
base_ok=bool(x.loc['Fixed6','MeanWins']>=5 and x.loc['Fixed6','MedianFunctionMeanRatio']<=.95)
policy_ok=bool(all(x.loc[ref,'MeanWins']>=5 and x.loc[ref,'MedianFunctionMeanRatio']<=1 for ref in ['ELS-Replace','ELS-Random']))
health_ok=bool((health<=1).sum()>=2 and not (health>1.2).any())
preflight=pd.read_csv(run/'preflight.csv').iloc[0]
gate=dict(PreflightOptimizationCalls=int(preflight.ObjectiveCalls),PreflightAuditCalls=int(preflight.PostRunRecheckCalls),Passed=base_ok and policy_ok and health_ok,Fixed6Gate=base_ok,RuleAndRandomGate=policy_ok,HealthyGate=health_ok,
          FreshRuns=80,CachedRuns=320,OptimizationCallsFresh=int(new.ObjectiveCalls.sum()),AuditCallsFresh=int(new.PostRunRecheckCalls.sum()),
          QReplayPassed=80,IndependentConfirmation=False,Comparisons=comparisons)
(out/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf-8')
curves=pd.concat([pd.read_csv(run/'cache/convergence_nodes.csv'),pd.read_csv(run/'convergence_nodes.csv')],ignore_index=True)
curves=curves[curves.Method.isin(methods)]
assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
curves.to_csv(out/'convergence_nodes.csv',index=False)
states=pd.concat([pd.read_csv(run/'cache/policy_state_diagnostics.csv'),pd.read_csv(run/'policy_state_diagnostics.csv')],ignore_index=True)
states=states[states.Method.isin(methods)];states.to_csv(out/'policy_state_diagnostics.csv',index=False)
policy=states.groupby('Method')[['NormalChoicesWhenFeasible','ProbeChoicesWhenFeasible','FeasibleWindows']].sum()
policy['ProbeFractionWhenFeasible']=policy.ProbeChoicesWhenFeasible/policy.FeasibleWindows.clip(lower=1)
policy.to_csv(out/'policy_summary.csv')
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
colors={'Fixed6':'#333333','ELS-Replace':'#2166ac','ELS-Random':'#1b9e77','ELS-Q':'#9a83a6','ELS-TeacherQ':'#d6604d'}
labels={'Fixed6':'No probe','ELS-Replace':'Rule','ELS-Random':'Random','ELS-Q':'Previous Q','ELS-TeacherQ':'Teacher-reward Q'}
fig,axes=plt.subplots(2,4,figsize=(13,6.2));g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
for ax,fid in zip(axes.flat,means.index):
    for method in methods:
        series=g.loc[(fid,method)];ax.semilogy(series.index/1000,series.clip(lower=1e-12),color=colors[method],label=labels[method],lw=1.5 if method==newname else 1)
    ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
handles,ls=axes.flat[0].get_legend_handles_labels();fig.legend(handles,ls,loc='lower center',ncol=5,frameon=False)
fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
for name in ['config.json','validation.json','checks.csv','prelaunch_hashes.csv']:
    shutil.copyfile(run/name,out/name)
report=['# 教师启发奖励：单项修改开发实验（2026-10-14）','',
        'D50 / 100k真实评价 / 8函数 / 10种子（8101–8110），4 worker。新80次优化、复用320次对照；属于已有开发集合，不是独立确认。','',
        '固定6T/4S与既有单维精英探测，保留有效改善判定、状态、触发、搜索公式和学习参数；仅将奖励改为有效改善+10、低进展且实际执行探测但未有效改善+0.5、其余−1。这是教师式奖励塑形的适配，不是逐项复现。','',
        '| 新奖励Q相对 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 |',
        '|---|---:|---:|---:|']
for row in comparisons:
    report.append(f"| {labels[row['Reference']]} | {row['MeanWins']}/{row['MeanLosses']}/{row['MeanTies']} | {row['SeedWins']}/{row['SeedLosses']}/{row['SeedTies']} | {row['MedianFunctionMeanRatio']:.4f} |")
report += ['',f"预先记录的开发门：{'通过' if gate['Passed'] else '未通过'}。Fixed6条件={base_ok}；规则与随机条件={policy_ok}；健康函数条件={health_ok}。",
           '','胜负为均值描述，不是显著性票数。逐函数配对Wilcoxon及32项Holm校正见function_comparisons.csv；未显著不表示等效。',
           '',f"全部80条新轨迹的奖励标签与Q更新独立重放通过；新优化调用{gate['OptimizationCallsFresh']:,}，额外运行后复核调用{gate['AuditCallsFresh']:,}，两者分别计数。源码与CEC快照哈希一致。",
           '',f"新奖励Q可行动作窗口中的探测占比：{policy.loc[newname,'ProbeFractionWhenFeasible']:.2%}。+0.5是塑形奖励，不计作真实改善。动作占比本身不能证明学习有效。",'']
report += ['## 行为变化与下一步判断','',
           f"旧Q在可行动作窗口中的探测占比为{policy.loc['ELS-Q','ProbeFractionWhenFeasible']:.2%}，新奖励Q为{policy.loc[newname,'ProbeFractionWhenFeasible']:.2%}；塑形确实改变了动作分配，但没有取得相对规则或旧Q的总体均值优势。",
           '当前Q每100FE窗口至多影响1个探测评价，窗口奖励却来自整个窗口。这与老师让Q选择整代位置更新算子的作用范围不同。该结构差异可作为下一步假设，尚未被本次实验单独验证。',
           '停止调本候选奖励；如继续研究，应优先检验Q对搜索动作的作用范围，而不同时增加多个脱困机制。',
           f"性能实验之外另有预检优化调用{gate['PreflightOptimizationCalls']:,}、预检复核调用{gate['PreflightAuditCalls']:,}；合成正确性检查不计入性能表。",'']
report += ['## 最终函数均值','', '| FunctionID | '+' | '.join(methods)+' |', '|---|'+'---:|'*len(methods)]
for fid,row in means.iterrows():
    report.append('| '+str(fid)+' | '+' | '.join(f'{value:.5g}' for value in row)+' |')
report.append('')
if not gate['Passed']:
    report += ['本候选未通过预定门，停止扩大实验；不调奖励或删除负面函数补救。本轮不能支持“借鉴探索奖励就修好了Q”的结论。','']
else:
    report += ['本候选仅通过开发筛查；需新独立种子确认后才能判断稳定收益。','']
report += [f'原始MAT、源码与运行配置：{run}','']
(out/'REPORT.md').write_text('\n'.join(report),encoding='utf-8')
print(comp.to_string(index=False));print(json.dumps(gate,ensure_ascii=False,indent=2));print('Output:',out)
