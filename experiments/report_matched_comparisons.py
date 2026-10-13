"""Compact reporting for a predeclared method set and scientific contrasts.
No optimization and no choosing favorable functions. Intended for main-table
subsets and matched framework ablations; source/MAT checks are separate.
"""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon,friedmanchisquare
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def holm(values):
    p=np.asarray(values);ix=np.argsort(p);q=np.empty(len(p));q[ix]=np.minimum(1,np.maximum.accumulate(p[ix]*np.arange(len(p),0,-1)));return q

def report(raw,out,methods,contrasts,title,notes,curves=None):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    assert set(raw.Condition)==set(methods) and len(raw)==29*30*len(methods)
    assert raw.Status.eq('ok').all() and raw.Budget.eq(100000).all() and raw.ObjectiveCalls.eq(100000).all()
    assert raw.Dimension.eq(50).all() and not raw.duplicated(['FunctionID','Seed','Condition']).any()
    assert set(raw.FunctionID)==set([1]+list(range(3,31))) and set(raw.Seed)==set(range(3001,3031))
    raw.to_csv(out/'all_quality_runs.csv',index=False)
    summary=raw.groupby(['FunctionID','Condition']).agg(N=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),MeanSeconds=('Seconds','mean')).reset_index()
    assert summary.N.eq(30).all();summary.to_csv(out/'summary.csv',index=False)
    means=summary.pivot(index='FunctionID',columns='Condition',values='MeanError')[methods];rank=means.rank(axis=1).mean().sort_values()
    medians=summary.pivot(index='FunctionID',columns='Condition',values='MedianError')[methods]
    means.to_csv(out/'function_means.csv');medians.to_csv(out/'function_medians.csv');rank.rename('MeanErrorRank').to_csv(out/'mean_ranks.csv')
    std=summary.copy();std['MeanStd']=std.apply(lambda r:f'{r.MeanError:.4e} ± {r.StdError:.4e}',axis=1)
    std.pivot(index='FunctionID',columns='Condition',values='MeanStd').reindex(columns=methods).to_csv(out/'paper_mean_std.csv',encoding='utf-8-sig')
    tests=[]
    for cid,left,right,role in contrasts:
        a=raw[raw.Condition==left];b=raw[raw.Condition==right]
        paired=a.merge(b,on=['FunctionID','Seed'],suffixes=('_L','_R'),validate='one_to_one')
        for fid,g in paired.groupby('FunctionID'):
            diff=g.FinalError_L.to_numpy()-g.FinalError_R.to_numpy()
            pvalue=1. if np.all(diff==0) else float(wilcoxon(diff,zero_method='wilcox',correction=True,alternative='two-sided',method='approx').pvalue)
            tests.append({'Contrast':cid,'Role':role,'Left':left,'Right':right,'FunctionID':int(fid),'LeftMean':float(means.loc[fid,left]),'RightMean':float(means.loc[fid,right]),'MeanWinner':'Left' if means.loc[fid,left]<means.loc[fid,right] else 'Right' if means.loc[fid,left]>means.loc[fid,right] else 'Tie','SeedWins':int((diff<0).sum()),'SeedLosses':int((diff>0).sum()),'SeedTies':int((diff==0).sum()),'MedianPairedDifference':float(np.median(diff)),'PValue':pvalue})
    t=pd.DataFrame(tests);t['HolmAll']=holm(t.PValue);t['HolmWithinContrast']=t.groupby('Contrast').PValue.transform(lambda g:holm(g.to_numpy()))
    t['SignificantDirection']=np.where(t.HolmAll<.05,np.where(t.MedianPairedDifference<0,'Left-better','Right-better'),'NS');t.to_csv(out/'function_comparison.csv',index=False)
    counts=[]
    for cid,left,right,role in contrasts:
        z=t[t.Contrast==cid]
        counts.append({'Contrast':cid,'Role':role,'Left':left,'Right':right,'MeanWins':int(z.MeanWinner.eq('Left').sum()),'MeanLosses':int(z.MeanWinner.eq('Right').sum()),'MeanTies':int(z.MeanWinner.eq('Tie').sum()),'SeedWins':int(z.SeedWins.sum()),'SeedLosses':int(z.SeedLosses.sum()),'SeedTies':int(z.SeedTies.sum()),'HolmBetter':int(z.SignificantDirection.eq('Left-better').sum()),'HolmWorse':int(z.SignificantDirection.eq('Right-better').sum()),'HolmNS':int(z.SignificantDirection.eq('NS').sum())})
    counts=pd.DataFrame(counts);counts.to_csv(out/'overall_comparisons.csv',index=False)
    stat,pvalue=friedmanchisquare(*[means[c].to_numpy() for c in methods]);runtime=raw.groupby('Condition').Seconds.agg(['mean','median','std']);runtime.to_csv(out/'runtime.csv')
    stats={'PerFunction':'paired two-sided Wilcoxon, normal approximation, continuity/tie correction','HolmFamily':len(t),'SeedPairsPerFunction':30,'FriedmanBlocks':29,'FriedmanStatistic':float(stat),'FriedmanP':float(pvalue),'Contrasts':contrasts,'NoFunctionSelection':True}
    (out/'statistics_protocol.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2),encoding='utf-8')
    overview={'QualityRecords':len(raw),'Dimension':50,'Budget':100000,'Functions':29,'Seeds':30,'Methods':methods,'MeanRanks':rank.to_dict(),'Contrasts':counts.to_dict('records'),'Notes':notes}
    (out/'overall.json').write_text(json.dumps(overview,ensure_ascii=False,indent=2),encoding='utf-8')
    text=[f'# {title}','','CEC2017 D50、100k真实FE、29函数、30种子。均值票数与显著票数分开。','', '|方法|平均函数均值排名|平均秒/运行|','|---|---:|---:|']
    for c in rank.index:text.append(f'|{c}|{rank[c]:.3f}|{runtime.loc[c,"mean"]:.3f}|')
    text+=['','|比较（左vs右）|均值胜/负|配对seed胜/负|全族Holm显著好/差/NS|','|---|---|---|---|']
    for r in counts.itertuples():text.append(f'|{r.Left} vs {r.Right}|{r.MeanWins}/{r.MeanLosses}|{r.SeedWins}/{r.SeedLosses}|{r.HolmBetter}/{r.HolmWorse}/{r.HolmNS}|')
    text+=['',f'全比较族{len(t)}项Holm；Friedman以29函数均值为block，stat={stat:.6g},p={pvalue:.6g}，不是每个seed当独立问题。','']+notes
    (out/'REPORT.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
    colors={c:plt.get_cmap('tab10')(i) for i,c in enumerate(methods)}
    fig,ax=plt.subplots(figsize=(9,4.5));ax.barh(rank.index,rank.values,color=[colors[c] for c in rank.index]);ax.invert_yaxis();ax.set_xlim(0,len(methods)+.4);ax.set_xlabel('Average rank over 29 function means (lower is better)')
    for i,val in enumerate(rank):ax.text(val+.06,i,f'{val:.3f}',va='center')
    fig.tight_layout();fig.savefig(out/'mean_ranks.png',dpi=180);plt.close(fig)
    if curves is not None:
        curves=curves[curves.Condition.isin(methods)].copy();curves.to_csv(out/'convergence_nodes.csv',index=False)
        fig,axes=plt.subplots(6,5,figsize=(15,15))
        for ax,(fid,g) in zip(axes.flat,curves.groupby('FunctionID')):
            for c in methods:
                z=g[g.Condition==c];ax.semilogy(z.FE/1000,np.maximum(z.Error,1e-8),label=c,lw=1.2,color=colors[c])
            ax.set_title(f'F{fid}');ax.set_xlabel('True FE (thousands)');ax.set_ylabel('Mean error');ax.grid(alpha=.2)
        axes.flat[-1].axis('off');h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=3);fig.suptitle('CEC2017 D50, 100k true FE, 30 seeds; display floor1e-8');fig.tight_layout(rect=(0,.065,1,.975));fig.savefig(out/'all29_convergence.png',dpi=180);plt.close(fig)
    print(json.dumps(overview,ensure_ascii=False,indent=2))
    return overview
