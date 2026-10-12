"""All29 curves and pure quota-Q gains relative to external and internal controls."""
from pathlib import Path
import argparse
import numpy as np,pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();out=root/'results/quota_q_full_100k_20261012';q='CSO-QuotaQ-Stall1000';s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError')
fig,axes=plt.subplots(2,1,figsize=(13,7.5),constrained_layout=True)
for ax,control in zip(axes,['CLPSO-AuthorSource40','CSO-Fixed6']):
 ratio=(t[q].clip(lower=0)+1e-12)/(t[control].clip(lower=0)+1e-12);v=np.log10(ratio);x=np.arange(len(t));ax.bar(x,v,color=np.where(ratio<=1,'#2563eb','#c2410c'),width=.73);ax.axhline(0,color='#64748b',linewidth=1);ax.set_xticks(x,['F'+str(i) for i in t.index],rotation=45,fontsize=8);ax.set_ylabel('log10(mean error Q / control)');ax.set_title('Q vs '+control+' (blue Q lower / orange control lower)',fontsize=11)
fig.suptitle('D50, 100k true evaluations: all 29 functions, five matched seeds');fig.savefig(out/'all29_q_error_ratios.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'all_quality_runs.csv');nodes=np.unique(np.r_[50,np.arange(1000,100001,1000)]);rows=[]
for row in raw.itertuples():
 d=loadmat(Path(row.SourceDirectory)/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);T=np.asarray(d['T']).reshape(-1)
 for fe in nodes:rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(fe),Error=float(T[fe-1]-100*row.FunctionID)))
c=pd.DataFrame(rows);c.to_csv(out/'convergence_nodes.csv',index=False);agg=c.groupby(['FunctionID','Condition','FE']).Error.mean().reset_index();fig,axes=plt.subplots(6,5,figsize=(17,16),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
 ax=axes.flat[i]
 for method,color,label in [(q,'#2563eb','Quota Q'),('CSO-Fixed6','#0f766e','CSO Fixed6'),('CLPSO-AuthorSource40','#c2410c','CLPSO source N40')]:
  g=agg[(agg.FunctionID==fid)&(agg.Condition==method)];ax.semilogy(g.FE/100000,np.maximum(g.Error,1e-12),color=color,linewidth=1,label=label)
 ax.set_title('F'+str(fid),fontsize=10);ax.grid(alpha=.16);ax.set_xlim(0,1)
 if i%5==0:ax.set_ylabel('Mean objective error')
 if i>=24:ax.set_xlabel('Fraction of 100k FE')
axes.flat[-1].axis('off');axes.flat[0].legend(frameon=False,fontsize=6);fig.suptitle('Full CEC2017: unchanged 6x3 quota Q, strongest fixed quota and author-code CLPSO',fontsize=12);fig.savefig(out/'all29_threeway_convergence.png',dpi=150);plt.close(fig)
policy=pd.read_csv(out/'q_policy_by_function.csv');x=np.arange(len(policy));fig,ax=plt.subplots(figsize=(13,4.3),constrained_layout=True);base=np.zeros(len(policy))
for col,color,label in [('Action1Share','#60a5fa','2T8S'),('Action2Share','#2563eb','4T6S'),('Action3Share','#0f766e','6T4S')]:ax.bar(x,policy[col],bottom=base,color=color,label=label,width=.8);base+=policy[col].to_numpy()
ax.set_xticks(x,['F'+str(i) for i in policy.FunctionID],rotation=45,fontsize=8);ax.set_ylim(0,1);ax.set_ylabel('Mean actual decision share');ax.set_title('Actual Q evaluation-quota allocation (five runs per function)');ax.legend(frameon=False,ncol=3);fig.savefig(out/'all29_q_action_shares.png',dpi=180);plt.close(fig);print('Saved all29 Q/control ratios, threeway curves and actual Q allocation')
