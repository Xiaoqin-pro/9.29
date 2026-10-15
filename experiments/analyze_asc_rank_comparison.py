"""Full-data ASC comparison, including exact cache provenance and fresh-run checks."""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import wilcoxon, friedmanchisquare, rankdata
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('run',type=Path);args=p.parse_args();run=args.run
cfg=json.loads((run/'config.json').read_text(encoding='utf8'));status=json.loads((run/'status.json').read_text(encoding='utf8'));assert status['Status']=='complete'
out=ROOT/'results/asc_comparison_30seed_20261015';out.mkdir(exist_ok=True,parents=True)
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256,h.Path
cache_audit=json.loads((run/'cache/cache_validation.json').read_text(encoding='utf8'));assert cache_audit['Passed'] and cache_audit['Runs']==5220
fresh=pd.read_csv(run/'raw_runs.csv');old=pd.read_csv(run/'cache/cached_runs.csv')
assert len(fresh)==1740 and len(old)==5220
methods=cfg['FreshMethods']+cfg['ReferenceMethods'];assert len(methods)==8
assert not any('HIDMS' in m or m=='Original-CSO-MR02' for m in methods)
fresh['ArtifactPath']=fresh.Artifact.map(lambda f:str(run/'runs'/f));fresh['SourceType']='new';old['SourceType']='cached'
raw=pd.concat([fresh,old],ignore_index=True)
assert raw.Status.eq('ok').all() and raw.Dimension.eq(50).all() and raw.Budget.eq(100000).all()
assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.OutsideCalls.eq(0).all()
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Seed']).Method.nunique().eq(8).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed']].nunique().eq(1).all().all()
assert set(raw.FunctionID)==set([1]+list(range(3,31))) and set(raw.Seed)==set(range(3001,3031))
assert np.isfinite(raw[['FinalCost','FinalError','Seconds']]).all().all()
# Fresh rows first: save common 50-point pool to check every cached prefix.
initials={};integrity=[];curves=[];diagnostics=[];roundcurves=[]
nodes=np.unique(np.r_[50,1000,np.linspace(2000,100000,61).round().astype(int),10000,20000,40000,60000,80000,90000,100000])
for n,row in enumerate(raw.itertuples(),1):
    new=row.SourceType=='new';names=['B','T','p0','job','I'] if new else ['B','T','p0','job']
    saved=loadmat(row.ArtifactPath,simplify_cells=True,variable_names=names)
    T=np.asarray(saved['T']).reshape(-1);B=saved['B'];p0=np.atleast_2d(saved['p0']);job=saved['job'];key=(row.FunctionID,row.Seed)
    assert len(T)==100000 and np.isfinite(T).all() and (np.diff(T)<=0).all()
    assert np.isclose(B['Cost'],row.FinalCost,rtol=1e-12,atol=1e-9) and T[-1]==B['Cost']
    assert np.isclose(row.FinalError,row.FinalCost-100*row.FunctionID,rtol=1e-12,atol=1e-9)
    assert job['FunctionID']==row.FunctionID and job['Seed']==row.Seed and job['SearchSeed']==row.SearchSeed
    assert p0.shape==(row.Population,50)
    if key not in initials:assert new;initials[key]=p0.copy()
    assert np.array_equal(p0,initials[key][:row.Population])
    assert np.all((p0>=-100)&(p0<=100)) and np.all((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100))
    if new:
        I=saved['I'];R=np.atleast_2d(I['RoundLog']);P=I['Parameters']
        assert I['Evaluations']==100000 and np.array_equal(I['InitialPopulation'],p0)
        assert np.array_equal(R[:,1]-R[:,0],R[:,2]) and R[:,2].sum()+50==100000
        assert R[0,0]==50 and R[-1,1]==100000 and np.all(R[1:,0]==R[:-1,1])
        assert P['traceBoostGain']==0 and not P['useGroup'] and not P['useOBL'] and not P['useGaussBest']
        if row.Method=='ASC-PositionRank':
            assert P['positionRankRule']=='either'
            assert I['TracingEvaluations']+I['SeekingEvaluations']==99950
            assert R[:,15].sum()==I['TracingEvaluations'] and R[:,16].sum()==I['SeekingEvaluations']
            assert np.all(R[:,18]<=R[:,17])
        diagnostics.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,Jumps=int(I['Jumps']),Rounds=int(I['Rounds']),
                                FinalRadius=float(I['FinalRadius']),FinalSeekingProbability=float(I['FinalSeekProb']),FinalSlowness=float(I['FinalSlowness']),
                                TracingFE=I.get('TracingEvaluations',np.nan),SeekingFE=I.get('SeekingEvaluations',np.nan),
                                PositionEvaluationMismatchOwners=int(R[:,18].sum()) if R.shape[1]>15 else np.nan,
                                EvaluatedOwners=int(R[:,17].sum()) if R.shape[1]>15 else np.nan))
        for progress in [.1,.2,.4,.6,.8,1.]:
            k=np.searchsorted(R[:,1],100000*progress);k=min(k,len(R)-1)
            roundcurves.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,FE=int(R[k,1]),Node=int(progress*100000),
                                    SeekProbability=R[k,3],Radius=R[k,4],Slowness=R[k,5],SuccessRate=R[k,7],Jumped=R[k,9]))
    for fe in nodes:curves.append((row.FunctionID,row.Seed,row.Method,int(fe),float(T[fe-1]-100*row.FunctionID)))
    integrity.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,SourceType=row.SourceType,TracePassed=True,SharedInitialPrefix=True,BestMatches=True))
    if n%1000==0:print('Artifact checks',n,'/',len(raw),flush=True)
