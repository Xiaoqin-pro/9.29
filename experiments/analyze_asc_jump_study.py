"""Analyze three prespecified Jump controls without altering the tested ASC source."""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import wilcoxon,rankdata,friedmanchisquare
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run',type=Path);args=p.parse_args();run=args.run
cfg=json.loads((run/'config.json').read_text(encoding='utf8'));status=json.loads((run/'status.json').read_text(encoding='utf8'))
assert status['Status']=='complete' and status['Completed']==240
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256,h.Path
raw=pd.read_csv(run/'raw_runs.csv');methods=['Original','NoJump','LightJump'];funcs=[1,6,9,13,21,22,27,30]
assert len(raw)==240 and raw.Status.eq('ok').all() and raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all()
assert raw.OutsideCalls.eq(0).all() and raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all()
assert set(raw.FunctionID)==set(funcs) and set(raw.Seed)==set(range(5001,5011)) and set(raw.Method)==set(methods)
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(3).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed']].nunique().eq(1).all().all()
assert (raw.InitSeed==261013000+raw.FunctionID*10000+raw.Seed).all() and (raw.SearchSeed==raw.InitSeed+1000000).all()
out=ROOT/'results/asc_jump_study_10seed_20261015';out.mkdir(parents=True,exist_ok=True)
checks=[];node_rows=[];jump_rows=[];phase_rows=[];metric_rows=[];control_rows=[];p0s={};full_traces={};parameter_reference=None
nodes=np.unique(np.r_[50,1000,np.linspace(2000,100000,101).round().astype(int),10000,20000,40000,60000,80000,90000,100000])
for row in raw.itertuples():
    z=loadmat(run/'runs'/row.Artifact,simplify_cells=True);I=z['I'];B=z['B'];T=np.asarray(z['T']).reshape(-1);R=np.atleast_2d(I['RoundLog']);P=I['Parameters'];p0=np.atleast_2d(z['p0']);job=z['job']
    assert T.size==100000 and np.isfinite(T).all() and np.all(np.diff(T)<=0) and T[-1]==B['Cost']
    assert np.isclose(T[-1],row.FinalCost,rtol=1e-12,atol=1e-9) and np.isclose(row.FinalError,row.FinalCost-100*row.FunctionID,rtol=1e-12,atol=1e-9)
    assert I['Evaluations']==100000 and I['Seed']==row.SearchSeed and np.array_equal(I['InitialPopulation'],p0)
    assert p0.shape==(50,50) and np.all((p0>=-100)&(p0<=100))
    assert np.all((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100))
    for key in ['FunctionID','Seed','SearchSeed','InitSeed','Method','UseJump','JumpFraction']:assert job[key]==getattr(row,key)
    key=(row.FunctionID,row.Seed)
    if key not in p0s:p0s[key]=p0
    assert np.array_equal(p0s[key],p0)
    full_traces[(row.FunctionID,row.Seed,row.Method)]=T
    assert bool(P['useJump'])==(row.Method!='NoJump')
    assert P['jumpFraction']==(.1 if row.Method=='LightJump' else .5)
    assert P['jumpGens']==20 and P['jumpUnit']=='generation' and P['jumpProtectElites']==1
    assert P['traceBoostGain']==0 and P['useGroup']==0 and P['useOBL']==0 and P['useGaussBest']==0
    params={k:v for k,v in P.items() if k not in ['useJump','jumpFraction']}
    if parameter_reference is None:parameter_reference=params
    assert set(params)==set(parameter_reference)
    for key in params:assert np.array_equal(params[key],parameter_reference[key]),key
    assert R[0,0]==50 and R[-1,1]==100000 and np.all(R[1:,0]==R[:-1,1])
    assert np.array_equal(R[:,1]-R[:,0],R[:,2]) and np.all(R[:,2]==np.minimum(10,100000-R[:,0]))
    assert np.all(R[:,12]==R[:,2]) and np.all(R[:,10]+R[:,11]==50)
    assert R[:,2].sum()+50==100000 and len(R)==I['Rounds']
    # Reconstruct exact strict-improvement clock and Jump decision. The clock is reset by either progress or Jump.
    last=50;stall=0;smooth=0.;buffer=np.zeros(100);ptr=0;count=0
    for k,rr in enumerate(R):
        before,after=int(rr[0]),int(rr[1]);improved=T[after-1]<T[before-1]
        expected_seek=.2+.7*(1-smooth);expected_radius=.02+.18*(1-smooth)
        assert abs(rr[3]-expected_seek)<1e-12 and abs(rr[4]-expected_radius)<1e-12
        buffer[ptr]=int(improved);ptr=(ptr+1)%100;count=min(count+1,100);success=buffer[:count].sum()/count
        smooth=np.clip(smooth+.05*((1-success)-smooth),0,1)
        assert abs(rr[5]-smooth)<1e-12 and abs(rr[7]-success)<1e-12
        if improved:last=after;stall=0
        else:stall+=1
        should_jump=bool(P['useJump']) and after-last>=1000
        assert bool(rr[9])==should_jump
        if should_jump:stall=0;last=after
        assert rr[8]==stall
    events=np.flatnonzero(R[:,9]>0);assert len(events)==I['Jumps']==row.Jumps
    assert np.array_equal(events+1,np.asarray(I['JumpRounds']).reshape(-1))
    victims=0 if not P['useJump'] else max(1,int(np.floor((50-10)*P['jumpFraction']+.5)))
    active_events=R[events,1]<100000
    metric_rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,Jumps=int(I['Jumps']),
        FirstJumpFE=float(R[events[0],1]) if len(events) else np.nan,FinalBudgetJumps=int((~active_events).sum()),
        VictimsPerJump= victims,PositionResetsFromCode=int(victims*len(events)),PositionResetsWithRemainingBudget=int(victims*active_events.sum()),
        FinalRadius=float(I['FinalRadius']),FinalSeekingProbability=float(I['FinalSeekProb']),
        FinalSlowness=float(I['FinalSlowness']),Tail20kRelativeDrop=float((T[79999]-T[99999])/max(T[79999]-100*row.FunctionID,1e-300))))
    for idx in events:
        fe=int(R[idx,1]);end=min(100000,fe+1000)
        jump_rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,JumpFE=fe,VictimsFromCode=victims,
            Next1000FEObserved=end-fe,ObservedPostJumpGain=float(T[fe-1]-T[end-1]),TerminalNoSearch=fe==100000))
    for start,end in [(50,20000),(20000,60000),(60000,80000),(80000,100000)]:
        part=R[(R[:,0]>=start)&(R[:,1]<=end)]
        phase_rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,StartFE=start,EndFE=end,
            ErrorStart=float(T[start-1]-100*row.FunctionID),ErrorEnd=float(T[end-1]-100*row.FunctionID),
            RelativeDrop=float((T[start-1]-T[end-1])/max(T[start-1]-100*row.FunctionID,1e-300)),
            Jumps=int(part[:,9].sum()),MeanSeekProbability=part[:,3].mean(),MeanRadius=part[:,4].mean(),MeanSlowness=part[:,5].mean()))
    for fe in nodes:
        node_rows.append((row.FunctionID,row.Seed,row.Method,int(fe),float(T[fe-1]-100*row.FunctionID)))
    checks.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,Passed=True,SharedInitialization=True,ExactJumpDecision=True,AdaptiveParametersReplayed=True,BestMatches=True))
