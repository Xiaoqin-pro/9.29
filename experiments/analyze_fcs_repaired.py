from pathlib import Path
import sys,json,hashlib,itertools
import numpy as np,pandas as pd
from scipy.io import loadmat

def md(df):
    def val(x):return format(x,'.6g') if isinstance(x,(float,np.floating)) else str(x)
    lines=['| '+' | '.join(map(str,df.columns))+' |','| '+' | '.join(['---']*len(df.columns))+' |']
    lines.extend('| '+' | '.join(val(x) for x in row)+' |' for row in df.itertuples(index=False,name=None))
    return chr(10).join(lines)
def signed_rank_p(x):
    x=np.asarray(x);x=x[x!=0]
    if not len(x):return 1.
    w=np.rint(2*pd.Series(np.abs(x)).rank().to_numpy()).astype(int);observed=abs(int(np.dot(w,np.sign(x).astype(int))))
    scores=[abs(int(np.dot(w,s))) for s in itertools.product([-1,1],repeat=len(w))]
    return sum(v>=observed for v in scores)/len(scores)

out=Path(sys.argv[1]).resolve();root=Path(__file__).resolve().parents[1];raw=pd.read_csv(out/'raw_runs.csv');manifest=pd.read_csv(out/'job_manifest.csv')
assert (out/'COMPLETED.json').exists() and len(raw)==len(manifest)==341 and raw.JobID.is_unique and raw.Status.eq('ok').all()
pd.testing.assert_frame_equal(raw[manifest.columns].sort_values('JobID').reset_index(drop=True),manifest.sort_values('JobID').reset_index(drop=True),check_dtype=False)
assert (raw.ObjectiveCalls==raw.Budget).all() and (raw.Evaluations==raw.Budget).all() and raw.OutsideCalls.eq(0).all() and raw.PostRunRecheckCalls.eq(1).all()
assert raw.TraceFinite.eq(True).all() and raw.TraceMonotone.eq(True).all()
conditional=[];global_feedback=[];audited_decisions=0
for _,r in raw.iterrows():
    m=loadmat(out/'runs'/f'job_{int(r.JobID):04d}.mat',simplify_cells=True);I=m['I'];B=m['B'];T=np.asarray(m['T'],dtype=float).ravel()
    assert len(T)==r.Budget and np.isfinite(T).all() and (np.diff(T)<=0).all() and T[-1]==float(B['Cost'])
    assert (np.abs(B['Vector'])<=100).all() and int(I['TracingEvaluations'])+int(I['SeekingEvaluations'])==r.Budget-50
    if r.Method=='B10-Reference':continue
    assert int(I['ActualMaxParentEvaluations'])<=2 and int(I['FallbackCount'])==int(I['ActionMismatchCount'])==int(I['QFallbackUpdates'])==0
    executed=np.asarray(I['ExecutedActionCounts'],dtype=float);counts=np.asarray(I['ConditionalFollowCounts'],dtype=float);wins=np.asarray(I['ConditionalFollowSuccesses'],dtype=float);gains=np.asarray(I['ConditionalFollowGain'],dtype=float)
    assert counts.sum()==executed.sum() and wins.sum()==int(I['SecondEvaluationSuccesses'])
    assert int(I['SameParentSecondEvaluations'])==executed[0]
    assert int(I['OtherParentSecondEvaluations'])+int(I['OpenedParentEvaluations'])==executed[1]
    assert abs(float(I['FirstVisitEvaluations'])/float(I['Rounds'])-float(I['MeanParentCoverage']))<1e-12
    for s in range(6):
        for a in range(2):
            n=int(counts[s,a]);conditional.append(dict(Cohort=r.Cohort,FunctionID=int(r.FunctionID),Seed=int(r.Seed),Method=r.Method,State=s+1,Phase=s//2,StarterImproved=(s%2==0),ActualAction=a+1,Trials=n,Successes=int(wins[s,a]),SuccessRate=float(wins[s,a]/n) if n else np.nan,GainSum=float(gains[s,a])))
    L=np.asarray(I['DecisionLog'],dtype=float)
    if L.size:
        L=L.reshape(-1,21);audited_decisions+=len(L)
        assert (L[:,7]==1+(L[:,8]!=L[:,3])).all() and (L[:,10]<=1).all()
        assert (L[:,5]==(L[:,17]<L[:,16])).all() and (L[:,12]==(L[:,19]<L[:,18])).all() and (L[:,13]==2*L[:,12]-1).all()
        assert ((np.floor((L[:,9]-1)/5)+1)==L[:,8]).all() and ((np.floor((L[:,4]-1)/5)+1)==L[:,3]).all()
        for fe_col,value_col in [(1,17),(15,19)]:
            fe=L[:,fe_col].astype(int);assert np.array_equal(T[fe-1],np.minimum(T[fe-2],L[:,value_col]))
        followFE=L[:,15].astype(int);globalImproved=T[followFE-1]<T[followFE-2];globalGain=T[followFE-2]-T[followFE-1]
        for s in range(1,7):
            for action in [1,2]:
                mask=(L[:,2]==s)&(L[:,7]==action);n=int(mask.sum());local=L[mask,12].astype(bool)
                global_feedback.append(dict(FunctionID=int(r.FunctionID),Seed=int(r.Seed),Method=r.Method,State=s,Phase=(s-1)//2,StarterImproved=(s%2==1),ActualAction=action,Trials=n,LocalSuccesses=int(local.sum()),GlobalSuccesses=int(globalImproved[mask].sum()),LocalOnlySuccesses=int((local&~globalImproved[mask]).sum()),GlobalGain=float(globalGain[mask].sum())))
        same=L[:,7]==1;positive=same & (L[:,5]==1);assert (L[same,10]==1).all() and (L[positive,18]==L[positive,17]).all()
        if r.Method=='FCS-continue':assert same.all()
        if r.Method=='FCS-switch':assert (~same).all()
        if r.Method=='FCS-success':assert (L[:,6]==1+(L[:,5]==0)).all()
        if r.Method=='FCS-reverse':assert (L[:,6]==1+L[:,5]).all()
    elif r.AuditDecisions and r.Method!='FCS-batch':raise AssertionError('Missing decision log')

pilot=raw[raw.Cohort.eq('pilot')];assert len(pilot)==320
summary=pilot.groupby(['FunctionID','Method']).agg(Runs=('FinalError','size'),MeanError=('FinalError','mean'),MedianError=('FinalError','median'),StdError=('FinalError','std'),MeanSeconds=('Seconds','mean')).reset_index()
means=summary.pivot(index='FunctionID',columns='Method',values='MeanError');ranks=means.rank(axis=1,method='average')
summary.to_csv(out/'summary_by_function.csv',index=False);means.to_csv(out/'mean_error_table.csv');(out/'mean_error_table.md').write_text(md(means.reset_index()),encoding='utf-8')
overall=[]
for method in means:
    d=pilot[pilot.Method.eq(method)];overall.append(dict(Method=method,MeanFunctionRank=float(ranks[method].mean()),FunctionsBest=int(means[method].eq(means.min(axis=1)).sum()),MeanSeconds=float(d.Seconds.mean()),Runs=len(d)))
overall=pd.DataFrame(overall).sort_values('MeanFunctionRank');overall.to_csv(out/'overall_summary.csv',index=False)
pairs=[];stats=[]
for a,b in itertools.combinations(means.columns,2):
    data=pilot[pilot.Method.isin([a,b])].pivot(index=['FunctionID','Seed'],columns='Method',values='FinalError');diff=data[a]-data[b];local=[]
    for fid,x in diff.groupby(level=0):local.append(dict(MethodA=a,MethodB=b,FunctionID=int(fid),Pairs=len(x),PValue=signed_rank_p(x.to_numpy()),AWins=int((x<0).sum()),BWins=int((x>0).sum())))
    order=np.argsort([s['PValue'] for s in local]);previous=0.
    for k,j in enumerate(order):previous=max(previous,min(1.,local[j]['PValue']*(len(local)-k)));local[j]['PHolm8']=previous
    stats.extend(local);pairs.append(dict(MethodA=a,MethodB=b,FunctionMeanAWins=int((means[a]<means[b]).sum()),FunctionMeanBWins=int((means[a]>means[b]).sum()),FunctionMeanTies=int((means[a]==means[b]).sum()),SeedAWins=int((diff<0).sum()),SeedBWins=int((diff>0).sum()),SeedTies=int((diff==0).sum())))
pd.DataFrame(pairs).to_csv(out/'pairwise_comparison.csv',index=False);pd.DataFrame(stats).to_csv(out/'paired_statistics.csv',index=False)
metrics=pilot.groupby('Method')[['Seconds','MeanParentCoverage','ExecutedContinue','ExecutedSwitch','SameParentSecondEvaluations','OtherParentSecondEvaluations','OpenedParentEvaluations','SecondEvaluationSuccesses','QUpdates','FallbackCount','ActionMismatchCount']].mean();metrics.to_csv(out/'policy_metrics.csv')
cond=pd.DataFrame(conditional);cond.to_csv(out/'conditional_follow_runs.csv',index=False)
cg=cond.groupby(['Cohort','FunctionID','Method','State','Phase','StarterImproved','ActualAction'])[['Trials','Successes','GainSum']].sum().reset_index();cg['SuccessRate']=cg.Successes/cg.Trials.replace(0,np.nan);cg.to_csv(out/'conditional_follow_by_function.csv',index=False)
gf=pd.DataFrame(global_feedback);gf['LocalSuccessRate']=gf.LocalSuccesses/gf.Trials.replace(0,np.nan);gf['GlobalSuccessRate']=gf.GlobalSuccesses/gf.Trials.replace(0,np.nan);gf.to_csv(out/'diagnostic_global_feedback.csv',index=False)
source_manifest={}
for p in (out/'source_snapshot').rglob('*'):
    if p.is_file():
        content=p.read_bytes();normalized=content.replace(bytes([13,10]),bytes([10]));source_manifest[str(p.relative_to(out/'source_snapshot'))]={'sha256_execution_bytes':hashlib.sha256(content).hexdigest(),'sha256_LF_normalized':hashlib.sha256(normalized).hexdigest()}
(out/'source_manifest.json').write_text(json.dumps(source_manifest,indent=2),encoding='utf-8')
checks={'Runs':len(raw),'PilotRuns':len(pilot),'DiagnosticRuns':len(raw)-len(pilot),'AuditedDecisionRows':audited_decisions,'ActualCalls':int(raw.ObjectiveCalls.sum()),'AllIndependentBudgetChecks':True,'AllTraceAndBestChecks':True,'AllDomainChecks':True,'Fallbacks':0,'ActionMismatches':0,'QFallbackCredits':0,'ExecutionRepair':'passed','ClaimStatus':'development pilot; not a confirmed paper innovation'}
(out/'integrity_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
lines=['# FCS修复后开发结果','',f'341次运行全部有效，独立复核{audited_decisions}条决策日志。','',md(overall),'','## 两两胜负（函数均值、逐seed；非显著胜场）','',md(pd.DataFrame(pairs)),'','## 执行指标','',md(metrics.reset_index()),'','## 解释范围','','FCS组内共有搜索内核、候选排序、Tracing、奖励和参数。B10使用不同Tracing筛选和候选分配，仅为质量参照。Switch保留不同父代语义，可能评价其他父代的第二候选，不自动等于Open。Q nextState保留旧即时follow-up解释，此结果只检验这个小控制器，不证明长期规划或一般Q-learning无效。','','8函数5seed是开发筛选；参考几何是借用组件，不作为创新；局部成功率与最终质量必须分开。决策内样本非独立实验重复，跨函数原始gain不作统一性能指标。5seed的精确双侧符号秩最小p为0.0625，显著性推断有限。']
(out/'RESULTS_REPORT.md').write_text(chr(10).join(lines),encoding='utf-8')
print(overall.to_string(index=False));print(pd.DataFrame(pairs).query("MethodA=='FCS-q' or MethodB=='FCS-q'").to_string(index=False));print(metrics.to_string());print(json.dumps(checks,indent=2))
if len(sys.argv)>2:
    public=Path(sys.argv[2]).resolve();public.mkdir(parents=True,exist_ok=True)
    names=['raw_runs.csv','job_manifest.csv','summary_by_function.csv','mean_error_table.csv','mean_error_table.md','overall_summary.csv','pairwise_comparison.csv','paired_statistics.csv','policy_metrics.csv','conditional_follow_by_function.csv','diagnostic_global_feedback.csv','source_manifest.json','integrity_checks.json','RESULTS_REPORT.md']
    for name in names:
        text=(out/name).read_text(encoding='utf-8');(public/name).write_text(chr(10).join(text.splitlines())+chr(10),encoding='utf-8')
    for name in ['behavior_checks.json','tail_witness.csv']:
        text=(root/'work/fcs_repair_20261012'/name).read_text(encoding='utf-8');(public/name).write_text(chr(10).join(text.splitlines())+chr(10),encoding='utf-8')
    (public/'README.md').write_text('# FCS修复开发证据（2026-10-12）'+chr(10)+chr(10)+'源码修复提交：931e52a。原始运行目录：'+out.name+chr(10)+'原协议：docs/FCS_REPAIR_PROTOCOL_20261012.md。MAT完整轨迹和点级日志保存在本地results/cec对应目录；此处上传完整运行CSV、比较/条件统计、行为验收和执行源码指纹。'+chr(10)+'运行：MATLAB setup_project(true); addpath experiments; run_fcs_repaired_pilot; 分析：python experiments/analyze_fcs_repaired.py <run-dir> <public-dir>，需要numpy/pandas/scipy。'+chr(10)+'CSV文字已统一LF；source_manifest同时给实际执行字节hash和LF归一hash，以兼容Git行尾转换。'+chr(10),encoding='utf-8')
    published={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in public.iterdir() if p.is_file() and p.name!='published_sha256.json'}
    (public/'published_sha256.json').write_text(json.dumps(published,indent=2),encoding='utf-8')
