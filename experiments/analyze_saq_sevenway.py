"""Validate raw MATs and summarize frozen SAQ-CSO comparison; no run selection."""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import friedmanchisquare, wilcoxon
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

p=argparse.ArgumentParser()
p.add_argument('base',type=Path)
p.add_argument('--hclpso',type=Path)
p.add_argument('--hidms',type=Path)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--new-baselines',type=Path,required=True)
a=p.parse_args(); root=Path(__file__).resolve().parents[1]; out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
methods=['Original-CSO-MR02','SAQ-CSO','CLPSO-AuthorSource','HCLPSO-Reference']
base=a.base.resolve();df=pd.read_csv(base/'raw_runs.csv');assert (base/'COMPLETED.json').exists() and len(df)==3480
# Keep originals traceable before replacing only the audited baseline column.
reference=df[df.Condition=='HCLPSO-Reference'].copy()
df['RunDirectory']=str(base)
if a.hclpso:
    h=a.hclpso.resolve();new=pd.read_csv(h/'raw_runs.csv');assert (h/'COMPLETED.json').exists() and len(new)==870
    new['RunDirectory']=str(h);df=pd.concat([df[df.Condition!='HCLPSO-Reference'],new],ignore_index=True)
    methods[-1]='HCLPSO-AuthorSource'
if a.hidms:
    h=a.hidms.resolve();new=pd.read_csv(h/'raw_runs.csv');assert (h/'COMPLETED.json').exists() and len(new)==870
    new['RunDirectory']=str(h);df=pd.concat([df,new],ignore_index=True);methods.append('HIDMS-PSO-IndexCorrected')
nb=a.new_baselines.resolve();new=pd.read_csv(nb/'raw_runs.csv');assert (nb/'COMPLETED.json').exists() and len(new)==1740
new['RunDirectory']=str(nb);df=pd.concat([df,new],ignore_index=True);methods.extend(['HPSO-TVAC-CEC','DMS-PSO-SIS2005'])
assert len(df)==870*len(methods) and set(df.Condition)==set(methods)
assert df.Status.eq('ok').all() and df.Budget.eq(100000).all() and df.Dimension.eq(50).all()
assert df.ObjectiveCalls.eq(df.Budget).all() and df.Evaluations.eq(df.Budget).all()
assert df.PostRunRecheckCalls.eq(1).all() and df.OutsideCalls.eq(0).all()
assert set(df.FunctionID)==set([1]+list(range(3,31))) and set(df.Seed)==set(range(3001,3031))
assert not df.duplicated(['FunctionID','Seed','Condition']).any()
assert np.isfinite(df[['FinalCost','FinalError','Seconds']].to_numpy()).all()
all_nodes=np.unique(np.r_[50,np.linspace(2000,100000,60).round().astype(int),20000,60000,80000,100000])
curve=[]; behavior=[]; q_tables=[]; initial={}; checks=0;roundsChecked=0;decisionsChecked=0;source=[]
# Source identity check for cached methods; source snapshots were written pre-launch.
for rel in ['src/SAQ_CSO.m','src/ASE_CSO_QuotaQ_Candidate.m','src/ASE_CSO_QuotaQ_Compact.m','src/CLPSO_CEC_AuthorSource.m','archive/legacy/CSO_CEC.m','archive/legacy/CEC2017Function.m']:
    b=(base/'source_snapshot'/rel).read_bytes().replace(b'\r\n',b'\n'); now=(root/rel).read_bytes().replace(b'\r\n',b'\n')
    assert b==now, f'Cached source changed: {rel}'
    source.append({'Path':rel,'SHA256NormalizedLF':hashlib.sha256(b).hexdigest(),'MatchesCurrent':True})