# Public seed-level outcomes and curve nodes retain negative results.
raw.to_csv(out/'all_runs.csv',index=False);pd.DataFrame(checks).to_csv(out/'integrity_checks.csv',index=False)
curves=pd.DataFrame(node_rows,columns=['FunctionID','Seed','Method','FE','BestError']);curves.to_csv(out/'convergence_nodes.csv',index=False)
metrics=pd.DataFrame(metric_rows);metrics.to_csv(out/'run_diagnostics.csv',index=False)
metrics.groupby(['FunctionID','Method'])[['Jumps','FirstJumpFE','PositionResetsFromCode','PositionResetsWithRemainingBudget','FinalBudgetJumps','FinalRadius','FinalSeekingProbability','FinalSlowness','Tail20kRelativeDrop']].mean().to_csv(out/'function_diagnostics.csv')
pd.DataFrame(jump_rows).to_csv(out/'jump_events.csv',index=False);phase=pd.DataFrame(phase_rows);phase.to_csv(out/'phase_runs.csv',index=False)
phase.groupby(['FunctionID','Method','StartFE','EndFE'])[['RelativeDrop','Jumps','MeanSeekProbability','MeanRadius','MeanSlowness']].mean().to_csv(out/'phase_summary.csv')
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
med=raw.groupby(['FunctionID','Method']).FinalError.median().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');std.to_csv(out/'function_std.csv');med.to_csv(out/'function_medians.csv')
ranks=means.rank(axis=1).mean().sort_values().rename('AverageRank');ranks.to_csv(out/'mean_ranks.csv')
comparisons=[];detail=[]
for method,ref in [('NoJump','Original'),('LightJump','Original'),('LightJump','NoJump')]:
    b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError
    a=raw[raw.Method.eq(method)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index);delta=a-b
    ratio=means[method]/means[ref]
    comparisons.append(dict(Method=method,Reference=ref,MeanWins=int((ratio<1).sum()),MeanLosses=int((ratio>1).sum()),MeanTies=int((ratio==1).sum()),
        MedianMeanRatio=float(ratio.median()),SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),SeedTies=int((delta==0).sum())))
    for fid in means.index:
        ds=delta.loc[fid].to_numpy();pv=1. if np.all(ds==0) else float(wilcoxon(ds,zero_method='wilcox',method='auto').pvalue);nz=ds[ds!=0]
        rb=0 if not len(nz) else float(np.sum(rankdata(abs(nz))*np.sign(-nz))/sum(rankdata(abs(nz))))
        detail.append(dict(FunctionID=int(fid),Method=method,Reference=ref,MethodMean=float(means.loc[fid,method]),ReferenceMean=float(means.loc[fid,ref]),
            MeanRatio=float(ratio.loc[fid]),WilcoxonP=pv,RankBiserial=rb,SeedWins=int((ds<0).sum()),SeedLosses=int((ds>0).sum()),SeedTies=int((ds==0).sum())))