raw.to_csv(out/'all_runs.csv',index=False)
pd.DataFrame(integrity).to_csv(out/'artifact_checks.csv',index=False)
diagframe=pd.DataFrame(diagnostics)
diagframe['TraceEvaluationFraction']=diagframe.TracingFE/(diagframe.TracingFE+diagframe.SeekingFE)
diagframe['PositionEvaluationMismatchFraction']=diagframe.PositionEvaluationMismatchOwners/diagframe.EvaluatedOwners
# Original ASC does not log true mode allocations: leave missing, never use generated counts as estimates.
diagframe.to_csv(out/'asc_diagnostics.csv',index=False)
diagframe.groupby(['FunctionID','Method'])[['Jumps','Rounds','FinalRadius','FinalSeekingProbability','FinalSlowness','TracingFE','SeekingFE','TraceEvaluationFraction','PositionEvaluationMismatchFraction']].mean().to_csv(out/'diagnostics_by_function.csv')
pd.DataFrame(roundcurves).to_csv(out/'adaptive_control_nodes.csv',index=False)
curves=pd.DataFrame(curves,columns=['FunctionID','Seed','Method','FE','BestError']);curves.to_csv(out/'convergence_nodes.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods)
median=raw.groupby(['FunctionID','Method']).FinalError.median().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');std.to_csv(out/'function_std.csv');median.to_csv(out/'function_medians.csv')
wide=pd.DataFrame(index=means.index)
for method in methods:wide[method]=[f'{a:.5e} ± {b:.5e}' for a,b in zip(means[method],std[method])]
wide.to_csv(out/'paper_mean_std.csv')
ranks=means.rank(axis=1).mean().sort_values().rename('AverageRank');ranks.to_csv(out/'mean_ranks.csv')
friedman=friedmanchisquare(*[means[m].to_numpy() for m in methods])
# Two prespecified focal algorithms: 13 unique focal-control pairs, 377 function tests.
pairs=[];seen=set()
for focal in cfg['FreshMethods']:
    for ref in methods:
        if ref==focal or frozenset([focal,ref]) in seen:continue
        seen.add(frozenset([focal,ref]));pairs.append((focal,ref))
# Ensure the mechanism pair uses improved on the left.
pairs=[('ASC-PositionRank','ASC-NoFarness') if frozenset(p)==frozenset(cfg['FreshMethods']) else p for p in pairs]
assert len(pairs)==13
detail=[]
for method,ref in pairs:
    for fid in means.index:
        z=raw[raw.FunctionID.eq(fid)].pivot(index='Seed',columns='Method',values='FinalError')
        delta=(z[method]-z[ref]).to_numpy();assert len(delta)==30
        nz=delta[delta!=0];pv=1. if len(nz)==0 else float(wilcoxon(delta,zero_method='wilcox',correction=True,method='approx').pvalue)
        rb=0. if len(nz)==0 else float(np.sum(rankdata(abs(nz))*np.sign(-nz))/np.sum(rankdata(abs(nz))))
        denominator=means.loc[fid,ref];ratio=means.loc[fid,method]/denominator if denominator!=0 else (1. if means.loc[fid,method]==0 else np.inf)
        detail.append(dict(FunctionID=int(fid),Method=method,Reference=ref,MethodMean=float(means.loc[fid,method]),ReferenceMean=float(denominator),
                           MeanRatio=float(ratio),SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),SeedTies=int((delta==0).sum()),WilcoxonP=pv,RankBiserial=rb))
