"""Combine the 29-function confirmation with checked strong-baseline cache."""
from pathlib import Path
import argparse, json, hashlib, shutil
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon, friedmanchisquare
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run_directory',type=Path);p.add_argument('--skip-figures',action='store_true');a=p.parse_args();run=a.run_directory
cfg=json.loads((run/'config.json').read_text(encoding='utf-8'));status=json.loads((run/'status.json').read_text(encoding='utf-8'))
assert status['Status']=='complete' and status['SnapshotHashesVerified']
new=pd.read_csv(run/'raw_runs.csv');cache=pd.read_csv(run/'cache/cached_runs.csv')
assert len(new)==580 and len(cache)==1740 and new.Status.eq('ok').all() and cache.Status.eq('ok').all()
assert new.ObjectiveCalls.eq(100000).all() and new.Evaluations.eq(100000).all() and new.OutsideCalls.eq(0).all()
assert cache.ObjectiveCalls.eq(100000).all() and cache.Evaluations.eq(100000).all() and cache.OutsideCalls.eq(0).all()
methods=['ELS-Q','ELS-Replace','SAQ-CSO','HIDMS-PSO-IndexCorrected','DMS-PSO-SIS2005','HCLPSO-AuthorSource','HPSO-TVAC-CEC','SPSO-2011-OfficialC']
controls=methods[3:]
labels={'ELS-Q':'新Q版','ELS-Replace':'新规则版','SAQ-CSO':'原冻结SAQ-CSO',
 'HIDMS-PSO-IndexCorrected':'HIDMS-PSO','DMS-PSO-SIS2005':'DMS-PSO','HCLPSO-AuthorSource':'HCLPSO',
 'HPSO-TVAC-CEC':'HPSO-TVAC','SPSO-2011-OfficialC':'SPSO-2011'}