comp=pd.DataFrame(comparisons);comp.to_csv(out/'comparisons.csv',index=False);detail=pd.DataFrame(detail)
pv=detail.WilcoxonP.to_numpy();order=np.argsort(pv);adj=np.empty(len(pv));running=0.
for k,idx in enumerate(order):running=max(running,(len(pv)-k)*pv[idx]);adj[idx]=min(1.,running)
detail['Holm24']=adj;detail.to_csv(out/'function_comparisons.csv',index=False)
# A priori confirmation gate, not a post hoc criterion selected from the results.
gates={}
for method in ['NoJump','LightJump']:
    row=comp[(comp.Method==method)&(comp.Reference=='Original')].iloc[0];ratio=means[method]/means.Original
    gates[method]={'Passed':bool(row.MeanWins>=5 and row.MedianMeanRatio<=.95 and (ratio<=1.2).all() and (ratio.loc[[6,9]]<=1.1).all()),
        'MeanWins':int(row.MeanWins),'MedianMeanRatio':float(row.MedianMeanRatio),'NoFunctionOver20PercentRegression':bool((ratio<=1.2).all()),
        'F6F9Within10Percent':bool((ratio.loc[[6,9]]<=1.1).all()),'WorstFunctionRatio':float(ratio.max())}
passed=[m for m in ['NoJump','LightJump'] if gates[m]['Passed']]
selected=min(passed,key=lambda m:(gates[m]['MedianMeanRatio'],0 if m=='NoJump' else 1)) if passed else None
pre=json.loads((run/'preflight.json').read_text(encoding='utf8'));val=json.loads((run/'validation.json').read_text(encoding='utf8'))
summary={'Passed':bool(passed),'SelectedForIndependentConfirmation':selected,'Candidates':gates,'FreshRuns':240,'CachedRuns':0,
    'FreshOptimizationCalls':int(raw.ObjectiveCalls.sum()),'FreshBestRecheckCalls':int(raw.PostRunRecheckCalls.sum()),
    'FullBudgetParityObjectiveCalls':pre['ObjectiveCalls'],'FullBudgetParityRecheckCalls':pre['RecheckCalls'],
    'ValidationObjectiveCalls':val['ValidationObjectiveCalls'],'ValidationBestRechecks':val['ValidationBestRechecks'],
    'IndependentFunctionValidation':False,'Seeds':cfg['Seeds'],'Functions':cfg['Functions']}
for path in [run,out]:(path/'gate_decision.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf8')
# Matched median-seed plots: chosen on Original only, not on candidate advantage.
curves.groupby(['FunctionID','Method','FE']).BestError.agg(['mean','median','std']).to_csv(out/'curve_summary.csv')
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9});colors={'Original':'#333333','NoJump':'#2166ac','LightJump':'#d6604d'}
g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
fig,axes=plt.subplots(2,4,figsize=(13,6.2))
for ax,fid in zip(axes.flat,funcs):
    for method in methods:
        z=g.loc[(fid,method)];ax.semilogy(z.index/1000,z.clip(lower=1e-12),label=method,color=colors[method],lw=1.4)
    ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=3,frameon=False);fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
