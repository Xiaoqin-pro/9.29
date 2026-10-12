"""All 29 functions: mean error ratios and FE curves for the requested CLPSO comparison."""
from pathlib import Path
import argparse
import numpy as np,pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;out=root/'results/clpso_full_100k_20261012'
s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');ratio=(t['CSO-Fixed6'].clip(lower=0)+1e-12)/(t['CLPSO-AuthorSource40'].clip(lower=0)+1e-12)
fig,ax=plt.subplots(figsize=(13,4.8),constrained_layout=True);x=np.arange(len(t));v=np.log10(ratio)
ax.bar(x,v,color=np.where(ratio<=1,'#2563eb','#c2410c'),width=.72);ax.axhline(0,color='#64748b',linewidth=1);ax.set_xticks(x,['F'+str(i) for i in t.index],rotation=45,fontsize=8);ax.set_ylabel('log10(mean error CSO / CLPSO)');ax.set_title('D50, 100k true evaluations, five fresh seeds: blue CSO lower / orange CLPSO lower')
fig.savefig(out/'all29_mean_error_ratios.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'raw_runs.csv');nodes=np.unique(np.r_[50,np.arange(1000,100001,1000)]);curves=[]
for row in raw.itertuples():
 d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);T=np.asarray(d['T']).reshape(-1)
 for fe in nodes:curves.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(fe),Error=float(T[fe-1]-100*row.FunctionID)))
c=pd.DataFrame(curves);c.to_csv(out/'convergence_nodes.csv',index=False);agg=c.groupby(['FunctionID','Condition','FE']).Error.mean().reset_index()
fig,axes=plt.subplots(6,5,figsize=(17,16),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
 ax=axes.flat[i]
 for cond,color,label in [('CSO-Fixed6','#2563eb','CSO Fixed6'),('CLPSO-AuthorSource40','#c2410c','CLPSO source N40')]:
  g=agg[(agg.FunctionID==fid)&(agg.Condition==cond)];ax.semilogy(g.FE/100000,np.maximum(g.Error,1e-12),color=color,linewidth=1.2,label=label)
 ax.set_title('F'+str(fid),fontsize=10);ax.grid(alpha=.18);ax.set_xlim(0,1)
 if i%5==0:ax.set_ylabel('Mean objective error')
 if i>=24:ax.set_xlabel('Fraction of 100k FE')
axes.flat[-1].axis('off');axes.flat[0].legend(frameon=False,fontsize=6);fig.suptitle('Full CEC2017 F1, F3-F30: same FE budget, N50 CSO vs N40 author-profile CLPSO',fontsize=12);fig.savefig(out/'all29_convergence.png',dpi=150);plt.close(fig)
fig,ax=plt.subplots(figsize=(7,4),constrained_layout=True);m=pd.read_csv(out/'paired_runs.csv');ax.boxplot(m.groupby('FunctionID').TimeRatio.median(),vert=True,tick_labels=['CSO / CLPSO'],patch_artist=True,boxprops=dict(facecolor='#93c5fd'));ax.axhline(1,color='#64748b',linestyle='--');ax.set_ylabel('Per-function median matched runtime ratio');ax.set_title('Actual wall-clock cost at equal 100k evaluations');fig.savefig(out/'runtime_ratio.png',dpi=180);plt.close(fig);print('Saved all29 ratios, all29 curves and actual runtime ratio')