detail=pd.DataFrame(detail)
def holm(p):
    p=np.asarray(p);order=np.argsort(p);a=np.empty(len(p));acc=0
    for k,i in enumerate(order):acc=max(acc,(len(p)-k)*p[i]);a[i]=min(1.,acc)
    return a
detail['Holm377']=holm(detail.WilcoxonP);detail['Holm29Mechanism']=np.nan
mechanism=detail.Method.eq('ASC-PositionRank')&detail.Reference.eq('ASC-NoFarness')
detail.loc[mechanism,'Holm29Mechanism']=holm(detail.loc[mechanism,'WilcoxonP'])
detail.to_csv(out/'function_comparisons.csv',index=False)
overall=[]
for method,ref in pairs:
    d=detail[detail.Method.eq(method)&detail.Reference.eq(ref)]
    overall.append(dict(Method=method,Reference=ref,MeanWins=int((d.MethodMean<d.ReferenceMean).sum()),MeanLosses=int((d.MethodMean>d.ReferenceMean).sum()),
                         MeanTies=int((d.MethodMean==d.ReferenceMean).sum()),SeedWins=int(d.SeedWins.sum()),SeedLosses=int(d.SeedLosses.sum()),SeedTies=int(d.SeedTies.sum()),
                         MedianMeanRatio=float(d.MeanRatio.median()),SignificantBetter377=int(((d.Holm377<.05)&(d.MethodMean<d.ReferenceMean)).sum()),
                         SignificantWorse377=int(((d.Holm377<.05)&(d.MethodMean>d.ReferenceMean)).sum()),NotSignificant377=int((d.Holm377>=.05).sum())))
overall=pd.DataFrame(overall);overall.to_csv(out/'overall_comparisons.csv',index=False)
mech=detail[mechanism];mech.to_csv(out/'mechanism_comparison.csv',index=False)
summary_changes=pd.DataFrame(index=means.index)
for method in cfg['FreshMethods']:
 summary_changes[method+' / SAQ-CSO']=means[method]/means['SAQ-CSO'].replace(0,np.nan)
summary_changes['ASC-PositionRank / ASC-NoFarness']=means['ASC-PositionRank']/means['ASC-NoFarness'].replace(0,np.nan)
summary_changes.to_csv(out/'asc_error_ratios.csv')
runtime=raw.groupby('Method').agg(Runs=('Seed','size'),MeanSeconds=('Seconds','mean'),StdSeconds=('Seconds','std'),OptimizationCalls=('ObjectiveCalls','sum'),PostRunRechecks=('PostRunRecheckCalls','sum'))
runtime.to_csv(out/'runtime.csv')
phase=[]
for fid in means.index:
    for method in cfg['FreshMethods']:
        z=curves[curves.FunctionID.eq(fid)&curves.Method.eq(method)].groupby('FE').BestError.mean()
        for start,end in [(10000,20000),(20000,40000),(40000,60000),(60000,80000),(80000,100000)]:
            a,b=z.loc[start],z.loc[end];phase.append(dict(FunctionID=int(fid),Method=method,StartFE=start,EndFE=end,StartMean=a,EndMean=b,RelativeDrop=(a-b)/max(abs(a),1e-300)))
