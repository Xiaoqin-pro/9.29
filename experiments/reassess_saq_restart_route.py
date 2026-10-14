"""Reassess the corrected restart pilot and frozen phase checkpoints.
No new CEC evaluations are performed. All plots use four observed nodes.
"""
from pathlib import Path
import hashlib, json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'work/saq_route_reassessment_20261014'
FIG = ROOT / 'figures/saq_route_reassessment_20261014'
OUT.mkdir(exist_ok=True, parents=True)
FIG.mkdir(exist_ok=True, parents=True)
PILOT = ROOT / 'results/cec/saq_restart_pilot_20261013_225210/raw_runs.csv'
MAIN = ROOT / 'results/saq_cso_main_five_30seed_20261013/all_quality_runs.csv'
pilot = pd.read_csv(PILOT)
assert len(pilot) == 320 and pilot.Status.eq('ok').all()
assert pilot.Dimension.eq(50).all() and pilot.Budget.eq(100000).all()
assert pilot.Evaluations.eq(100000).all()
assert not pilot.duplicated(['FunctionID', 'Seed', 'Method']).any()
assert pilot.groupby('Method').size().eq(80).all()
means = pilot.groupby(['FunctionID','Method']).FinalError.mean().unstack()
means.to_csv(OUT / 'corrected_restart_means.csv')
ranks = means.rank(axis=1).mean().sort_values()
ranks.rename('AverageRank').rename_axis('Method').to_csv(OUT/'corrected_restart_ranks.csv')
base = pilot[pilot.Method.eq('Sparse-Base')].set_index(['FunctionID','Seed']).FinalError
rows=[]
for method in ['Fixed-Restart','Random-Restart','Q-Restart']:
    a = pilot[pilot.Method.eq(method)]
    paired = a.set_index(['FunctionID','Seed']).FinalError.reindex(base.index)
    delta = paired - base
    mean_delta = means[method] - means['Sparse-Base']
    rows.append(dict(Method=method,MeanWins=int((mean_delta<0).sum()),MeanLosses=int((mean_delta>0).sum()),
      SeedWins=int((delta<0).sum()),SeedLosses=int((delta>0).sum()),Ties=int((delta==0).sum()),
      ProbeEvaluations=int(a.RestartEvaluations.sum()),ParentImprovements=int(a.RestartParentSuccesses.sum()),
      GlobalImprovements=int(a.RestartSuccesses.sum()),MedianErrorRatio=float((means[method]/means['Sparse-Base']).median())))
comparison=pd.DataFrame(rows)
comparison.to_csv(OUT/'corrected_restart_comparison.csv',index=False)

main=pd.read_csv(MAIN)
assert len(main)==4350 and main.Status.eq('ok').all()
assert main.groupby('Condition').size().eq(870).all()
fields=['Error20FE','Error60FE','Error80FE','FinalError']
g=main.groupby(['FunctionID','Condition'])[fields].mean()
phase=[]
for fid in [1,6,9,13,21,30]:
    table=g.loc[fid]
    comparator=table.drop(index='SAQ-CSO').FinalError.idxmin()
    a=table.loc['SAQ-CSO'].to_numpy()
    b=table.loc[comparator].to_numpy()
    rec={'FunctionID':fid,'BestFinalControl':comparator}
    rec.update(dict(zip(['SAQ20FE','SAQ60FE','SAQ80FE','SAQ100FE'],a)))
    rec.update(dict(zip(['SAQoverBest20','SAQoverBest60','SAQoverBest80','SAQoverBest100'],a/b)))
    rec['SAQLast20RelativeDrop']=float((a[2]-a[3])/a[2])
    phase.append(rec)
phase=pd.DataFrame(phase)
phase.to_csv(OUT/'frozen_main_phase_diagnosis.csv',index=False)

plt.rcParams.update({'font.family':'Microsoft YaHei','font.size':10,'axes.spines.top':False,
 'axes.spines.right':False,'axes.unicode_minus':False,'pdf.fonttype':42,'savefig.dpi':300})
fig,axes=plt.subplots(2,3,figsize=(11.3,6.9))
x=np.array([20,60,80,100])
name_map={'HPSO-TVAC-CEC':'HPSO-TVAC','CLPSO-AuthorSource':'CLPSO','SPSO-2011-OfficialC':'SPSO-2011'}
for ax,r in zip(axes.flat,phase.to_dict('records')):
    fid=r['FunctionID'];ctrl=r['BestFinalControl']
    a=g.loc[(fid,'SAQ-CSO')].to_numpy();b=g.loc[(fid,ctrl)].to_numpy()
    ax.semilogy(x,a,'o-',color='#2166ac',label='SAQ-CSO',lw=1.8,ms=4)
    ax.semilogy(x,b,'s--',color='#d6604d',label=name_map[ctrl],lw=1.5,ms=4)
    ax.set_title(f"F{fid}   |   SAQ 后 20k 下降 {r['SAQLast20RelativeDrop']:.1%}",fontsize=10)
    ax.set_xticks(x);ax.set_xlabel('真实评价次数（千次）');ax.set_ylabel('平均最优误差（对数轴）')
    ax.grid(axis='y',alpha=.15);ax.legend(frameon=False,fontsize=9)
fig.suptitle('现有算法的阶段差异：中期效率与后期停滞需要分别处理',fontsize=13,y=.99)
fig.text(.5,.013,'D=50，100k FE，30 个种子。仅连接 20/60/80/100k 四个观测节点；对照按各函数最终均值事后选择。',ha='center',fontsize=9)
fig.tight_layout(rect=(0,.045,1,.96))
for ext in ['png','pdf']:
    fig.savefig(FIG/f'phase_diagnosis.{ext}',bbox_inches='tight')
plt.close(fig)
manifest={'Date':'2026-10-14','NewCECPerformanceRuns':0,
 'PilotValidationScope':'CSV-declared FE and previous final rechecks; not an independent objective-call count',
 'PhaseData':'Frozen five-method, 30-seed arithmetic mean errors at four observed nodes',
 'ComparatorSelection':'Posthoc best-final among selected four controls; descriptive only',
 'StatisticalScope':'Wins/losses and ranks are descriptive, not significance tests',
 'TotalRestartProbeEvaluations':int(pilot.RestartEvaluations.sum()),
 'RestartParentSuccesses':int(pilot.RestartParentSuccesses.sum()),
 'RestartGlobalSuccesses':int(pilot.RestartSuccesses.sum()),
 'Inputs':[], 'ImplementationDiagnostics':{}}
for path in [PILOT,MAIN,ROOT/'src/SAQ_CSO_RestartQ.m',ROOT/'tests/diagnose_SAQ_RestartQ_semantics.m',Path(__file__)]:
    manifest['Inputs'].append({'Path':str(path.relative_to(ROOT)),
      'SHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
for filename in ['rng_and_reference_witness.csv','flat_objective_witness.csv','terminal_budget_witness.csv']:
    path=OUT/filename
    if path.exists():
        data=pd.read_csv(path)
        manifest['ImplementationDiagnostics'][filename]=data.to_dict('records')
        manifest['Inputs'].append({'Path':str(path.relative_to(ROOT)),
          'SHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'reassessment_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(comparison.to_string(index=False))
print('Saved phase figure:', FIG/'phase_diagnosis.png')
