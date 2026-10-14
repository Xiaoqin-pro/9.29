"""Summarize completed elite-probe pilots without selecting favorable runs."""
from pathlib import Path
import argparse, json, hashlib
import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('raw_directory',type=Path)
parser.add_argument('--parent',type=Path)
args=parser.parse_args()
folder=args.raw_directory
cfg=json.loads((folder/'config.json').read_text(encoding='utf-8'))
status=json.loads((folder/'status.json').read_text(encoding='utf-8'))
assert status['Status']=='complete' and status['SnapshotHashesVerified']
raw=pd.read_csv(folder/'raw_runs.csv')
assert len(raw)==cfg['Runs'] and raw.Status.eq('ok').all()
assert raw.ObjectiveCalls.eq(cfg['Budget']).all() and raw.Evaluations.eq(cfg['Budget']).all()
assert raw.OutsideCalls.eq(0).all()
assert not raw.duplicated(['FunctionID','Seed','Method']).any()
assert raw.groupby(['FunctionID','Method']).size().eq(len(cfg['Seeds'])).all()
if args.parent:
    parent_cfg=json.loads((args.parent/'config.json').read_text(encoding='utf-8'))
    parent=pd.read_csv(args.parent/'raw_runs.csv')
    acceptance=cfg['Acceptance']
    rule='ELS-Replace' if acceptance=='replace' else 'ELS-Greedy'
    refs=parent[parent.Method.isin(['Fixed6',rule])]
    raw=pd.concat([refs,raw],ignore_index=True)
    a=pd.read_csv(args.parent/'prelaunch_hashes.csv');b=pd.read_csv(folder/'prelaunch_hashes.csv')
    def engine_hash(h):
        return h[h.Path.str.replace(chr(92),'/',regex=False).str.endswith('/SAQ_CSO_EliteProbe.m')].SHA256.iloc[0]
    assert engine_hash(a)==engine_hash(b),'Policy and parent used different engine snapshots'
    def runtime_hashes(h):
        result={}
        for row in h.itertuples():
            path=row.Path.replace(chr(92),'/')
            if '/cec_data/' in path:
                result[path.split('/cec_data/',1)[1]]=row.SHA256
            elif path.endswith('/CEC2017Function.m'):
                result['CEC2017Function.m']=row.SHA256
        return result
    assert runtime_hashes(a)==runtime_hashes(b),'CEC snapshot mismatch'
    for col in ['FunctionIDs','Seeds','Dimension','Population','Budget','LowerBound','UpperBound','ProgressWindowFE','ProgressThreshold','EpisodeFE','SeedBase']:
        assert parent_cfg[col]==cfg[col], f'Configuration mismatch: {col}'
    for col in ['InitSeed','SearchSeed','ProbeSeed','PolicySeed']:
        assert raw.groupby(['FunctionID','Seed'])[col].nunique().eq(1).all()
else:
    rule='ELS-Replace'
name=f"saq_elite_probe_{cfg['Stage']}_{len(cfg['Seeds'])}seed_20261014"
output=ROOT/'results'/name;output.mkdir(exist_ok=True,parents=True)
raw.to_csv(output/'all_runs.csv',index=False)
means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack()
means.to_csv(output/'function_means.csv')
means.rank(axis=1).mean().rename('AverageRank').sort_values().to_csv(output/'mean_ranks.csv')
base=raw[raw.Method.eq('Fixed6')].set_index(['FunctionID','Seed']).FinalError
comparisons=[];function_rows=[];gate={}
for method in means.columns:
    if method=='Fixed6':continue
    sub=raw[raw.Method.eq(method)].set_index(['FunctionID','Seed']).FinalError.reindex(base.index)
    assert not sub.isna().any()
    delta=sub-base;ratio=means[method]/means['Fixed6']
    wins=int((ratio<1).sum());losses=int((ratio>1).sum());ties=int((ratio==1).sum())
    healthy=ratio.reindex([1,13,30]);healthy_not_worse=int((healthy<=1).sum())
    has_large_regression=bool((healthy>1.2).any())
    passed=bool(wins>=5 and ratio.median()<=.95 and healthy_not_worse>=2 and not has_large_regression)
    gate[method]={'MeanFunctionWins':wins,'MeanFunctionLosses':losses,'FunctionTies':ties,
        'MedianFunctionMeanErrorRatio':float(ratio.median()),'HealthyNotWorse':healthy_not_worse,
        'AnyHealthyRegressionOver20Percent':has_large_regression,'PassesPrespecifiedDevelopmentGate':passed}
    mraw=raw[raw.Method.eq(method)]
    comparisons.append({'Method':method,**gate[method], 'SeedWins':int((delta<0).sum()),'SeedLosses':int((delta>0).sum()),
        'SeedTies':int((delta==0).sum()),'ProbeEvaluations':int(mraw.ProbeEvaluations.sum()),
        'ProbeParentSuccesses':int(mraw.ProbeParentSuccesses.sum()),'ProbeGlobalSuccesses':int(mraw.ProbeGlobalSuccesses.sum()),
        'ProbeWritebacks':int(mraw.ProbeWritebacks.sum())})
    for fid in means.index:
        d=delta.loc[fid].to_numpy();p=1.0 if np.all(d==0) else float(wilcoxon(d,zero_method='wilcox',alternative='two-sided',method='auto').pvalue)
        function_rows.append({'FunctionID':int(fid),'Method':method,'BaseMean':float(means.loc[fid,'Fixed6']),
          'MethodMean':float(means.loc[fid,method]),'MeanErrorRatio':float(ratio.loc[fid]),
          'PairedSeedWins':int((d<0).sum()),'PairedSeedLosses':int((d>0).sum()),'PairedSeedTies':int((d==0).sum()),'WilcoxonP':p})
