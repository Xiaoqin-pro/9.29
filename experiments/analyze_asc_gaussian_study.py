"""Independent artifact and paired statistical analysis of A0-A3 protected probes."""
from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import wilcoxon,rankdata
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run',type=Path);args=p.parse_args();run=args.run
cfg=json.loads((run/'config.json').read_text(encoding='utf8'));status=json.loads((run/'status.json').read_text(encoding='utf8'))
assert status['Status']=='complete' and status['Completed']==320
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256
raw=pd.read_csv(run/'raw_runs.csv');assert len(raw)==320 and raw.Status.eq('ok').all()
assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.OutsideCalls.eq(0).all()
assert raw.BestDiff.eq(0).all() and raw.ObservedTraceMaxDiff.eq(0).all() and raw.ProbeRecheckMaxDiff.eq(0).all()
assert set(raw.Seed)==set(range(6001,6011)) and set(raw.FunctionID)==set([1,6,9,12,13,21,24,27]) and set(raw.Method)==set(['A0','A1','A2','A3'])
assert not raw.duplicated(['FunctionID','Seed','Method']).any() and raw.groupby(['FunctionID','Seed']).Method.nunique().eq(4).all()
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed','ProbeSeed']].nunique().eq(1).all().all()
out=ROOT/'results/asc_gaussian_10seed_20261015';out.mkdir(exist_ok=True,parents=True)
methods=['A0','A1','A2','A3'];nodes=np.unique(np.r_[50,1000,np.linspace(2000,100000,101).round().astype(int),10000,20000,40000,60000,80000,100000])
curves=[];checks=[];probe_rows=[];diag=[];phase=[];pools={};params_reference=None
for n,row in enumerate(raw.itertuples(),1):
    z=loadmat(run/'runs'/row.Artifact,simplify_cells=True);I=z['I'];T=np.asarray(z['T']).reshape(-1);B=z['B'];p0=np.atleast_2d(z['p0']);R=np.atleast_2d(I['RoundLog']);P=I['Parameters'];L=np.asarray(I['ProbeLog'])
    key=(row.FunctionID,row.Seed)
    if key not in pools:pools[key]=p0
    assert np.array_equal(pools[key],p0) and np.array_equal(I['InitialPopulation'],p0)
    assert T.size==100000 and np.isfinite(T).all() and np.all(np.diff(T)<=0) and T[-1]==B['Cost']
    assert np.isclose(T[-1],row.FinalCost,rtol=1e-12,atol=1e-9) and np.isclose(row.FinalError,row.FinalCost-100*row.FunctionID,rtol=1e-12,atol=1e-9)
    assert np.all((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100))
    assert I['Evaluations']==100000 and R.shape==(9995,18) and R[0,0]==50 and R[-1,1]==100000
    assert np.array_equal(R[1:,0],R[:-1,1]) and np.array_equal(R[:,1]-R[:,0],R[:,2]) and np.all(R[:,2]==10)
    assert np.array_equal(R[:,16]+R[:,15],R[:,2]) and np.array_equal(R[:,12],R[:,16])
    expected=0 if row.Method=='A0' else 1999
    assert row.ProbeEvaluations==I['ProbeEvaluations']==expected and R[:,15].sum()==expected
    assert row.PostRunRecheckCalls==1+expected
    assert P['probeVariant']==row.Method and P['probeDims']==5 and P['probeEveryRounds']==5 and P['probeSeed']==row.ProbeSeed
    assert P['probeSigmaStart']==.05 and P['probeSigmaEnd']==.005 and P['jumpFraction']==.5 and bool(P['useJump'])
    params={k:v for k,v in P.items() if k not in ['probeVariant','probeSeed']}
    if params_reference is None:params_reference=params
    for k in params:assert np.array_equal(params[k],params_reference[k]),k
    # Independently replay the adaptive success buffer and strict-stall Jump clock.
    smooth=0.;buffer=np.zeros(100);ptr=0;count=0;last=50;stall=0
    for rr in R:
        before,after=int(rr[0]),int(rr[1]);improved=T[after-1]<T[before-1]
        assert abs(rr[3]-(.2+.7*(1-smooth)))<1e-12 and abs(rr[4]-(.02+.18*(1-smooth)))<1e-12
        buffer[ptr]=improved;ptr=(ptr+1)%100;count=min(count+1,100);success=buffer[:count].sum()/count
        smooth=np.clip(smooth+.05*((1-success)-smooth),0,1)
        assert abs(rr[5]-smooth)<1e-12 and abs(rr[7]-success)<1e-12
        if improved:last=after;stall=0
        else:stall+=1
        jumped=after-last>=1000;assert bool(rr[9])==jumped
        if jumped:last=after;stall=0
        assert rr[8]==stall
    assert int(R[:,9].sum())==I['Jumps']
    if expected:
        L=np.atleast_2d(L);points=np.atleast_2d(I['ProbePoints']);anchors=np.atleast_2d(I['ProbeAnchors']);dims=np.atleast_2d(I['ProbeDimensions']).astype(int)-1
        pre=np.atleast_2d(I['ProbePrePositions']);post=np.atleast_2d(I['ProbePostPositions']);vel=np.atleast_2d(I['ProbePostVelocity'])
        assert len(L)==expected and np.array_equal(L[:,1],np.arange(5,9996,5)) and np.array_equal(L[:,0],50+10*L[:,1])
        assert np.all(R[L[:,1].astype(int)-1,15]==1) and np.all(L[:,12]==9) and np.all(L[:,14]==1) and np.all(I['ProbeAnchorEligible'])
        assert np.all((points>=-100)&(points<=100)) and dims.shape==(1999,5)
        assert all(len(set(d))==5 for d in dims)
        mask=np.ones_like(points,dtype=bool);mask[np.arange(expected)[:,None],dims]=False
        assert np.array_equal(points[mask],anchors[mask])
        expected_sigma=.05+(.005-.05)*(50+10*(L[:,1]-1)-50)/99950
        assert np.allclose(L[:,4],expected_sigma,rtol=1e-12,atol=1e-15)
        assert np.array_equal(L[:,6]<L[:,5],L[:,9]>0) and np.array_equal(L[:,6]<L[:,7],L[:,10]>0)
        assert np.array_equal(T[L[:,0].astype(int)-1],L[:,8])
        accept=L[:,9]>0;assert np.array_equal(post[accept],points[accept]) and np.all(vel[accept]==0)
        assert np.array_equal(post[~accept],pre[~accept]) and np.array_equal(L[accept,13],L[accept,6]) and np.array_equal(L[~accept,13],L[~accept,5])
        if row.Method=='A2':assert np.all(L[:,3]==0)
        else:assert np.all(L[:,3]>=1) and np.all(L[:,3]<=50)
        assert row.ProbeParentSuccesses==L[:,9].sum() and row.ProbeGlobalSuccesses==L[:,10].sum()
        for j,rr in enumerate(L):
            fe=int(rr[0]);end=min(100000,fe+1000)
            probe_rows.append((row.FunctionID,row.Seed,row.Method,fe,int(rr[1]),int(rr[2]),int(rr[3]),float(rr[4]),float(rr[5]),float(rr[6]),float(rr[7]),float(rr[8]),int(rr[9]),int(rr[10]),int(rr[11]),end-fe,float(T[fe-1]-T[end-1])))
    for fe in nodes:curves.append((row.FunctionID,row.Seed,row.Method,int(fe),float(T[fe-1]-100*row.FunctionID)))
    for start,end in [(50,20000),(20000,60000),(60000,80000),(80000,100000)]:
        part=R[(R[:,0]>=start)&(R[:,1]<=end)]
        phase.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,StartFE=start,EndFE=end,
            RelativeDrop=float((T[start-1]-T[end-1])/max(T[start-1]-100*row.FunctionID,1e-300)),Jumps=int(part[:,9].sum()),MeanRadius=part[:,4].mean(),MeanSeekProbability=part[:,3].mean()))
    diag.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,ProbeFE=expected,ProbeParentSuccesses=int(I['ProbeParentSuccesses']),ProbeGlobalSuccesses=int(I['ProbeGlobalSuccesses']),Jumps=int(I['Jumps']),FinalRadius=I['FinalRadius'],FinalSeekProb=I['FinalSeekProb']))
    checks.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Method=row.Method,Passed=True,StateAndJumpReplayed=True,ProtectedBudgetVerified=True,ProbeAcceptanceVerified=True))
    if n%80==0:print('Artifact audit',n,'/320',flush=True)
