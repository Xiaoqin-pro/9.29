"""All-function mode-efficiency Q comparison and actual policy state behavior."""
from pathlib import Path
import argparse
import numpy as np,pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;out=root/'results/cso_mode_efficiency_20261012'
s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['fixed6','random','phase','epsfixed','previousQ','stallQ','effrule','reverseeff'];v=np.array([np.log10((t.effQ.clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)) for c in controls]);ratios=10**v
fig,ax=plt.subplots(figsize=(11,6.4),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
 for j in range(len(t)):ax.text(j,i,f'{ratios[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Five fresh seeds: efficiency-state Q mean error / control');fig.colorbar(im,ax=ax,label='log10 error ratio (blue: candidate lower)');fig.savefig(out/'effQ_error_ratios.png',dpi=180);plt.close(fig)
f=pd.read_csv(out/'state_action_feedback.csv');q=f[f.Condition=='effQ'];g=q.groupby(['Phase','Bit','Action']).Share.mean();fig,axes=plt.subplots(1,3,figsize=(11,3.6),constrained_layout=True)
for ph,ax in enumerate(axes):
 bottom=np.zeros(2)
 for ac,color,label in [(1,'#60a5fa','2T8S'),(2,'#2563eb','4T6S'),(3,'#0f766e','6T4S')]:
  values=np.array([g.get((ph,bit,ac),0) for bit in [0,1]]);ax.bar([0,1],values,bottom=bottom,color=color,label=label);bottom+=values
 ax.set_xticks([0,1],['Seek/tie','Trace higher']);ax.set_ylim(0,1);ax.set_title(['Early','Middle','Late'][ph]);ax.set_ylabel('Mean actual action share')
axes[-1].legend(frameon=False,fontsize=8);fig.suptitle('Q action distribution conditional on lagged observed mode feedback');fig.savefig(out/'effQ_state_actions.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'raw_runs.csv');select=['fixed6','previousQ','stallQ','effQ','effrule'];rows=[]
for row in raw[raw.Condition.isin(select)].itertuples():
 data=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(data['I']['TrendLog']).reshape(-1,7)
 for z in L:rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(z[0]),Error=z[5]-100*row.FunctionID,RealDiversityRatio=z[1]/z[6],StagnationFE=z[4]))
r=pd.DataFrame(rows);agg=r.groupby(['FunctionID','Condition','FE']).mean(numeric_only=True).reset_index();agg.to_csv(out/'mean_trends.csv',index=False)
r['Phase']=np.minimum(2,np.floor(3*(r.FE-50)/99950)).astype(int);r.groupby(['FunctionID','Condition','Phase']).agg(MeanRealDiversity=('RealDiversityRatio','mean'),MedianStagnationFE=('StagnationFE','median'),LongStallRate=('StagnationFE',lambda x:float((x>=1000).mean()))).to_csv(out/'phase_trends.csv')
colors={'fixed6':'#0f766e','previousQ':'#64748b','stallQ':'#2563eb','effQ':'#c2410c','effrule':'#9333ea'};fig,axes=plt.subplots(8,3,figsize=(14,18),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
 for c in select:
  g=agg[(agg.FunctionID==fid)&(agg.Condition==c)];x=(g.FE-50)/99950
  axes[i,0].semilogy(x,np.maximum(g.Error,1e-12),color=colors[c],linewidth=1,label=c);axes[i,1].plot(x,g.RealDiversityRatio,color=colors[c],linewidth=1,label=c);axes[i,2].plot(x,g.StagnationFE,color=colors[c],linewidth=1,label=c)
 axes[i,0].set_ylabel(f'F{fid}: error');axes[i,1].set_ylabel('True diversity / initial');axes[i,2].set_ylabel('Stagnation FE')
 for ax in axes[i]:ax.set_xlim(0,1);ax.grid(alpha=.15)
for ax,title in zip(axes[0],['Real error','Trusted population diversity','Actual stagnation FE']):ax.set_title(title,fontsize=11)
for ax in axes[-1]:ax.set_xlabel('Fraction of 100k FE')
axes[0,1].legend(frameon=False,fontsize=7,ncol=2);fig.suptitle('Pure FE-quota Q: all eight functions, five fresh seeds, unchanged CSO search');fig.savefig(out/'all_function_trends.png',dpi=150);plt.close(fig);print('Saved efficiency Q controls, actual state actions and true trends')