for row in df.itertuples():
    path=Path(row.RunDirectory)/'runs'/f'job_{row.JobID:04d}.mat';d=loadmat(path,simplify_cells=True)
    T=np.asarray(d['T']).reshape(-1);I=d['I'];B=d['B'];p0=np.asarray(d['p0']);job=d['job'];rec=d['rec']
    assert all(job[k]==getattr(row,k) for k in ['FunctionID','Seed','Budget','Population','InitSeed','SearchSeed','Condition'])
    assert len(T)==row.Budget and np.isfinite(T).all() and np.all(np.diff(T)<=0)
    assert int(I['Evaluations'])==row.Budget and np.isclose(float(B['Cost']),row.FinalCost,rtol=1e-13,atol=1e-8)
    assert T[-1]==float(B['Cost']) and np.isclose(T[row.Population-1],row.InitialCost,rtol=1e-13,atol=1e-8)
    assert np.isclose(row.FinalError,row.FinalCost-100*row.FunctionID,rtol=1e-11,atol=1e-7)
    assert p0.shape==(row.Population,50) and np.isfinite(p0).all() and ((p0>=-100)&(p0<=100)).all()
    assert np.array_equal(p0,np.asarray(I['InitialPopulation']))
    v=np.asarray(B['Vector']).reshape(-1);assert len(v)==50 and np.isfinite(v).all() and ((v>=-100)&(v<=100)).all()
    key=(row.FunctionID,row.Seed)
    if key not in initial:initial[key]=p0
    assert np.array_equal(initial[key][:row.Population],p0),f'Initial pool mismatch {key} {row.Condition}'
    for frac,name in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:
        assert np.isclose(T[round(frac*row.Budget)-1]-100*row.FunctionID,getattr(row,name),rtol=1e-11,atol=1e-7)
    if row.Condition=='HPSO-TVAC-CEC':
        assert row.Population==50 and not bool(I['InertiaTerm']) and I['VelocityCap']==100
        assert I['Iterations']==1999 and I['ScheduleGeneration']==2000
        assert I['ZeroVelocityRestarts']>=50 and I['BoundaryClips']>=0
    if row.Condition=='DMS-PSO-SIS2005':
        assert row.Population==30 and I['SubgroupSize']==3 and I['GroupCount']==10 and I['RegroupPeriod']==5
        assert not bool(I['LocalSearchEnabled']) and not bool(I['CoordinateMixingEnabled'])
        assert I['InertiaStart']==.9 and I['InertiaEnd']==.2 and I['Acceleration']==1.49445
        nominal=int(np.ceil((row.Budget-30)/30));local=int(np.floor(.9*nominal))
        assert I['NominalGenerations']==nominal and I['LocalGenerationLimit']==local
        assert I['RegroupCount']==local//5 and I['Iterations']>local and I['GlobalStartFE']<row.Budget
        groups=np.asarray(I['InitialGroups']);assert groups.shape==(10,3) and np.array_equal(np.sort(groups.ravel()),np.arange(1,31))
    if row.Condition=='SAQ-CSO':
        R=np.asarray(I['RoundLog']).reshape(-1,13);DL=np.asarray(I['DecisionLog']).reshape(-1,14)
        U=np.asarray(I['UpdateLog']).reshape(-1,8);G=np.asarray(I['GateLog']).reshape(-1,3);SL=np.asarray(I['StateLog']).reshape(-1,3)
        RL=np.asarray(I['RewardLog']).reshape(-1,4);discount=np.asarray(I['DiscountLog']).reshape(-1)
        assert len(R)==I['Rounds'] and len(DL)==I['Decisions']==1000 and len(U)==len(DL)
        assert np.array_equal(R[:,0],np.r_[50,R[:-1,1]]) and R[-1,1]==100000
        assert np.array_equal(R[:,1]-R[:,0],R[:,2]+R[:,3])
        assert R[:,2].sum()==I['TracingEvaluations']==row.TracingEvaluations
        assert R[:,3].sum()==I['SeekingEvaluations']==row.SeekingEvaluations
        assert I['TracingEvaluations']+I['SeekingEvaluations']==99950 and I['MaxParentEvaluations']<=2
        lo=DL[:,0].astype(int);hi=DL[:,1].astype(int);gain=DL[:,7]-DL[:,8]
        assert np.array_equal(DL[:,7],T[lo-1]) and np.array_equal(DL[:,8],T[hi-1])
        assert np.array_equal(lo,np.r_[50,hi[:-1]]) and hi[-1]==100000
        assert np.array_equal(hi-lo,DL[:,10]+DL[:,11]) and np.all(hi-lo<=100)
        reward=np.where(gain>0,10,-1);assert np.array_equal(DL[:,9],reward) and np.array_equal(RL[:,2],reward)
        changes=np.r_[False,np.diff(T)<0]; changes[:50]=False
        last=np.maximum.accumulate(np.where(changes,np.arange(1,len(T)+1),50))
        assert np.array_equal(SL[:,0],lo-last[lo-1])
        signal=(SL[:,0]>=1000).astype(int);phase=np.minimum(2,np.floor(3*(lo-50)/99950)).astype(int)
        assert np.array_equal(SL[:,1],signal) and np.array_equal(DL[:,2],phase+1)
        assert np.array_equal(G[:,1],signal) and np.all(G[:,0]==1) and np.array_equal(G[:,2],DL[:,3])
        assert np.all(DL[signal==0,3]==3) and np.array_equal(DL[:,4],2*DL[:,3])
        bi=np.searchsorted(hi,R[:,0],side='right');qt=DL[bi,4];size=R[:,1]-R[:,0]
        expected=np.minimum(qt,np.maximum(1,size-1));fallback=(R[:,2]!=expected)|(R[:,3]!=size-expected)
        assert np.array_equal(np.bincount(bi,weights=R[:,2],minlength=len(DL)),DL[:,10])
        assert np.array_equal(np.bincount(bi,weights=R[:,3],minlength=len(DL)),DL[:,11])
        assert np.array_equal(np.bincount(bi,weights=fallback,minlength=len(DL)),DL[:,12])
        eligible=((DL[:,12]==0)&(signal==1)).astype(int)
        assert np.array_equal(U[:,7],eligible) and np.array_equal(DL[:,13],eligible)
        assert np.array_equal(U[:,:3],DL[:,[2,3,9]])
        assert np.array_equal(U[:-1,3],DL[1:,2]) and U[-1,4]==1 and U[-1,3]==0
        assert np.allclose(discount,.9**((hi-lo)/100),rtol=0,atol=1e-15)
        replay=np.zeros((3,3));visits=np.zeros((3,3),dtype=int)
        for ix,u in enumerate(U):
            if u[7]:
                st=int(u[0])-1;ac=int(u[1])-1
                future=0 if u[4] or signal[ix+1]==0 else discount[ix]*replay[int(u[3])-1].max()
                replay[st,ac]+=.1*(u[2]+future-replay[st,ac]);visits[st,ac]+=1
        assert np.array_equal(visits,np.asarray(I['QVisits'])) and np.allclose(replay,np.asarray(I['QTable']),rtol=0,atol=1e-12)
        assert visits.sum()==row.QUpdates==I['QUpdates'] and not bool(I['PendingAtEnd'])
        success=np.r_[0,np.cumsum(np.diff(T[49:])<0)]
        assert np.array_equal(success[(R[:,1]-50).astype(int)]-success[(R[:,0]-50).astype(int)],R[:,9]+R[:,10])
        assert np.isclose(R[:,11:].sum(),T[49]-T[-1],rtol=1e-10,atol=1e-8)
        entry={'FunctionID':row.FunctionID,'Seed':row.Seed,'FreeDecisions':int(signal.sum()),'QUpdates':int(visits.sum()),'Decisions':len(DL),'PositiveWindows':int((gain>0).sum())}
        for ac in range(1,4):
            entry[f'Action{ac}ShareAll']=float((DL[:,3]==ac).mean())
            entry[f'Action{ac}ShareStalled']=float((DL[signal==1,3]==ac).mean()) if signal.sum() else np.nan
        entry['GateFraction']=float(signal.mean());entry['QuotaFallbackRounds']=int(fallback.sum());behavior.append(entry)
        for st in range(3):
            for ac in range(3):q_tables.append({'FunctionID':row.FunctionID,'Seed':row.Seed,'State':st+1,'Action':ac+1,'Q':replay[st,ac],'Visits':visits[st,ac]})
        roundsChecked+=len(R);decisionsChecked+=len(DL)
    for fe,val in zip(all_nodes,T[all_nodes-1]):curve.append({'FunctionID':row.FunctionID,'Seed':row.Seed,'Condition':row.Condition,'FE':int(fe),'Error':float(val-100*row.FunctionID)})
    checks+=1
    if checks%500==0:print(f'VALIDATED {checks}/{len(df)}',flush=True)
