"""Compare two deleted-mechanism candidates and all fair simple controls."""
from pathlib import Path
import argparse
import numpy as np,pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;out=root/'results/quota_q_simplicity_20261012';s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['Fixed6','Random','Phase','EpsFixed6','Original-Q6-Bonus1','Gated-Q6-Bonus10']
fig,axes=plt.subplots(2,1,figsize=(12,9),constrained_layout=True)
for ax,cand in zip(axes,['Simple-Q6','Simple-Q3']):
 ratios=np.array([((t[cand].clip(lower=0)+1e-12)/(t[ctl].clip(lower=0)+1e-12)).to_numpy() for ctl in controls]);v=np.log10(ratios);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
 for i in range(len(controls)):
  for j in range(len(t)):ax.text(j,i,f'{ratios[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
 ax.set_title(cand+' mean error / matched control (five development seeds)')
fig.colorbar(im,ax=axes,label='log10 error ratio (blue candidate lower)',shrink=.8);fig.savefig(out/'simple_q_error_ratios.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'all_quality_runs.csv');selected=['Fixed6','Original-Q6-Bonus1','Gated-Q6-Bonus10','Simple-Q6','Simple-Q3','EpsFixed6'];sources={'Fixed6':root/'results/cec/clpso_full_100k_study_20261012_193032','Original-Q6-Bonus1':root/'results/cec/quota_q_full_100k_study_20261012_194957','Gated-Q6-Bonus10':root/'results/cec/quota_q_episode_bonus_study_20261012_213013'};nodes=np.unique(np.r_[50,np.arange(1000,100001,1000)]);rows=[]
for r in raw[raw.Condition.isin(selected)].itertuples():
 data=loadmat(sources.get(r.Condition,run)/'runs'/f'job_{r.JobID:04d}.mat',simplify_cells=True);T=np.asarray(data['T']).reshape(-1)
 for fe in nodes:rows.append(dict(FunctionID=r.FunctionID,Seed=r.Seed,Condition=r.Condition,FE=int(fe),Error=float(T[fe-1]-100*r.FunctionID)))
c=pd.DataFrame(rows);c.to_csv(out/'convergence_nodes.csv',index=False);agg=c.groupby(['FunctionID','Condition','FE']).Error.mean().reset_index();colors={'Fixed6':'#0f766e','Original-Q6-Bonus1':'#94a3b8','Gated-Q6-Bonus10':'#64748b','Simple-Q6':'#2563eb','Simple-Q3':'#c2410c','EpsFixed6':'#9333ea'};fig,axes=plt.subplots(2,4,figsize=(15,7),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
 ax=axes.flat[i]
 for method in selected:
  g=agg[(agg.FunctionID==fid)&(agg.Condition==method)];ax.semilogy(g.FE/100000,np.maximum(g.Error,1e-12),color=colors[method],linewidth=1,label=method)
 ax.set_title('F'+str(fid));ax.grid(alpha=.15);ax.set_xlabel('Fraction of 100k FE')
axes.flat[0].legend(frameon=False,fontsize=6);fig.suptitle('Delete mechanisms before adding them: original bone and real FE budget unchanged');fig.savefig(out/'simple_q_all8_convergence.png',dpi=180);plt.close(fig);print('Saved simplicity control/error and all8 convergence figures')
