"""Matched Q gap diagnosis and stall-gated learning: all eight test functions."""
from pathlib import Path
import argparse
import numpy as np,pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;out=root/'results/quota_q_gap_20261012'
s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['fixed6','alwaysQ','gaterandom','gate2','gate4','gateeps6'];ratios=np.array([((t.gateq.clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratios)
fig,ax=plt.subplots(figsize=(11,5.5),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
 for j in range(len(t)):ax.text(j,i,f'{ratios[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Same-seed intervention test: stall-only Q mean error / control');fig.colorbar(im,ax=ax,label='log10 error ratio');fig.savefig(out/'gateq_error_ratios.png',dpi=180);plt.close(fig)
diag=pd.read_csv(out/'function_gap_summary.csv');fig,axes=plt.subplots(1,2,figsize=(12,4.1),constrained_layout=True);g=diag.sort_values('MeanErrorRatio',ascending=False);x=np.arange(len(g))
axes[0].bar(x,np.log10(g.MeanErrorRatio),color=np.where(g.MeanErrorRatio>1,'#c2410c','#2563eb'));axes[0].axhline(0,color='#64748b');axes[0].set_xticks(x,['F'+str(i) for i in g.FunctionID],rotation=60,fontsize=7);axes[0].set_ylabel('log10(original Q error / Fixed6)');axes[0].set_title('All29 original Q loss/gain pattern')
axes[1].bar(x,g.HealthyBlockRate,color='#0f766e');axes[1].set_xticks(x,['F'+str(i) for i in g.FunctionID],rotation=60,fontsize=7);axes[1].set_ylabel('Fraction of original decisions below stall threshold');axes[1].set_ylim(0,1);axes[1].set_title('Many loss functions spent most decisions healthy')
fig.savefig(out/'original_healthy_gap_diagnosis.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'all_quality_runs.csv');sources={'fixed6':root/'results/cec/clpso_full_100k_study_20261012_193032','alwaysQ':root/'results/cec/quota_q_full_100k_study_20261012_194957'};selected=['fixed6','alwaysQ','gateq','gaterandom','gateeps6'];nodes=np.unique(np.r_[50,np.arange(1000,100001,1000)]);curves=[]
for row in raw[raw.Condition.isin(selected)].itertuples():
 folder=sources.get(row.Condition,run);data=loadmat(folder/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);T=np.asarray(data['T']).reshape(-1)
 for fe in nodes:curves.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(fe),Error=float(T[fe-1]-100*row.FunctionID)))
c=pd.DataFrame(curves);c.to_csv(out/'convergence_nodes.csv',index=False);agg=c.groupby(['FunctionID','Condition','FE']).Error.mean().reset_index();colors={'fixed6':'#0f766e','alwaysQ':'#64748b','gateq':'#2563eb','gaterandom':'#9333ea','gateeps6':'#c2410c'};fig,axes=plt.subplots(2,4,figsize=(14,7),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
 ax=axes.flat[i]
 for method in selected:
  q=agg[(agg.FunctionID==fid)&(agg.Condition==method)];ax.semilogy(q.FE/100000,np.maximum(q.Error,1e-12),color=colors[method],linewidth=1.15,label=method)
 ax.set_title('F'+str(fid));ax.set_xlabel('Fraction of 100k FE');ax.grid(alpha=.15)
axes.flat[0].legend(frameon=False,fontsize=6);fig.suptitle('Gate effects and Q-specific effects must be assessed separately');fig.savefig(out/'gate_all8_convergence.png',dpi=180);plt.close(fig);print('Saved gap diagnosis and stall-only Q control figures')