pd.DataFrame(phase).to_csv(out/'phase_progress.csv',index=False)
labels={'ASC-NoFarness':'ASC original','ASC-PositionRank':'ASC rank-min','SAQ-CSO':'SAQ-CSO','CLPSO-AuthorSource':'CLPSO',
        'HCLPSO-AuthorSource':'HCLPSO','HPSO-TVAC-CEC':'HPSO-TVAC','SPSO-2011-OfficialC':'SPSO-2011','DMS-PSO-SIS2005':'DMS-PSO'}
colors=['#333333','#d6604d','#2166ac','#1b9e77','#7570b3','#e6ab02','#a6761d','#66a61e']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':8})
g=curves.groupby(['FunctionID','Method','FE']).BestError.mean()
fig,axes=plt.subplots(6,5,figsize=(17,18))
for ax,fid in zip(axes.flat,means.index):
    for method,color in zip(methods,colors):
        z=g.loc[(fid,method)];ax.semilogy(z.index/1000,z.clip(lower=1e-12),label=labels[method],color=color,lw=1.5 if method in cfg['FreshMethods'] else .85)
    ax.set_title(f'F{fid}',loc='left');ax.grid(alpha=.17);ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error')
axes.flat[-1].set_visible(False);h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=4,frameon=False);fig.tight_layout(rect=(0,.025,1,1));fig.savefig(out/'all29_convergence.png',dpi=160,bbox_inches='tight');plt.close(fig)
with PdfPages(out/'all29_convergence.pdf') as pdf:
    for start in range(0,29,6):
        fig,axes=plt.subplots(2,3,figsize=(12,7.2))
        for ax,fid in zip(axes.flat,list(means.index)[start:start+6]):
            for method,color in zip(methods,colors):
                z=g.loc[(fid,method)];ax.semilogy(z.index/1000,z.clip(lower=1e-12),label=labels[method],color=color,lw=1.4 if method in cfg['FreshMethods'] else 1)
            ax.set_title(f'F{fid}',loc='left');ax.grid(alpha=.17);ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error')
        for ax in list(axes.flat)[len(list(means.index)[start:start+6]):]:ax.set_visible(False)
        h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=4,frameon=False);fig.tight_layout(rect=(0,.05,1,1));pdf.savefig(fig,bbox_inches='tight');plt.close(fig)
fig,ax=plt.subplots(figsize=(8,4));ax.barh([labels[x] for x in ranks.index],ranks.values,color='#2166ac');ax.invert_yaxis();ax.set_xlabel('Mean rank across 29 functions');fig.tight_layout();fig.savefig(out/'mean_ranks.png',dpi=170);plt.close(fig)
for name in ['config.json','validation.json','checks.csv','prelaunch_hashes.csv','PROTOCOL.md']:shutil.copyfile(run/name,out/name)
for name in ['cache_validation.json','cache_preparation.json','source_checks.csv']:shutil.copyfile(run/'cache'/name,out/name)
(out/'source').mkdir(exist_ok=True)
for name in ['ASC_NoFarness.m','ASC_NoFarness_PositionRank.m','run_asc_rank_job.m','run_asc_rank_comparison.m']:
    shutil.copyfile(run/'source'/name,out/'source'/name)
report=['# ASC-NoFarness与位置评分改进：八算法CEC2017比较','',
        'D50、100k真实FE（包含初始化）、29函数F1/F3–F30、30种子3001–3030、4worker。原ASC和改进ASC各870新运行，六个已核验参照5220条缓存，共6960条质量记录。未包含HIDMS或原始CSO。','',
        '改进仅用min(rankNear,rankFar)替代决定粒子下一位置的排名和；实际评价候选的两阶段筛选保持不变。分组速度返回修复在本批默认useGroup=false下不影响轨迹。未启用pbest位置保护或半径恢复。','',
        '| 方法 | 平均函数排名 | 平均秒/运行（描述性） |','|---|---:|---:|']