fig,axes=plt.subplots(2,4,figsize=(13,6.2));selections=[]
for ax,fid in zip(axes.flat,funcs):
    rows=raw[raw.FunctionID.eq(fid)&raw.Method.eq('Original')].sort_values(['FinalError','Seed']);seed=int(rows.iloc[4].Seed);selections.append(dict(FunctionID=fid,Seed=seed,Rule='5th of 10 Original final errors ascending; paired across methods'))
    for method in methods:
        T=full_traces[(fid,seed,method)];ax.semilogy(nodes/1000,np.maximum(T[nodes-1]-100*fid,1e-12),label=method,color=colors[method],lw=1.2)
        js=pd.DataFrame(jump_rows);ev=js[(js.FunctionID==fid)&(js.Seed==seed)&(js.Method==method)].JumpFE.to_numpy(dtype=int) if len(js) else np.array([],dtype=int)
        if len(ev):ax.scatter(ev/1000,np.maximum(T[ev-1]-100*fid,1e-12),color=colors[method],s=7,marker='|')
    ax.set_title(f'F{fid} / seed{seed}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.grid(alpha=.17)
h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=3,frameon=False);fig.tight_layout(rect=(0,.045,1,1));fig.savefig(out/'paired_seed_jump_events.png',dpi=180,bbox_inches='tight');plt.close(fig)
pd.DataFrame(selections).to_csv(out/'paired_plot_seed_selection.csv',index=False)
raw.groupby('Method').agg(Runs=('Seed','size'),MeanSeconds=('Seconds','mean'),StdSeconds=('Seconds','std')).to_csv(out/'runtime.csv')
for name in ['config.json','validation.json','checks.csv','preflight.json','prelaunch_hashes.csv','PROTOCOL.md','completion_recovery.json']:shutil.copyfile(run/name,out/name)
(out/'source').mkdir(exist_ok=True)
for name in ['ASC_NoFarness.m','run_asc_jump_job.m','run_asc_jump_study.m']:shutil.copyfile(run/'source'/name,out/'source'/name)
report=['# ASC Jump强度实验（2026-10-15）','','D50/N50/100k真实评价、8个已知开发函数、10个新随机种子5001–5010、4worker。三组各80次，全部新运行。原ASC文件未修改，只覆盖已有Jump开关或比例。',
    '', '| 设置 | Jump开关 | 每次非精英比例 | 每次重置个体数 |','|---|---:|---:|---:|','| Original | 开 | 0.50 | 20 |','| NoJump | 关 | 不执行 | 0 |','| LightJump | 开 | 0.10 | 4 |',
    '', '| 比较 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 |','|---|---:|---:|---:|']
for c in comparisons:report.append(f"| {c['Method']} vs {c['Reference']} | {c['MeanWins']}/{c['MeanLosses']}/{c['MeanTies']} | {c['SeedWins']}/{c['SeedLosses']}/{c['SeedTies']} | {c['MedianMeanRatio']:.4f} |")
report+=['',f"进入独立确认的筛查：{selected if selected else '两候选均未通过，保留原参数'}。条件与PROTOCOL.md一致，未按结果修改。",'',
    '胜负为函数均值描述，24项Holm与配对效应量见function_comparisons.csv；10种子不足以把未显著解释为等效。新随机重复不代表未见函数验证。',
    '', '| FunctionID | Original | NoJump | LightJump |','|---:|---:|---:|---:|']
for fid,row in means.iterrows():report.append('| '+str(fid)+' | '+' | '.join(f'{v:.6g}' for v in row)+' |')
report+=['','## 诊断与完整性','', '优化已完成后，MATLAB读取哈希清单的列名失败；通过独立Python校验36项冻结输入和240份MAT后恢复完成状态，未重复优化或修改执行快照。source/保留实际执行代码；当前experiments/run_asc_jump_study.m已显式指定CSV分隔符。恢复记录见completion_recovery.json。',
    '每次目标调用由运行器独立计数并记录best-so-far，全部轨迹与算法返回T逐点完全相同；最优解另行重评，所有运行通过。低进展平滑状态、Jump触发时钟和计数从已保存轨迹独立重建。共享初始种群也逐对核验。',
    'Jump作用数是根据固定代码计算的重置次数，不是不同粒子数。末预算结束时Jump单列为没有后续搜索的事件，不把这些事件视为产生优化收益。Jump后1000FE收益仅为描述，不能从时序相关推导因果效果。',
    '改变Jump会改变之后随机数消耗和搜索轨迹；对照控制的是共同初始种子和所有非Jump参数，不声称三组候选在Jump之后仍一一相同。',
    '',f"正式优化{summary['FreshOptimizationCalls']:,}调用，返回解复核{summary['FreshBestRecheckCalls']:,}次；额外全预算原版轨迹回归{pre['ObjectiveCalls']:,}调用和{pre['RecheckCalls']}次重评；合成/CEC检查调用{val['ValidationObjectiveCalls']:,}加{val['ValidationBestRechecks']}次重评，均不计性能样本。",
    '', 'convergence.png展示全部8函数均值曲线；paired_seed_jump_events.png按原版第5顺位种子选择固定配对曲线（未按候选优势挑图），并标记Jump时点。',
    '',f'原始数据与冻结源码：{run}','']
(out/'REPORT.md').write_text(chr(10).join(report),encoding='utf8')
print(comp.to_string(index=False));print(means.round(5).to_string());print(json.dumps(summary,ensure_ascii=False,indent=2));print('Results:',out)