raw.to_csv(out/'all_runs.csv',index=False);pd.DataFrame(checks).to_csv(out/'integrity_checks.csv',index=False)
curves=pd.DataFrame(curves,columns=['FunctionID','Seed','Method','FE','BestError']);curves.to_csv(out/'convergence_nodes.csv',index=False)
probes=pd.DataFrame(probe_rows,columns=['FunctionID','Seed','Method','FE','Round','Carrier','Anchor','Sigma','CarrierPbestBefore','ProbeCost','BestBefore','BestAfter','PbestSuccess','GlobalSuccess','ReplacedCandidateRow','ObservedNextHorizon','ObservedGainNext1000FE'])
probes.to_csv(out/'probe_events.csv.gz',index=False,compression={'method':'gzip','mtime':0});diag=pd.DataFrame(diag);diag.to_csv(out/'probe_run_summary.csv',index=False)
summ=diag.groupby(['Method'])[['ProbeFE','ProbeParentSuccesses','ProbeGlobalSuccesses','Jumps']].sum()
summ['PbestAcceptanceRate']=summ.ProbeParentSuccesses/summ.ProbeFE.replace(0,np.nan);summ['GlobalSuccessRate']=summ.ProbeGlobalSuccesses/summ.ProbeFE.replace(0,np.nan);summ.to_csv(out/'probe_summary.csv')
diag.groupby(['FunctionID','Method'])[['ProbeFE','ProbeParentSuccesses','ProbeGlobalSuccesses','Jumps','FinalRadius','FinalSeekProb']].mean().to_csv(out/'probe_function_summary.csv')
phase=pd.DataFrame(phase);phase.to_csv(out/'phase_runs.csv',index=False);phase.groupby(['FunctionID','Method','StartFE','EndFE'])[['RelativeDrop','Jumps','MeanRadius','MeanSeekProbability']].mean().to_csv(out/'phase_summary.csv')
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods);std=raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods);med=raw.groupby(['FunctionID','Method']).FinalError.median().unstack().reindex(columns=methods)
for name,d in [('function_means.csv',means),('function_std.csv',std),('function_medians.csv',med)]:d.to_csv(out/name)
means.rank(axis=1).mean().sort_values().rename('AverageRank').to_csv(out/'mean_ranks.csv')
pairs=[('A1','A0'),('A2','A0'),('A3','A0'),('A3','A1'),('A3','A2')];comparisons=[];detail=[]
for method,ref in pairs:
    b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError;a=raw[raw.Method.eq(method)].set_index(['FunctionID','Seed']).FinalError.reindex(b.index)
    delta=a-b;ratio=means[method]/means[ref]
    comparisons.append(dict(Method=method,Reference=ref,MeanWins=int((ratio<1).sum()),MeanLosses=int((ratio>1).sum()),MeanTies=int((ratio==1).sum()),MedianMeanRatio=float(ratio.median()),SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),SeedTies=int((delta==0).sum())))
    for fid in means.index:
        d=delta.loc[fid].to_numpy();nz=d[d!=0];pv=1. if not len(nz) else float(wilcoxon(d,zero_method='wilcox',method='auto').pvalue)
        rb=0. if not len(nz) else float(np.sum(rankdata(abs(nz))*np.sign(-nz))/sum(rankdata(abs(nz))))
        detail.append(dict(FunctionID=int(fid),Method=method,Reference=ref,MeanRatio=float(ratio.loc[fid]),WilcoxonP=pv,RankBiserial=rb,SeedWins=int((d<0).sum()),SeedLosses=int((d>0).sum()),SeedTies=int((d==0).sum())))
