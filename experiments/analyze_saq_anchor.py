"""Analyze the anchor-discrepancy screening pilot with frozen controls."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run');a=p.parse_args();run=Path(a.run)
cfg=json.loads((run/'config.json').read_text(encoding='utf8'))
assert cfg['Stage']=='anchor' and cfg['Budget']==100000 and cfg['Dimension']==50
assert json.loads((run/'status.json').read_text(encoding='utf8'))['Status']=='complete'
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
    assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256
new=pd.read_csv(run/'raw_runs.csv');assert len(new)==160 and new.Status.eq('ok').all()
assert new.ObjectiveCalls.eq(100000).all() and new.Evaluations.eq(100000).all() and new.OutsideCalls.eq(0).all()
assert set(new.Method)=={'Anchor-Rule','Age-Rule'}
assert new.groupby(['FunctionID','Seed']).Method.nunique().eq(2).all()
cache=ROOT/'results/saq_elite_probe_mechanism_10seed_20261014'
ccfg=json.loads((cache/'config.json').read_text(encoding='utf8'))
for key in ['FunctionIDs','Seeds','Dimension','Population','Budget','LowerBound','UpperBound','ProgressWindowFE','ProgressThreshold','EpisodeFE','SeedBase']:
    assert cfg[key]==ccfg[key],key
old=pd.read_csv(cache/'all_runs.csv');old=old[old.Method.isin(['Fixed6','ELS-Replace'])].copy()
old['Method']=old['Method'].replace({'ELS-Replace':'Geometry-Rule'})
raw=pd.concat([old,new],ignore_index=True)
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(4).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed','PolicySeed','ProbeSeed']].nunique().eq(1).all().all()
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
methods=['Fixed6','Geometry-Rule','Anchor-Rule','Age-Rule']
out=ROOT/'results/saq_anchor_screening_10seed_20261014';out.mkdir(exist_ok=True,parents=True)
raw.to_csv(out/'all_runs.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
med=raw.groupby(['FunctionID','Method']).FinalError.median().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');std.to_csv(out/'function_std.csv');med.to_csv(out/'function_medians.csv')
means.rank(axis=1).mean().sort_values().rename('AverageRank').to_csv(out/'mean_ranks.csv')
# Paired comparisons for every pair involving anchor and controls.
comparisons=[];detail=[]
pairs=[('Anchor-Rule','Geometry-Rule'),('Anchor-Rule','Age-Rule'),('Anchor-Rule','Fixed6'),('Age-Rule','Geometry-Rule')]
for method,ref in pairs:
    b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError
    v=raw[raw.Method.eq(method)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index)
    d=v-b;ratio=means[method]/means[ref]
    comparisons.append(dict(Method=method,Reference=ref,MeanWins=int((ratio<1).sum()),MeanLosses=int((ratio>1).sum()),MeanTies=int((ratio==1).sum()),
                            MedianMeanRatio=float(ratio.median()),SeedWins=int((d<0).sum()),SeedLosses=int((d>0).sum()),SeedTies=int((d==0).sum())))
    for fid in means.index:
        delta=d.loc[fid].to_numpy();pv=1. if np.all(delta==0) else float(wilcoxon(delta,zero_method='wilcox',method='auto').pvalue)
        detail.append(dict(FunctionID=int(fid),Method=method,Reference=ref,CandidateMean=float(means.loc[fid,method]),ReferenceMean=float(means.loc[fid,ref]),
                           MeanRatio=float(ratio.loc[fid]),WilcoxonP=pv,SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),SeedTies=int((delta==0).sum())))
comp=pd.DataFrame(comparisons);comp.to_csv(out/'comparisons.csv',index=False)
detail=pd.DataFrame(detail);pv=detail.WilcoxonP.to_numpy();order=np.argsort(pv);adj=np.empty(len(pv));running=0.
for k,i in enumerate(order):
    running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
detail['HolmP']=adj;detail.to_csv(out/'function_comparisons.csv',index=False)
x=comp.set_index(['Method','Reference'])
anchor_geo=x.loc[('Anchor-Rule','Geometry-Rule')];anchor_age=x.loc[('Anchor-Rule','Age-Rule')]
ratio_geo=means['Anchor-Rule']/means['Geometry-Rule'];ratio_age=means['Anchor-Rule']/means['Age-Rule']
hard=ratio_geo.loc[[6,9]];healthy=ratio_geo.loc[[1,13,30]]
gate=dict(Passed=bool(anchor_geo.MeanWins>=5 and anchor_geo.MedianMeanRatio<=.95 and anchor_age.MeanWins>=5 and anchor_age.MedianMeanRatio<=1 and (hard<=.9).any() and (hard<=1).all() and (healthy<=1).sum()>=2 and not (healthy>1.2).any()),
          AnchorVsGeometry=anchor_geo.to_dict(),AnchorVsAge=anchor_age.to_dict(),
          F6F9Ratios={int(k):float(v) for k,v in hard.items()},HealthyRatios={int(k):float(v) for k,v in healthy.items()},
          FreshRuns=160,CachedRuns=160,FreshOptimizationCalls=int(new.ObjectiveCalls.sum()),AuditCalls=int(new.PostRunRecheckCalls.sum()),
          IndependentConfirmation=False,Note='Development pilot; cached Fixed6/Geometry results share seeds and search streams.')
for directory in [run,out]:(directory/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf8')
# Curves.
curves=pd.read_csv(cache/'convergence_nodes.csv');curves=curves[curves.Method.isin(['Fixed6','ELS-Replace'])].copy();curves['Method']=curves['Method'].replace({'ELS-Replace':'Geometry-Rule'})
newcurves=pd.read_csv(run/'convergence_nodes.csv');curves=pd.concat([curves,newcurves],ignore_index=True)
curves.to_csv(out/'convergence_nodes.csv',index=False)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
colors={'Fixed6':'#333333','Geometry-Rule':'#2166ac','Anchor-Rule':'#d6604d','Age-Rule':'#1b9e77'}
fig,axes=plt.subplots(2,4,figsize=(13,6.2));g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
for ax,fid in zip(axes.flat,means.index):
    for m in methods:
        z=g.loc[(fid,m)];ax.semilogy(z.index/1000,z.clip(lower=1e-12),label=m,color=colors[m],lw=1.4)
    ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=4,frameon=False);fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
for name in ['config.json','validation.json','checks.csv','prelaunch_hashes.csv','preflight.csv']:
    if (run/name).exists():shutil.copyfile(run/name,out/name)
report=['# 锚点失配稀疏筛选开发结果（2026-10-14）','',
        'D50/100k真实FE，8函数×10个开发种子8101–8110，4 worker。新增160次Anchor-Rule/Age-Rule；Fixed6/Geometry-Rule复用同种子同搜索流缓存。','',
        '| 比较 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 |','|---|---:|---:|---:|']
for c in comparisons:report.append(f"| {c['Method']} vs {c['Reference']} | {c['MeanWins']}/{c['MeanLosses']}/{c['MeanTies']} | {c['SeedWins']}/{c['SeedLosses']}/{c['SeedTies']} | {c['MedianMeanRatio']:.4f} |")
report+=['',f"预定开发门：{'通过' if gate['Passed'] else '未通过'}。",'',
         f"新优化调用{gate['FreshOptimizationCalls']:,}；额外运行后复核调用{gate['AuditCalls']:,}，均单独计数。",'',
         '锚点失配若不能同时优于Geometry-Rule和Age-Rule，则不能称为独立创新，只能作为局部筛选信号。','',
         '| FunctionID | '+' | '.join(methods)+' |','|---|'+'---:|'*len(methods)]
for fid,row in means.iterrows():report.append('| '+str(fid)+' | '+' | '.join(f'{v:.5g}' for v in row)+' |')
report+=['','逐函数配对Wilcoxon与32项Holm见function_comparisons.csv。未显著不表示等效。',f'原始MAT与源码快照：{run}','']
(out/'REPORT.md').write_text('\n'.join(report),encoding='utf8')
print(comp.to_string(index=False));print(json.dumps(gate,ensure_ascii=False,indent=2));print('Output:',out)
