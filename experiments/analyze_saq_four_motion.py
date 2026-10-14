"""Motion-retention mechanism audit; never overwrites four-operator results."""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import wilcoxon
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run');arg=p.parse_args();run=Path(arg.run)
cfg=json.loads((run/'config.json').read_text(encoding='utf8'));assert cfg['Stage']=='mechanism'
assert json.loads((run/'status.json').read_text(encoding='utf8'))['Status']=='complete'
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():assert hashlib.sha256(Path(h.Path).read_bytes()).hexdigest()==h.SHA256
new=pd.read_csv(run/'raw_runs.csv');assert len(new)==80 and new.Status.eq('ok').all() and new.ObjectiveCalls.eq(100000).all()
oldcfg=json.loads((run/'cache/config.json').read_text(encoding='utf8'))
for k in ['FunctionIDs','Seeds','Dimension','Population','Budget','ProgressThreshold','EpisodeFE','SeedBase']:assert cfg[k]==oldcfg[k]
oldparent=ROOT/'results/cec'/'saq_four_operator_20261014_134243'
for h in pd.read_csv(run/'prelaunch_hashes.csv').itertuples():
 hp=Path(h.Path)
 if 'cec_data' in hp.parts:
  assert hashlib.sha256((oldparent/'cec_data'/hp.relative_to(run/'cec_data')).read_bytes()).hexdigest()==h.SHA256
old=pd.read_csv(run/'cache/all_runs.csv');old=old[old.Method.isin(['FO-Base','FO-Rule'])]
raw=pd.concat([old,new],ignore_index=True)
assert raw.groupby(['FunctionID','Seed'])[['InitSeed','SearchSeed','PolicySeed','ProbeSeed']].nunique().eq(1).all().all()
out=ROOT/'results/saq_four_motion_mechanism_10seed_20261014';out.mkdir(exist_ok=True,parents=True)
checks=[]
for row in new.itertuples():
 saved=loadmat(run/'runs'/row.Artifact,simplify_cells=True);I=saved['info'];w=np.atleast_2d(I['WindowLog']);T=np.asarray(saved['T']).reshape(-1);stall=0
 assert len(T)==100000 and np.isfinite(T).all() and np.all(np.diff(T)<=0)
 assert np.isclose(T[-1],row.FinalCost,rtol=1e-12)
 assert sum(I['OperatorFE'])==I['SeekingEvaluations'] and I['QUpdates']==0
 assert I['EscapeEvaluations']==w[:,18].sum()
 for k in range(len(w)):
  if k:stall=0 if max(0,w[k-1,12]-w[k-1,14])>=1e-4*w[k-1,5] else stall+1
  stag=1+int(stall>0)+int(stall>=10);phase=1+int((w[k,0]-50)/99950>=.3)+int((w[k,0]-50)/99950>=.7)
  assert w[k,4]==stall and w[k,2]==3*(phase-1)+stag
  expected=-1
  if max(0,w[k,12]-w[k,14])>=1e-4*w[k,5]:expected=10
  elif stag==3 and w[k,9]>=3 and w[k,18]>0:expected=.5
  assert w[k,15]==expected
 if I['EscapeEvaluations']:
  e=np.atleast_2d(I['EscapeLog']);pts=np.atleast_2d(I['EscapePoints']);assert len(e)==I['EscapeEvaluations']
  assert np.isin(e[:,3],[2,3,4]).all() and np.all((pts>=-100)&(pts<=100))
  assert np.array_equal(T[e[:,0].astype(int)-1]<e[:,7],e[:,9]>0)
 checks.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Passed=True,AlternativeFE=int(I['EscapeEvaluations'])))
pd.DataFrame(checks).to_csv(out/'integrity_checks.csv',index=False);raw.to_csv(out/'all_runs.csv',index=False)
methods=['FO-Base','FO-Rule','FM-Rule'];means=raw.groupby(['FunctionID','Method']).FinalError.mean().unstack().reindex(columns=methods)
means.to_csv(out/'function_means.csv');raw.groupby(['FunctionID','Method']).FinalError.std().unstack().reindex(columns=methods).to_csv(out/'function_std.csv')
rows=[];detail=[]
for ref in methods[:-1]:
 b=raw[raw.Method.eq(ref)].set_index(['FunctionID','Seed']).FinalError;v=raw[raw.Method.eq('FM-Rule')].set_index(['FunctionID','Seed']).FinalError.reindex(b.index);d=v-b;ratio=means['FM-Rule']/means[ref]
 rows.append(dict(Reference=ref,MeanWins=int((ratio<1).sum()),MeanLosses=int((ratio>1).sum()),MedianMeanRatio=float(ratio.median()),SeedWins=int((d<0).sum()),SeedLosses=int((d>0).sum()),SeedTies=int((d==0).sum())))
 for fid in means.index:
  delta=d.loc[fid].to_numpy();pv=1. if np.all(delta==0) else wilcoxon(delta,zero_method='wilcox',method='auto').pvalue
  detail.append(dict(FunctionID=int(fid),Reference=ref,MeanRatio=float(ratio.loc[fid]),WilcoxonP=float(pv)))
