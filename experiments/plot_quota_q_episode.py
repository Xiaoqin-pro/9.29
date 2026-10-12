"""Duration-controlled episode Q comparisons and real FE allocation."""
from pathlib import Path
import argparse
import numpy as np,pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;out=root/'results/quota_q_episode_20261012';s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['fixed6','alwaysQ','100-gateq','500-gaterandom','500-gate2','500-gate4','500-gateeps6'];ratio=np.array([((t['500-gateq'].clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratio)
fig,ax=plt.subplots(figsize=(11,6),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
 for j in range(len(t)):ax.text(j,i,f'{ratio[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Same-seed development: held-500FE Q mean error / control');fig.colorbar(im,ax=ax,label='log10 error ratio (blue Q lower)');fig.savefig(out/'episode_error_ratios.png',dpi=180);plt.close(fig)
f=pd.read_csv(out/'episode_fe_weighted_policy.csv');g=f.groupby('Condition')[['Action1FEShare','Action2FEShare','Action3FEShare']].mean();x=np.arange(len(g));fig,ax=plt.subplots(figsize=(10,4),constrained_layout=True);bottom=np.zeros(len(g))
for col,color,label in [('Action1FEShare','#60a5fa','2T8S'),('Action2FEShare','#2563eb','4T6S'),('Action3FEShare','#0f766e','6T4S')]:ax.bar(x,g[col],bottom=bottom,color=color,label=label);bottom+=g[col].to_numpy()
ax.set_xticks(x,g.index,rotation=20);ax.set_ylim(0,1);ax.set_ylabel('Actual FE-weighted decision allocation share');ax.set_title('Held actions consume different FE: use duration-weighted shares');ax.legend(frameon=False,ncol=3);fig.savefig(out/'episode_fe_shares.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'all_quality_runs.csv');sources={'fixed6':root/'results/cec/clpso_full_100k_study_20261012_193032','alwaysQ':root/'results/cec/quota_q_full_100k_study_20261012_194957'};old=root/'results/cec/quota_q_stall_gate_study_20261012_202002';sel=['fixed6','alwaysQ','100-gateq','500-gateq','500-gaterandom','500-gateeps6'];nodes=np.unique(np.r_[50,np.arange(1000,100001,1000)]);curves=[]
for row in raw[raw.Condition.isin(sel)].itertuples():
 folder=run if row.Condition.startswith('500-') else old if row.Condition.startswith('100-') else sources[row.Condition];data=loadmat(folder/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);T=np.asarray(data['T']).reshape(-1)
 for fe in nodes:curves.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(fe),Error=float(T[fe-1]-100*row.FunctionID)))
c=pd.DataFrame(curves);c.to_csv(out/'convergence_nodes.csv',index=False);agg=c.groupby(['FunctionID','Condition','FE']).Error.mean().reset_index();colors={'fixed6':'#0f766e','alwaysQ':'#64748b','100-gateq':'#9333ea','500-gateq':'#2563eb','500-gaterandom':'#d97706','500-gateeps6':'#c2410c'};fig,axes=plt.subplots(2,4,figsize=(15,7),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
 ax=axes.flat[i]
 for method in sel:
  g=agg[(agg.FunctionID==fid)&(agg.Condition==method)];ax.semilogy(g.FE/100000,np.maximum(g.Error,1e-12),color=colors[method],linewidth=1,label=method)
 ax.set_title('F'+str(fid));ax.grid(alpha=.15);ax.set_xlabel('Fraction of 100k FE')
axes.flat[0].legend(frameon=False,fontsize=6);fig.suptitle('Same-seed temporal-credit diagnostic: all eight functions and strong controls');fig.savefig(out/'episode_all8_convergence.png',dpi=180);plt.close(fig);print('Saved duration-controlled Q results and FE-weighted allocation')