comp=pd.DataFrame(comparisons);comp.to_csv(out/'comparisons.csv',index=False);detail=pd.DataFrame(detail);pv=detail.WilcoxonP.to_numpy();adj=np.empty(len(pv));running=0
for k,i in enumerate(np.argsort(pv)):running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
detail['Holm40']=adj;detail.to_csv(out/'function_comparisons.csv',index=False)
x=comp.set_index(['Method','Reference']);r0=means.A3/means.A0
checks_gate=dict(A3VsA0=bool(x.loc[('A3','A0'),'MeanWins']>=5 and x.loc[('A3','A0'),'MedianMeanRatio']<=.95),
 A3VsA1=bool(x.loc[('A3','A1'),'MeanWins']>=5 and x.loc[('A3','A1'),'MedianMeanRatio']<=1),
 A3VsA2=bool(x.loc[('A3','A2'),'MeanWins']>=5 and x.loc[('A3','A2'),'MedianMeanRatio']<=1),
 F6F9F24F27Guard=bool((r0.loc[[6,9,24,27]]<=1.1).all()),AllFunctionsGuard=bool((r0<=1.2).all()))
pre=json.loads((run/'preflight.json').read_text(encoding='utf8'));validation=json.loads((run/'validation.json').read_text(encoding='utf8'))
incident=ROOT/'work/asc_gaussian_initial_preflight_failure.json';inc=json.loads(incident.read_text(encoding='utf8')) if incident.exists() else None
summary=dict(Passed=all(checks_gate.values()),GateChecks=checks_gate,FreshRuns=320,OptimizationCalls=int(raw.ObjectiveCalls.sum()),AuditCalls=int(raw.PostRunRecheckCalls.sum()),
 FullBudgetParityCalls=pre['ObjectiveCalls'],FullBudgetParityRechecks=pre['RecheckCalls'],ValidationObjectiveCalls=validation['ValidationObjectiveCalls'],ValidationRechecks=validation['BestRecheckCalls'],
 PriorFailedPreflightCalls=inc['PreflightObjectiveCalls'] if inc else 0,NewSeedReplicates=True,UnseenFunctions=False,SeedRange=[6001,6010],Comparisons=comparisons)