comp=pd.DataFrame(rows);comp.to_csv(out/'comparisons.csv',index=False);detail=pd.DataFrame(detail);pv=detail.WilcoxonP.to_numpy();order=np.argsort(pv);adj=np.empty(len(pv));running=0
for k,i in enumerate(order):running=max(running,(len(pv)-k)*pv[i]);adj[i]=min(1.,running)
detail['HolmP']=adj;detail.to_csv(out/'function_comparisons.csv',index=False)
x=comp.set_index('Reference');health=means.loc[[1,13,30],'FM-Rule']/means.loc[[1,13,30],'FO-Base']
base=bool(x.loc['FO-Base','MeanWins']>=5 and x.loc['FO-Base','MedianMeanRatio']<=.95)
old_rule=bool(x.loc['FO-Rule','MeanWins']>=5 and x.loc['FO-Rule','MedianMeanRatio']<=1)
healthy=bool((health<=1).sum()>=2 and not (health>1.2).any());pre=pd.read_csv(run/'preflight.csv').iloc[0]
gate=dict(Passed=base and old_rule and healthy,BaseGate=base,OldRuleGate=old_rule,HealthyGate=healthy,
          FreshRuns=80,CachedRuns=160,FreshOptimizationCalls=int(new.ObjectiveCalls.sum()),AuditCalls=int(new.PostRunRecheckCalls.sum()),
          PreflightOptimizationCalls=int(pre.ObjectiveCalls),PreflightAuditCalls=int(pre.PostRunRecheckCalls),Comparisons=rows,IndependentConfirmation=False)
for d in [out,run]:(d/'gate_decision.json').write_text(json.dumps(gate,ensure_ascii=False,indent=2),encoding='utf8')
curves=pd.concat([pd.read_csv(run/'cache/convergence_nodes.csv'),pd.read_csv(run/'convergence_nodes.csv')],ignore_index=True);curves=curves[curves.Method.isin(methods)];curves.to_csv(out/'convergence_nodes.csv',index=False)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9});fig,axes=plt.subplots(2,4,figsize=(13,6.2));g=curves.groupby(['FunctionID','Method','FE']).BestError.mean();colors=['#333333','#2166ac','#d6604d']
for ax,fid in zip(axes.flat,means.index):
 for m,color in zip(methods,colors):
  z=g.loc[(fid,m)];ax.semilogy(z.index/1000,z.clip(lower=1e-12),label=m,color=color)
 ax.set_title(f'F{fid}',loc='left');ax.set_xlabel('Evaluations (thousands)');ax.set_ylabel('Best error');ax.grid(alpha=.17)
h,l=axes.flat[0].get_legend_handles_labels();fig.legend(h,l,loc='lower center',ncol=3,frameon=False);fig.tight_layout(rect=(0,.045,1,1))
for ext in ['png','pdf']:fig.savefig(out/f'convergence.{ext}',dpi=180,bbox_inches='tight')
plt.close(fig)
for name in ['config.json','validation.json','checks.csv','prelaunch_hashes.csv','run_diagnostics.csv','policy_state_diagnostics.csv']:shutil.copyfile(run/name,out/name)
report=['# 探索位置保留机制实验（2026-10-14）','','四算子不变；只允许探索动作的实评新位置保留，个人/全局最优档案仍贪心更新。高斯速度清零、反向速度翻转。与旧规则比是位置保留及运动记忆包的对照，不是新增算子。',
        '', 'D50/100k/8函数/10个已知开发种子8101–8110/4worker；新增80次优化，复用160次同种子旧对照。',
        '', '| 相对 | 函数均值胜/负 | 配对种子胜/负/平 | 函数均值比中位数 |','|---|---:|---:|---:|']
for c in rows:report.append(f"| {c['Reference']} | {c['MeanWins']}/{c['MeanLosses']} | {c['SeedWins']}/{c['SeedLosses']}/{c['SeedTies']} | {c['MedianMeanRatio']:.4f} |")
report+=['',f"预定门：{'通过' if gate['Passed'] else '未通过'}。Base={base}；旧规则={old_rule}；健康函数={healthy}。",'',
         f"新优化{gate['FreshOptimizationCalls']:,}调用，额外复核{gate['AuditCalls']:,}调用；预检优化{gate['PreflightOptimizationCalls']:,}、复核{gate['PreflightAuditCalls']:,}。12项合成检查和80次运行后核验通过。",'',
         '均值胜负为描述，16项Holm见function_comparisons.csv；不是独立确认，不保证已经解决局部最优。','', '| FunctionID | '+' | '.join(methods)+' |','|---|'+'---:|'*3]
for fid,row in means.iterrows():report.append('| '+str(fid)+' | '+' | '.join(f'{v:.5g}' for v in row)+' |')
report+=['','未通过则不展开本候选Q/随机调度；原冻结论文与算法保留。',f'原始MAT及快照：{run}','']
(out/'REPORT.md').write_text('\n'.join(report),encoding='utf8');print(comp.to_string(index=False));print(json.dumps(gate,ensure_ascii=False,indent=2))