comparison=pd.DataFrame(comparisons);comparison.to_csv(output/'overall_comparisons.csv',index=False)
if args.parent:
    policy_comparisons=[]
    for ref,method in [(rule,'ELS-Random'),(rule,'ELS-Q'),('ELS-Random','ELS-Q')]:
        reference=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError
        values=raw[raw.Method.eq(method)].set_index(['FunctionID','Seed']).FinalError.reindex(reference.index)
        delta=values-reference
        ratios=means[method]/means[ref]
        policy_comparisons.append({'Reference':ref,'Method':method,'MeanWins':int((ratios<1).sum()),
          'MeanLosses':int((ratios>1).sum()),'MeanTies':int((ratios==1).sum()),
          'MedianFunctionMeanRatio':float(ratios.median()),'SeedWins':int((delta<0).sum()),
          'SeedLosses':int((delta>0).sum()),'SeedTies':int((delta==0).sum())})
        for fid in means.index:
            d=delta.loc[fid].to_numpy();p=1.0 if np.all(d==0) else float(wilcoxon(d,zero_method='wilcox',alternative='two-sided',method='auto').pvalue)
            function_rows.append({'FunctionID':int(fid),'Reference':ref,'Method':method,
              'BaseMean':float(means.loc[fid,ref]),'MethodMean':float(means.loc[fid,method]),
              'MeanErrorRatio':float(ratios.loc[fid]),'PairedSeedWins':int((d<0).sum()),
              'PairedSeedLosses':int((d>0).sum()),'PairedSeedTies':int((d==0).sum()),'WilcoxonP':p})
    pd.DataFrame(policy_comparisons).to_csv(output/'policy_comparisons.csv',index=False)