for method in ranks.index:report.append(f'| {labels[method]} | {ranks[method]:.4f} | {runtime.loc[method,"MeanSeconds"]:.3f} |')
report+=['','| 比较 | 均值胜/负/平 | 配对种子胜/负/平 | 377项Holm显著优/劣/未显著 |','|---|---:|---:|---:|']
for c in overall.itertuples():report.append(f'| {labels[c.Method]} vs {labels[c.Reference]} | {c.MeanWins}/{c.MeanLosses}/{c.MeanTies} | {c.SeedWins}/{c.SeedLosses}/{c.SeedTies} | {c.SignificantBetter377}/{c.SignificantWorse377}/{c.NotSignificant377} |')
mb=int(((mech.Holm29Mechanism<.05)&(mech.MethodMean<mech.ReferenceMean)).sum());mw=int(((mech.Holm29Mechanism<.05)&(mech.MethodMean>mech.ReferenceMean)).sum())
comparison_original=overall[overall.Method.eq('ASC-PositionRank')&overall.Reference.eq('ASC-NoFarness')].iloc[0]
report += ['', '## 结果解读', '',
 f"位置评分改进相对原ASC：函数均值{int(comparison_original.MeanWins)}胜{int(comparison_original.MeanLosses)}负，配对种子{int(comparison_original.SeedWins)}胜{int(comparison_original.SeedLosses)}负，中位函数均值误差比{comparison_original.MedianMeanRatio:.4f}。数学上减少排名抵消并不自动意味着在全部景观上更好，应结合这一实际差异判断。", '',
 '排名评分仅控制下一搜索位置；被真实评价的候选仍由原两阶段规则选出。因此有反馈的候选和实际下一位置可能继续不同。该行为作为设计选项保留，没有在本批加入额外pbest回退。', '']
report+=['',f'预定机制比较族：改进ASC相对原ASC，29项Holm显著优/劣/未显著={mb}/{mw}/{29-mb-mw}；该族与主377项族分开，不混用票数。',
         '',f'Friedman以29函数均值为block，stat={friedman.statistic:.6g}, p={friedman.pvalue:.6g}。总体差异不代表每对算法均有差异。',
         '',f'新优化1740次、174,000,000次调用；新运行返回解复核{int(fresh.PostRunRecheckCalls.sum()):,}次；缓存核验{cache_audit["AuditObjectiveCalls"]:,}次，均在优化预算外单列。完整轨迹/共享初始化/Best核验共6960条通过。预检运行另外记录，不计正式性能样本。',
         '', '速度统计包含不同批次、实现语言和诊断开销，SPSO使用native-C；只描述性报告，不归因于某单一算法机制。原ASC默认参数未调优；本批不依胜负删除函数或算法。结果属于已开发的CEC函数集合，不声称未见问题泛化。',
         '', 'paper_mean_std.csv为完整29函数表；function_comparisons.csv保留所有原始P、两族校正和配对rank-biserial。phase_progress.csv和asc_diagnostics.csv记录阶段进展与实际模式评价。原版缺少模式实评日志的字段记NaN，不以生成比例代替评价比例。',
         '',f'原始MAT与冻结源：{run}','']
(out/'REPORT.md').write_text('\n'.join(report),encoding='utf8')
summary={'Passed':True,'Rows':6960,'FreshRuns':1740,'CachedRuns':5220,'ObjectiveCallsFresh':174000000,'CacheAuditCalls':cache_audit['AuditObjectiveCalls'],
         'MainHolmTests':377,'MechanismHolmTests':29,'FriedmanStatistic':float(friedman.statistic),'FriedmanP':float(friedman.pvalue),
         'Methods':methods,'UnseenFunctions':False,'RawDirectory':str(run)}
(out/'analysis_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf8')
print(overall.to_string(index=False));print('Ranks:\n',ranks.to_string());print('Output:',out)