new=new.copy();new['FromCache']=False;new['ArtifactPath']=[str(run/'runs'/s) for s in new.Artifact]
raw=pd.concat([new,cache],ignore_index=True)
assert len(raw)==2320 and set(raw.Method)==set(methods)
assert raw.groupby(['FunctionID','Method']).size().eq(10).all()
assert set(raw.FunctionID)=={1,*range(3,31)} and set(raw.Seed)==set(range(3001,3011))
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Seed']).InitSeed.nunique().eq(1).all()
assert raw.groupby(['FunctionID','Seed']).SearchSeed.nunique().eq(1).all()
output=ROOT/'results/saq_strong_confirmation_29f_10seed_20261014';output.mkdir(parents=True,exist_ok=True)
figdir=output/'function_curves';figdir.mkdir(exist_ok=True)
raw.to_csv(output/'all_runs.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack()[methods]
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack()[methods]
medians=raw.groupby(['FunctionID','Method']).FinalError.median().unstack()[methods]
means.to_csv(output/'function_means.csv');std.to_csv(output/'function_stds.csv');medians.to_csv(output/'function_medians.csv')
ranks=means.rank(axis=1).mean().sort_values();ranks.rename('MeanErrorRank').to_csv(output/'mean_ranks.csv')
fmt=pd.DataFrame(index=means.index)
for method in methods:fmt[labels[method]]=[f'{x:.3e} ± {y:.3e}' for x,y in zip(means[method],std[method])]
fmt.to_csv(output/'mean_std_zh.csv')
base=raw[raw.Method.eq('ELS-Q')].set_index(['FunctionID','Seed']).FinalError
rows=[];summary=[]
def ratio_values(numerator,denominator):
    n=np.asarray(numerator,dtype=float);d=np.asarray(denominator,dtype=float)
    out=np.full_like(n,np.inf);np.divide(n,d,out=out,where=d!=0);out[(n==0)&(d==0)]=1
    return out
for control in methods[1:]:
    values=raw[raw.Method.eq(control)].set_index(['FunctionID','Seed']).FinalError.reindex(base.index)
    delta=base-values;ratio=ratio_values(means['ELS-Q'],means[control])
    summary.append({'Control':control,'MeanWins':int((means['ELS-Q']<means[control]).sum()),
      'MeanLosses':int((means['ELS-Q']>means[control]).sum()),'MeanTies':int((means['ELS-Q']==means[control]).sum()),
      'SeedWins':int((delta<0).sum()),'SeedLosses':int((delta>0).sum()),'SeedTies':int((delta==0).sum()),
      'MedianFunctionMeanRatio':float(np.median(ratio))})
    for fid in means.index:
        d=delta.loc[fid].to_numpy();pv=1.0 if np.all(d==0) else float(wilcoxon(d,zero_method='wilcox',method='auto').pvalue)
        rows.append({'FunctionID':int(fid),'Control':control,'QMean':float(means.loc[fid,'ELS-Q']),
          'ControlMean':float(means.loc[fid,control]),'MeanRatio':float(ratio_values([means.loc[fid,'ELS-Q']],[means.loc[fid,control]])[0]),
          'PairedSeedWins':int((d<0).sum()),'PairedSeedLosses':int((d>0).sum()),'PairedSeedTies':int((d==0).sum()),'WilcoxonP':pv})
comparisons=pd.DataFrame(rows);ps=comparisons.WilcoxonP.to_numpy();order=np.argsort(ps);padj=np.empty(len(ps));running=0
for k,i in enumerate(order):running=max(running,(len(ps)-k)*ps[i]);padj[i]=min(1,running)
comparisons['HolmAdjustedP']=padj
comparisons['CorrectedConclusion']=np.where(padj>=.05,'NS',np.where(comparisons.QMean<comparisons.ControlMean,'Q-better','Q-worse'))
comparisons.to_csv(output/'function_comparisons.csv',index=False)
for row in summary:
    sub=comparisons[comparisons.Control.eq(row['Control'])]
    row['HolmBetter']=int(sub.CorrectedConclusion.eq('Q-better').sum())
    row['HolmWorse']=int(sub.CorrectedConclusion.eq('Q-worse').sum())
    row['HolmNS']=int(sub.CorrectedConclusion.eq('NS').sum())
summary=pd.DataFrame(summary);summary.to_csv(output/'overall_comparisons.csv',index=False)
fr=friedmanchisquare(*[means[m].to_numpy() for m in methods])
cached_curves=pd.read_csv(run/'cache/cached_convergence_nodes.csv')
supplement=[]
for r in cache.itertuples():
    path=Path(r.ArtifactPath)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==r.ArtifactSHA256,'Cached MAT changed during confirmation'
    existing=set(cached_curves[(cached_curves.FunctionID==r.FunctionID)&(cached_curves.Seed==r.Seed)&(cached_curves.Method==r.Method)].FE)
    missing=set([10000,20000,40000,60000,80000,100000])-existing
    if missing:
        T=np.asarray(loadmat(path,variable_names=['T'],simplify_cells=True)['T']).reshape(-1)
        for fe in sorted(missing):
            supplement.append({'FunctionID':r.FunctionID,'Seed':r.Seed,'Method':r.Method,'FE':fe,'BestError':float(T[fe-1]-100*r.FunctionID)})
if supplement:cached_curves=pd.concat([cached_curves,pd.DataFrame(supplement)],ignore_index=True)
curves=pd.concat([pd.read_csv(run/'convergence_nodes.csv'),cached_curves],ignore_index=True)
assert not curves.duplicated(['FunctionID','Seed','Method','FE']).any()
# Nodes are actual trace reads; different grids are joined by their observed union.
curves.to_csv(output/'convergence_nodes.csv',index=False)
g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
phase=[];phase_rows=[];development={1,6,9,13,21,22,27,30}
for fid in means.index:
    best=means.loc[fid,controls].idxmin()
    q=[];c=[]
    for fe in [10000,20000,40000,60000,80000,100000]:
        # Exact requested checkpoints are added by the exporter/cache preparer.
        qvalue=float(g.loc[(fid,'ELS-Q',fe)]);cvalue=float(g.loc[(fid,best,fe)])
        q.append(qvalue);c.append(cvalue)
        phase_rows.append({'FunctionID':int(fid),'Control':best,'FE':fe,'QError':qvalue,'ControlError':cvalue,
          'MeanRatio':float(ratio_values([qvalue],[cvalue])[0])})
    ratios=ratio_values(q,c)
    tail=(q[-2]-q[-1])/q[-2] if q[-2]!=0 else 0.0
    dq=(means.loc[fid,'ELS-Q']-means.loc[fid,'ELS-Replace'])/means.loc[fid,'ELS-Replace'] if means.loc[fid,'ELS-Replace']!=0 else np.inf
    phase.append({'FunctionID':int(fid),'DevelopmentFunction':fid in development,'BestFinalControl':best,
      'Ratio10k':ratios[0],'Ratio20k':ratios[1],'Ratio40k':ratios[2],'Ratio60k':ratios[3],
      'Ratio80k':ratios[4],'Ratio100k':ratios[5],'QTail20kRelativeDrop':tail,'QOverRule100k':dq+1,
      'EarlyGapAt20k':bool(ratios[1]>1.2),'GapWidens20to60k':bool(ratios[3]>1.2*ratios[1]),
      'SmallTailDropBelow5Percent':bool(tail<.05),'StillImprovingTailOver20Percent':bool(tail>.2)})
phase=pd.DataFrame(phase);phase.to_csv(output/'phase_gap_diagnosis.csv',index=False)
pd.DataFrame(phase_rows).to_csv(output/'phase_gap_nodes.csv',index=False)
if not a.skip_figures:
    plt.rcParams.update({'font.family':'Microsoft YaHei','font.size':9,'axes.spines.top':False,
     'axes.spines.right':False,'axes.unicode_minus':False,'pdf.fonttype':42,'savefig.dpi':260})
    colors={'ELS-Q':'#1b9e77','ELS-Replace':'#d95f02','SAQ-CSO':'#303030','HIDMS-PSO-IndexCorrected':'#2166ac',
     'DMS-PSO-SIS2005':'#7570b3','HCLPSO-AuthorSource':'#e7298a','HPSO-TVAC-CEC':'#66a61e','SPSO-2011-OfficialC':'#a6761d'}
    fig,axes=plt.subplots(6,5,figsize=(17,19))
    for ax,fid in zip(axes.flat,means.index):
        for method in methods:
            series=g.loc[(fid,method)]
            ax.semilogy(series.index/1000,np.maximum(series.to_numpy(),1e-12),label=labels[method],color=colors[method],lw=1.2 if method in methods[:3] else .9)
        ax.set_title(f'F{fid}');ax.set_xlabel('评价次数（千）');ax.set_ylabel('平均最优误差');ax.grid(alpha=.12)
    axes.flat[-1].axis('off');handles,lbl=axes.flat[0].get_legend_handles_labels();fig.legend(handles,lbl,loc='lower center',ncol=4,frameon=False)
    fig.suptitle('CEC2017 强对照确认：29函数 / D50 / 100k / 10种子',fontsize=14)
    fig.tight_layout(rect=(0,.045,1,.98))
    for ext in ['png','pdf']:fig.savefig(output/f'all29_convergence.{ext}',bbox_inches='tight')
    plt.close(fig)
    for fid in means.index:
        fig,ax=plt.subplots(figsize=(7.4,4.5))
        for method in methods:
            series=g.loc[(fid,method)];ax.semilogy(series.index/1000,np.maximum(series.to_numpy(),1e-12),color=colors[method],label=labels[method],lw=1.6 if method in methods[:3] else 1)
        ax.set_title(f'F{fid}：D50 / 100k / 10种子');ax.set_xlabel('真实评价次数（千次）');ax.set_ylabel('平均最优误差（对数轴）');ax.grid(alpha=.15)
        ax.legend(frameon=False,fontsize=8,ncol=2);fig.tight_layout()
        fig.savefig(figdir/f'F{fid:02d}.png',bbox_inches='tight');fig.savefig(figdir/f'F{fid:02d}.pdf',bbox_inches='tight');plt.close(fig)
    worst=phase.sort_values('Ratio100k',ascending=False).head(8)
    fig,axes=plt.subplots(2,4,figsize=(12.5,6.6))
    for ax,row in zip(axes.flat,worst.itertuples()):
        for method in ['ELS-Q','ELS-Replace','SAQ-CSO',row.BestFinalControl]:
            series=g.loc[(row.FunctionID,method)];ax.semilogy(series.index/1000,np.maximum(series.to_numpy(),1e-12),color=colors[method],label=labels[method],lw=1.4)
        ax.set_title(f'F{row.FunctionID}  最终比值 {row.Ratio100k:.2g}');ax.set_xlabel('真实评价（千次）');ax.set_ylabel('平均最优误差');ax.grid(alpha=.12);ax.legend(frameon=False,fontsize=7)
    fig.suptitle('优先诊断的差距：每函数对照按最终均值事后选择',fontsize=12);fig.tight_layout(rect=(0,0,1,.95))
    for ext in ['png','pdf']:fig.savefig(output/f'largest_gaps.{ext}',bbox_inches='tight')
    plt.close(fig)
for name in ['run_diagnostics.csv','probe_diagnostics.csv','policy_state_diagnostics.csv','mode_gain_diagnostics.csv','delayed_credit_diagnostics.csv','config.json','prelaunch_hashes.csv','validation.json','SAQ_STRONG_CONFIRMATION_PROTOCOL_20261014.md']:
    if (run/name).exists():shutil.copy2(run/name,output/name)
shutil.copy2(run/'cache/cache_python_validation.json',output/'cache_python_validation.json')
shutil.copy2(run/'cache/cache_matlab_validation.json',output/'cache_matlab_validation.json')
manifest={'Date':'2026-10-14','RawDirectory':str(run),'NewRuns':580,'NewOptimizationCalls':58000000,
 'CachedRuns':1740,'TotalComparisonRows':2320,'CacheAuditCallsOutsideBudget':77140,
 'Functions':29,'Seeds':list(range(3001,3011)),'Methods':methods,
 'CorrectedTestFamily':'Q vs seven methods on 29 functions = 203 paired Wilcoxon tests, one Holm family',
 'BestControlChoice':'Posthoc minimum final mean among five PSO controls; descriptive stage diagnosis only',
 'PlotFloor':1e-12,'FriedmanStatistic':float(fr.statistic),'FriedmanP':float(fr.pvalue),'SmallestObservedWilcoxonP':float(ps.min()),'FirstHolmThreshold':.05/len(ps),
 'TenSeedTwoSidedExactMinimumP':2/(2**10),'Inputs':[]}
for path in [run/'raw_runs.csv',run/'cache/cached_runs.csv',run/'cache/cache_matlab_validation.json',run/'prelaunch_hashes.csv',Path(__file__)]:
    manifest['Inputs'].append({'Path':str(path),'SHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
analysis_source=output/'analysis_source';analysis_source.mkdir(exist_ok=True)
for source_path in [Path(__file__),ROOT/'experiments/diagnose_saq_strong_modes.py',ROOT/'experiments/export_saq_elite_probe_diagnostics.m']:
    shutil.copy2(source_path,analysis_source/source_path.name)
(output/'analysis_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# 29函数强对照确认结果（2026-10-14）','','D50/100k/10种子（3001–3010），新方法580次运行；核验后复用6个参照方法1740次。',
 '主对照包含HIDMS、DMS、HCLPSO及HPSO-TVAC/SPSO-2011，另含新规则版和原冻结SAQ-CSO。',
 'HIDMS使用已公开说明的索引修正版；DMS-SIS2005为已审计论文重构；保留各算法种群设置与共享初始化前缀。','',
 '| 新Q版相对 | 函数均值胜/负/平 | 配对种子胜/负/平 | 均值比中位数 | Holm显著更好/更差/未显著 |','|---|---:|---:|---:|---:|']
for r in summary.itertuples():
    lines.append(f'| {labels[r.Control]} | {r.MeanWins}/{r.MeanLosses}/{r.MeanTies} | {r.SeedWins}/{r.SeedLosses}/{r.SeedTies} | {r.MedianFunctionMeanRatio:.4g} | {r.HolmBetter}/{r.HolmWorse}/{r.HolmNS} |')
lines+=['',f'本轮最小逐函数P值为{ps.min():.6g}，203项Holm首项阈值为{.05/len(ps):.6g}；10种子两侧精确检验的最小P值为{2/(2**10):.6g}。该规模用于趋势与差距诊断，正式逐函数显著性判断需增加种子数。未显著不代表等效。']
lines+=['','## 平均秩','']+[f'- {labels[m]}：{ranks[m]:.4f}' for m in ranks.index]
lines+=['','## 阶段诊断','', 'phase_gap_diagnosis.csv 汇总10k/20k/40k/60k/80k/100k差距及尾段改善；largest_gaps图展示最大差距的8个函数。',
 '对照按各函数最终均值事后选择，用于观察差距所在阶段；不进入在线算法。误差曲线和多样性只能支持现象分析，不能单独证明因果或严格局部最优。',
 '8个开发函数与21个其余函数已分别标记；这轮10种子确认仍需要后续正式范围的稳定性判断。','',f'全部运行与MAT原件：{run}。']
(output/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(summary.to_string(index=False));print(ranks.to_string());print('Saved strong comparison:',output)