function_table=pd.DataFrame(function_rows)
if 'Reference' not in function_table:function_table['Reference']='Fixed6'
else:function_table['Reference']=function_table.Reference.fillna('Fixed6')
p=function_table.WilcoxonP.to_numpy();order=np.argsort(p);adjusted=np.empty(len(p));running=0
for k,i in enumerate(order):running=max(running,(len(p)-k)*p[i]);adjusted[i]=min(1,running)
function_table['HolmAdjustedP']=adjusted
function_table.to_csv(output/'function_comparisons.csv',index=False)
(output/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf-8')
(folder/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf-8')
for filename in ['run_diagnostics.csv','probe_diagnostics.csv','convergence_nodes.csv','policy_state_diagnostics.csv','config.json','preflight.csv','prelaunch_hashes.csv','checks.csv']:
    path=folder/filename
    if path.exists():
        (output/filename).write_bytes(path.read_bytes())
if args.parent:
    for filename in ['run_diagnostics.csv','probe_diagnostics.csv','convergence_nodes.csv','policy_state_diagnostics.csv']:
        path=args.parent/filename;current=folder/filename
        if path.exists() and current.exists():
            a=pd.read_csv(path);b=pd.read_csv(current)
            pd.concat([a[a.Method.isin(['Fixed6',rule])],b],ignore_index=True).to_csv(output/filename,index=False)
plt.rcParams.update({'font.family':'Microsoft YaHei','font.size':9,'axes.spines.top':False,
 'axes.spines.right':False,'axes.unicode_minus':False,'pdf.fonttype':42,'savefig.dpi':300})
labels_zh={'Fixed6':'固定6T/4S基线','ELS-Greedy':'探测＋贪心接受','ELS-Replace':'探测＋真实替换（规则）','ELS-Random':'随机调度探测','ELS-Q':'Q学习调度探测'}
stage_zh={'mechanism':'算子','policy':'调度'}
curvepath=output/'convergence_nodes.csv'
if curvepath.exists():
    curves=pd.read_csv(curvepath).groupby(['FunctionID','Method','FE']).BestError.mean()
    fig,axes=plt.subplots(2,4,figsize=(12,6.2));colors={'Fixed6':'#303030','ELS-Greedy':'#2166ac','ELS-Replace':'#d6604d','ELS-Random':'#7570b3','ELS-Q':'#1b9e77'}
    for ax,fid in zip(axes.flat,means.index):
        for method in means.columns:
            s=curves.loc[(fid,method)];ax.semilogy(s.index/1000,np.maximum(s.to_numpy(),1e-12),label=labels_zh[method],color=colors[method],lw=1.2)
        ax.set_title(f'F{fid}');ax.set_xlabel('真实评价（千次）');ax.set_ylabel('平均最优误差');ax.grid(alpha=.15)
    handles,labels=axes.flat[0].get_legend_handles_labels();fig.legend(handles,labels,loc='lower center',ncol=len(labels),frameon=False)
    fig.suptitle(f"单维精英探测{stage_zh[cfg['Stage']]}开发实验：D50 / 100k / {len(cfg['Seeds'])} 种子",fontsize=12)
    fig.tight_layout(rect=(0,.055,1,.96))
    for ext in ['png','pdf']:fig.savefig(output/f'convergence.{ext}',bbox_inches='tight')
    plt.close(fig)
analysis_source=output/'analysis_source';analysis_source.mkdir(exist_ok=True)
for path in [Path(__file__),ROOT/'experiments/export_saq_elite_probe_diagnostics.m']:
    (analysis_source/path.name).write_bytes(path.read_bytes())
manifest={'Date':'2026-10-14','RawDirectory':str(folder),'ParentDirectory':str(args.parent) if args.parent else None,
 'NewPerformanceRuns':cfg['Runs'],'NewOptimizationCalls':int(pd.read_csv(folder/'raw_runs.csv').ObjectiveCalls.sum()),
 'Seeds':cfg['Seeds'],'Scope':'Development pilot; not the final 29-function confirmation',
 'GatePrespecifiedBeforeResults':True,'PValues':'Paired Wilcoxon; Holm across all function-method contrasts in this report',
 'PostProbeGains':'Descriptive subsequent-search gains, not isolated causal effects of a single probe','Inputs':[]}
for path in [folder/'raw_runs.csv',folder/'config.json',folder/'prelaunch_hashes.csv',Path(__file__),ROOT/'experiments/export_saq_elite_probe_diagnostics.m']:
    manifest['Inputs'].append({'Path':str(path),'SHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
(output/'analysis_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# 单维精英探测开发结果（2026-10-14）','',f"范围：{cfg['Stage']}，D50/100k，8函数/{len(cfg['Seeds'])}种子；独立目标调用与运行后重算检查通过。",'',
 '| 方法 | 函数均值胜/负/平 | 配对种子胜/负/平 | 函数均值比中位数 | 探测/父代成功/全局成功/写回 | 原定开发门 |',
 '|---|---:|---:|---:|---:|---|']
for r in comparisons:
    lines.append(f"| {r['Method']} | {r['MeanFunctionWins']}/{r['MeanFunctionLosses']}/{r['FunctionTies']} | {r['SeedWins']}/{r['SeedLosses']}/{r['SeedTies']} | {r['MedianFunctionMeanErrorRatio']:.4f} | {r['ProbeEvaluations']}/{r['ProbeParentSuccesses']}/{r['ProbeGlobalSuccesses']}/{r['ProbeWritebacks']} | {'通过' if r['PassesPrespecifiedDevelopmentGate'] else '未通过'} |")
lines+=['','胜负按最终均值直接比较；正式显著性结论需查看 function_comparisons.csv。未按跨函数原始误差求和挑选版本。',
 '开发门：至少5/8函数均值更好，函数均值比中位数≤0.95，F1/F13/F30至少两项不退化，并检查任一健康函数超过20%的退化。',
 '所有240次机制实验和后续调度实验的负面结果均保留；原冻结方法及论文仍是独立版本。','',f'逐运行MAT、冻结源码与CEC数据保存在：{folder}。']
if args.parent:
    lines+=['','## 调度相对规则和随机的直接比较','','| 对照 | 方法 | 函数均值胜/负/平 | 函数均值比中位数 | 配对种子胜/负/平 |','|---|---|---:|---:|---:|']
    for r in policy_comparisons:
        lines.append(f"| {r['Reference']} | {r['Method']} | {r['MeanWins']}/{r['MeanLosses']}/{r['MeanTies']} | {r['MedianFunctionMeanRatio']:.4f} | {r['SeedWins']}/{r['SeedLosses']}/{r['SeedTies']} |")
(output/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(comparison.to_string(index=False));print('Saved summary:',output)