# Do not overwrite historical raw files; output a traceable selected source table.
df.to_csv(out/'all_quality_runs.csv',index=False);reference.to_csv(out/'historical_hclpso_reference_runs.csv',index=False)
validation={'RunsChecked':checks,'Passed':True,'SharedInitialGroups':len(initial),'RoundChecks':roundsChecked,'QDecisionChecks':decisionsChecked,'ObjectiveCalls':int(df.ObjectiveCalls.sum()),'PostRunRecheckCalls':int(df.PostRunRecheckCalls.sum()),'Checks':'CSV/MAT/keys/FE/p0-prefix/bounds/final-best/nodes/Q states+gates+rewards+terminal replay','CachedSourceIdentity':source,'NoNewObjectiveChecksInPython':True}
validation['NewOptimizationRuns']=int((~new.FromCache.astype(bool)).sum())
validation['CachedHPSORuns']=int(new.FromCache.astype(bool).sum())
assert validation['NewOptimizationRuns']==1204 and validation['CachedHPSORuns']==536
validation['NewObjectiveCalls']=int(new.loc[~new.FromCache.astype(bool),'ObjectiveCalls'].sum())
(out/'independent_artifact_checks.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
summary=df.groupby(['FunctionID','Condition']).agg(N=('FinalError','size'),MeanError=('FinalError','mean'),StdError=('FinalError','std'),MedianError=('FinalError','median'),BestError=('FinalError','min'),WorstError=('FinalError','max'),MeanSeconds=('Seconds','mean'),StdSeconds=('Seconds','std')).reset_index();assert summary.N.eq(30).all()
summary.to_csv(out/'summary.csv',index=False)
means=summary.pivot(index='FunctionID',columns='Condition',values='MeanError')[methods]
medians=summary.pivot(index='FunctionID',columns='Condition',values='MedianError')[methods]
rank=means.rank(axis=1,method='average');rank.mean().sort_values().rename('MeanErrorRank').to_csv(out/'mean_ranks.csv')
means.to_csv(out/'function_means.csv');medians.to_csv(out/'function_medians.csv')
q=df[df.Condition=='SAQ-CSO'];pairs=[]
for c in methods:
    if c=='SAQ-CSO':continue
    d=q.merge(df[df.Condition==c],on=['FunctionID','Seed'],suffixes=('_Q','_Control'),validate='one_to_one')
    for fid,g in d.groupby('FunctionID'):
        diff=g.FinalError_Q.to_numpy()-g.FinalError_Control.to_numpy()
        pv=1. if np.all(diff==0) else float(wilcoxon(diff,zero_method='wilcox',correction=True,alternative='two-sided',method='approx').pvalue)
        pairs.append({'Control':c,'FunctionID':int(fid),'QMean':float(means.loc[fid,'SAQ-CSO']),'ControlMean':float(means.loc[fid,c]),'QMedian':float(medians.loc[fid,'SAQ-CSO']),'ControlMedian':float(medians.loc[fid,c]),'SeedWins':int((diff<0).sum()),'SeedLosses':int((diff>0).sum()),'SeedTies':int((diff==0).sum()),'MedianPairedDifference':float(np.median(diff)),'PValue':pv,'MeanWinner':'SAQ-CSO' if means.loc[fid,'SAQ-CSO']<means.loc[fid,c] else c if means.loc[fid,'SAQ-CSO']>means.loc[fid,c] else 'Tie'})
pairs=pd.DataFrame(pairs)
def holm(pvals):
    arr=np.asarray(pvals);order=np.argsort(arr);ans=np.zeros(len(arr));ans[order]=np.minimum(1,np.maximum.accumulate(arr[order]*np.arange(len(arr),0,-1)));return ans
pairs['HolmAll']=holm(pairs.PValue)
pairs['HolmWithinControl']=pairs.groupby('Control',group_keys=False).PValue.transform(lambda g:holm(g.to_numpy()))
pairs['SignificantDirection']=np.where(pairs.HolmAll>=.05,'NS',np.where(pairs.MedianPairedDifference<0,'Q-better','Q-worse'))
pairs.to_csv(out/'function_comparison.csv',index=False)
over=[]
for c,g in pairs.groupby('Control',sort=False):
    qm=means['SAQ-CSO'];cm=means[c]
    over.append({'Control':c,'MeanWins':int((qm<cm).sum()),'MeanLosses':int((qm>cm).sum()),'MeanTies':int((qm==cm).sum()),'SeedWins':int(g.SeedWins.sum()),'SeedLosses':int(g.SeedLosses.sum()),'SeedTies':int(g.SeedTies.sum()),'HolmAllBetter':int(g.SignificantDirection.eq('Q-better').sum()),'HolmAllWorse':int(g.SignificantDirection.eq('Q-worse').sum()),'HolmAllNS':int(g.SignificantDirection.eq('NS').sum()),'MedianFunctionErrorRatio':float(np.median(np.maximum(qm,1e-12)/np.maximum(cm,1e-12)))})
over=pd.DataFrame(over);over.to_csv(out/'overall_comparisons.csv',index=False)
stat,pvalue=friedmanchisquare(*[means[c].to_numpy() for c in methods]);stats={'FriedmanStatistic':float(stat),'FriedmanP':float(pvalue),'FriedmanBlocks':'29 function means','PerFunctionTest':'two-sided paired Wilcoxon, normal approximation with tie correction and continuity correction, raw errors','HolmFamily':'all '+str(len(pairs))+' SAQ-vs-control per-function tests; within-control Holm also reported','PairedSeedCountPerFunction':30,'PooledSeedsAreNotIndependentFunctionReplicates':True}
(out/'statistics_protocol.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
provenance=[]
for run in sorted(set(df.RunDirectory)):
    run_path=Path(run)
    for path in sorted((run_path/'source_snapshot').rglob('*')):
        if path.is_file():provenance.append({'RunDirectory':run,'Path':str(path.relative_to(run_path/'source_snapshot')),'SHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
inputs=pd.read_csv(root/'data/cec2017/D50_manifest.csv')
for row in inputs.itertuples():
    path=root/'data/cec2017/input_data'/row.File
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row.SHA256
    provenance.append({'RunDirectory':'common-data','Path':row.File,'SHA256':row.SHA256})
provenance.append({'RunDirectory':'common-data','Path':'cec17_func.mexw64','SHA256':hashlib.sha256((root/'data/cec2017/cec17_func.mexw64').read_bytes()).hexdigest()})
(out/'source_manifest.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')

runtime=df.groupby('Condition').Seconds.agg(['mean','median','std']);runtime.to_csv(out/'runtime.csv')
pd.DataFrame(behavior).to_csv(out/'q_behavior.csv',index=False);pd.DataFrame(q_tables).to_csv(out/'q_tables.csv',index=False)
curves=pd.DataFrame(curve).groupby(['FunctionID','Condition','FE']).Error.mean().reset_index();curves.to_csv(out/'convergence_nodes.csv',index=False)
node_compare=[]
for fe in [20000,60000,80000,100000]:
    z=curves[curves.FE==fe].pivot(index='FunctionID',columns='Condition',values='Error')
    for c in methods:
        if c!='SAQ-CSO':node_compare.append({'FE':fe,'Control':c,'MeanWins':int((z['SAQ-CSO']<z[c]).sum()),'MeanLosses':int((z['SAQ-CSO']>z[c]).sum()),'MeanTies':int((z['SAQ-CSO']==z[c]).sum())})
pd.DataFrame(node_compare).to_csv(out/'node_function_wins.csv',index=False)
paper=summary.copy();paper['MeanStd']=paper.apply(lambda row:f"{row.MeanError:.4e} ± {row.StdError:.4e}",axis=1)
paper.pivot(index='FunctionID',columns='Condition',values='MeanStd').reindex(columns=methods).to_csv(out/'paper_mean_std.csv',encoding='utf-8-sig')

plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
colors={'SAQ-CSO':'#1979a9','Original-CSO-MR02':'#9b9b9b','CLPSO-AuthorSource':'#ed9d38','HCLPSO-Reference':'#ac477d','HCLPSO-AuthorSource':'#ac477d','HIDMS-PSO-IndexCorrected':'#548743','HPSO-TVAC-CEC':'#7875b7','DMS-PSO-SIS2005':'#a1713e'}
fig,axes=plt.subplots(6,5,figsize=(15,15))
for ax,(fid,g) in zip(axes.flat,curves.groupby('FunctionID')):
    for c in methods:
        z=g[g.Condition==c];ax.semilogy(z.FE/1000,np.maximum(z.Error,1e-8),label=c,color=colors[c],lw=1.3)
    ax.set_title(f'F{fid}');ax.grid(alpha=.2);ax.set_xlabel('True FE (thousands)');ax.set_ylabel('Mean error')
axes.flat[-1].axis('off'); handles,labels=axes.flat[0].get_legend_handles_labels();fig.legend(handles,labels,loc='lower center',ncol=3,fontsize=10);fig.suptitle('CEC2017, D50, 100k FE, 30 seeds; display floor 1e-8');fig.tight_layout(rect=(0,.065,1,.975));fig.savefig(out/'all29_convergence.png',dpi=180);plt.close(fig)
fig,ax=plt.subplots(figsize=(8,4));rr=rank.mean().sort_values();ax.barh(rr.index,rr.values,color=[colors[x] for x in rr.index]);ax.invert_yaxis();ax.set_xlabel('Average rank across 29 function means (lower is better)');ax.set_xlim(0,len(methods)+.2)
for ix,val in enumerate(rr):ax.text(val+.04,ix,f'{val:.3f}',va='center')
fig.tight_layout();fig.savefig(out/'mean_ranks.png',dpi=180);plt.close(fig)
ratios=pd.DataFrame({c:np.maximum(means['SAQ-CSO'],1e-12)/np.maximum(means[c],1e-12) for c in methods if c!='SAQ-CSO'})
ratios.to_csv(out/'error_ratios.csv');fig,ax=plt.subplots(figsize=(12,4.2))
for c in ratios:ax.plot(range(len(ratios)),np.log10(ratios[c]),'o-',ms=3,lw=1,label=c,color=colors[c])
ax.axhline(0,color='black',lw=.7);ax.set_xticks(range(len(ratios)));ax.set_xticklabels([f'F{x}' for x in ratios.index]);ax.set_ylabel('log10(SAQ mean error / control mean error)');ax.grid(alpha=.2);ax.legend(fontsize=8);fig.tight_layout();fig.savefig(out/'all29_error_ratios.png',dpi=180);plt.close(fig)
result={'Runs':len(df),'Functions':29,'Seeds':30,'Budget':100000,'Dimension':50,'Methods':methods,'Ranks':rank.mean().to_dict(),'MeanSeconds':runtime['mean'].to_dict(),'Comparisons':over.to_dict(orient='records'),'ArtifactVerificationPassed':True,'HCLPSOReferenceSuperseded':bool(a.hclpso),'HIDMSAdded':bool(a.hidms),'NewBaselineRunDirectory':str(nb),'NewRuns':1204,'CachedHPSORuns':536,'Population':{c:int(df[df.Condition==c].Population.iloc[0]) for c in methods},'OriginalRunsDirectory':str(base),'HCLPSORunDirectory':str(a.hclpso) if a.hclpso else None,'HIDMSRunDirectory':str(a.hidms) if a.hidms else None}
(out/'overall.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
report=['# SAQ-CSO七算法同预算比较结果（2026-10-13）','','D50、100k真实FE、29函数、30新种子；所有函数均纳入，未删不利结果。',f'有效质量记录{len(df)}；独立MAT核验{checks}；870组初始种群共享；HIDMS取前40点，DMS取前30点，其余方法50点。','','|算法|平均排名|平均CPU秒/运行|','|---|---:|---:|']
for c in rr.index:report.append(f'|{c}|{rr[c]:.3f}|{runtime.loc[c,"mean"]:.3f}|')
report+=['','|SAQ对照|函数均值胜/负/平|配对seed胜/负/平|全比较族Holm显著好/差/未显著|','|---|---|---|---|']
for row in over.itertuples():report.append(f'|{row.Control}|{row.MeanWins}/{row.MeanLosses}/{row.MeanTies}|{row.SeedWins}/{row.SeedLosses}/{row.SeedTies}|{row.HolmAllBetter}/{row.HolmAllWorse}/{row.HolmAllNS}|')
report+=['','均值胜负不等于显著胜负。每函数30配对种子采用双侧Wilcoxon（正态近似、tie及连续性校正），全比较族Holm控制；附表同时给每对照29检验族校正。Friedman以29函数均值为block，不把870个seed当独立问题。','',f'Friedman statistic={stat:.6g}, p={pvalue:.6g}。该总体差异检验本身不表示SAQ对每个方法更优。','','SAQ运行时显著高于PSO基线；这里不支持同FE更快。CEC目标很便宜，候选生成/筛选时间不能忽略。不同补跑时段的CPU比较仅描述性报告。','','Q日志从MAT重新统计；原CSV action share字段为NaN属于汇总缺失，不等于Q未执行。修复汇总后输出q_behavior.csv及q_tables.csv，原始CSV保留。','','这批外部比较不证明新增Q优于固定6T4S，不证明稀疏筛选独立贡献；核心消融仍需同骨架Fixed4/Fixed6/同触发Random和无稀疏评价控制。标准500k、其它维度、无人机应用尚不在本结果范围。']
if not a.hclpso:report+=['','**HCLPSO仍是之前的Reference移植版，正在作者代码校正；本报告为旧批次描述，不能作为最终HCLPSO正式表。**']
else:report+=['','HCLPSO主列已替换为作者MATLAB profile；旧Reference列另存historical_hclpso_reference_runs.csv，未删除。来源与32组逐点核验见docs/HCLPSO_AUTHOR_CORRECTION_20261013.md。']
if a.hidms:report+=['','HIDMS为2020作者源码、N40、含公开注明的最佳从粒子局部索引修正；与N50算法共享初始前40点。同FE公平，但不假称完全相同人口规模。']
report+=['','新增HPSO-TVAC为2017独立baseline参考实现+公开披露的CEC位置clip；DMS为SIS2005基础版本的论文重建（N30、m3/R5/90%计划代切global），不是含Quasi-Newton的DMS-L-PSO。来源、逐点对照及独立手算见docs/HPSO_DMS_PROTOCOL_20261013.md。','', '本批新增1204次优化运行；HPSO已有有效536次缓存，已有五算法4350次经source/MAT/p0核验后复用。旧固定惯性DMS的536次记录另存并排除，不是凭性能挑版本。七算法平均排名与174个SAQ-vs-control检验族Holm重新计算，不与五算法116检验族结果混用。']
(out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2));print('OUTPUT',out)
