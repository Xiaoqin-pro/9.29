"""Independent confirmation and true population trends, all eight functions."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir;out=root/'results/cso_mode_q_state_confirm_20261012'
s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['fixed4','fixed6','random','phase','epsfixed','binaryQ'];ratio=np.array([((t.stag1000.clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratio)
fig,ax=plt.subplots(figsize=(11,5.5),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
    for j in range(len(t)):ax.text(j,i,f'{ratio[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Independent confirmation: stall-Q mean error / control (10 fresh seeds)');fig.colorbar(im,ax=ax,label='log10 error ratio (blue: candidate lower)');fig.savefig(out/'confirmation_error_ratios.png',dpi=180);plt.close(fig)
raw=pd.read_csv(out/'raw_runs.csv');selected=['fixed6','phase','binaryQ','stag1000'];records=[];actions=[]
for row in raw[raw.Condition.isin(selected)].itertuples():
    d=loadmat(run/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['TrendLog']).reshape(-1,7)
    D=np.asarray(d['I']['DecisionLog']).reshape(-1,14);S=np.asarray(d['I']['StateLog']).reshape(-1,3)
    for ph in range(3):
        mask=D[:,5]==ph
        for flag in [0,1]:
            ix=mask & (S[:,1]==flag)
            if not ix.any():continue
            for ac in [1,2,3]:actions.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,Phase=ph,Signal=flag,Action=ac,DecisionShare=float((D[ix,3]==ac).mean()),Blocks=int(ix.sum()),PositiveRate=float((D[ix,9]>0).mean())))
    for z in L:records.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(z[0]),Error=z[5]-100*row.FunctionID,RealDiversityRatio=z[1]/z[6],StagnationFE=z[4]))
pd.DataFrame(actions).to_csv(out/'confirmation_state_action_shares.csv',index=False)
r=pd.DataFrame(records);agg=r.groupby(['FunctionID','Condition','FE']).mean(numeric_only=True).reset_index();agg.to_csv(out/'confirmation_mean_trends.csv',index=False)
r['Phase']=np.minimum(2,np.floor(3*(r.FE-50)/99950)).astype(int);r.groupby(['FunctionID','Condition','Phase']).agg(MeanDiversityRatio=('RealDiversityRatio','mean'),MedianStagnationFE=('StagnationFE','median'),LongStallRate=('StagnationFE',lambda x:float((x>=1000).mean()))).to_csv(out/'confirmation_phase_trends.csv')
colors={'fixed6':'#0f766e','phase':'#64748b','binaryQ':'#2563eb','stag1000':'#c2410c'};fig,axes=plt.subplots(8,3,figsize=(14,18),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
    for c in selected:
        g=agg[(agg.FunctionID==fid)&(agg.Condition==c)];x=(g.FE-50)/99950
        axes[i,0].semilogy(x,np.maximum(g.Error,1e-12),color=colors[c],label=c,linewidth=1)
        axes[i,1].plot(x,g.RealDiversityRatio,color=colors[c],label=c,linewidth=1)
        axes[i,2].plot(x,g.StagnationFE,color=colors[c],label=c,linewidth=1)
    axes[i,0].set_ylabel(f'F{fid}: error');axes[i,1].set_ylabel('True diversity / initial');axes[i,2].set_ylabel('Stagnation FE')
    for ax in axes[i]:ax.set_xlim(0,1);ax.grid(alpha=.16);ax.axvline(1/3,color='#cbd5e1',linestyle=':',linewidth=.6);ax.axvline(2/3,color='#cbd5e1',linestyle=':',linewidth=.6)
for ax,title in zip(axes[0],['Real objective error','Trusted population diversity','Actual FE since last gbest gain']):ax.set_title(title,fontsize=10)
for ax in axes[-1]:ax.set_xlabel('Fraction of 100k FE')
axes[0,1].legend(frameon=False,fontsize=7,ncol=2);fig.suptitle('Ten independent seeds: all eight functions and preselected strong controls',fontsize=11);fig.savefig(out/'confirmation_true_diversity_stagnation.png',dpi=160);plt.close(fig);print('Saved independent confirmation and all-function trend plots')