for directory in [run,out]:(directory/'gate_decision.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf8')
if inc:(out/'prior_preflight_incident.json').write_text(json.dumps(inc,ensure_ascii=False,indent=2),encoding='utf8')
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9});colors={'A0':'#333333','A1':'#1b9e77','A2':'#2166ac','A3':'#d6604d'}
g=curves.groupby(['FunctionID','Method','FE']).BestError.mean();fig,axes=plt.subplots(2,4,figsize=(13,6.2))
for ax,fid in zip(axes.flat,cfg['Functions']):
    for method in methods:
        d=g.loc[(fid,method)];ax.semilogy(d.index/1000,d.clip(lower=1e-12),color=colors[method],label=method,lw=1.35)
    ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=4,frameon=False);fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
for name in ['config.json','validation.json','checks.csv','PROTOCOL.md','preflight.json','prelaunch_hashes.csv']:shutil.copyfile(run/name,out/name)
(out/'source').mkdir(exist_ok=True)
for name in ['ASC_NoFarness.m','ASC_NoFarness_EliteGaussian.m','run_asc_gaussian_job.m','run_asc_gaussian_study.m']:shutil.copyfile(run/'source'/name,out/'source'/name)
report=['# ASC精英引导稀疏探针：10种子开发实验','', 'D50/N50、100k真实评价、F1/F6/F9/F12/F13/F21/F24/F27、6001–6010、4worker；320次全新运行。参数与开发筛查在运行前固定。',
 '', '| 版本 | 探针 | 锚点 |','|---|---|---|','| A0 | 无，原ASC路径 | — |','| A1 | 5维等方差均匀扰动 | 随机前20%真实pbest精英 |','| A2 | 5维高斯扰动 | gbest |','| A3 | 5维高斯扰动 | 随机前20%真实pbest精英 |',
 '', '每第5轮将原sel最后一个名额替换为1个探针，100k内每次有1999个探针（A0为0），其余搜索与Jump参数不变。探针只有改善承载者真实pbest才接管位置并清零速度；失败不强制再播种。该接受规则与旧SAQ ELS-Replace不同。',
 '', '| 比较 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 |','|---|---:|---:|---:|']
for c in comparisons:report.append(f"| {c['Method']} vs {c['Reference']} | {c['MeanWins']}/{c['MeanLosses']}/{c['MeanTies']} | {c['SeedWins']}/{c['SeedLosses']}/{c['SeedTies']} | {c['MedianMeanRatio']:.4f} |")
report+=['',f"A3预定开发筛查：{'通过，需另行独立确认' if summary['Passed'] else '未通过，不晋级或在本批调参'}。具体条件见gate_decision.json。",'',
 '胜负为均值描述，不是显著优势；40项Holm见function_comparisons.csv。10种子两侧精确检验的最小P通常已大于40项Holm首项阈值，未显著不能写成等效。函数均已用于开发，本批新随机重复不是未见函数泛化。',
 '', '| FunctionID | A0 | A1 | A2 | A3 |','|---:|---:|---:|---:|---:|']
for fid,row in means.iterrows():report.append('| '+str(fid)+' | '+' | '.join(f'{v:.6g}' for v in row)+' |')
report+=['','## 真实调用与审计','',f"正式优化{summary['OptimizationCalls']:,}次调用，所有probe/Best运行后重评{summary['AuditCalls']:,}次；原版100k轨迹回归{summary['FullBudgetParityCalls']:,}加{summary['FullBudgetParityRechecks']}次重评；合成/CEC检查{summary['ValidationObjectiveCalls']:,}加{summary['ValidationRechecks']}次重评。初次运行器命名冲突的失败预检另有{summary['PriorFailedPreflightCalls']:,}次调用，未进入性能样本。",
 '320次运行的实际计数、独立best-so-far逐点核对、返回解/所有探针重评、保护名额/承载者/档案接受、Jump和自适应状态独立重放均通过。原算法源文件未修改。',
 '', 'probe_events.csv.gz的probe后1000FE收益仅描述后继搜索，不能把Tracing/Seeking/Jump共同产生的改善全部归功于探针。A3不胜A2则不支持多精英必要性；A3不胜A1则不支持高斯分布带来额外价值。',
 '',f'完整MAT与源码快照：{run}','']
(out/'REPORT.md').write_text(chr(10).join(report),encoding='utf8');print(comp.to_string(index=False));print(means.round(4).to_string());print(json.dumps(summary,ensure_ascii=False,indent=2));print(out)
