"""Plot both route candidates against all relevant same-opportunity controls."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('route_a',type=Path);p.add_argument('route_b',type=Path);a=p.parse_args();out=root/'results/cso_two_routes_20261012'
s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');targets=[('Adapt-Q',['Old-fixed6','Old-Q','Adapt-fixed2','Adapt-fixed4','Adapt-fixed6','Adapt-random','Adapt-phase','Adapt-epsfixed']),('Q-reset',['Old-fixed6','Old-Q','Rule-reset','Random-reset','EpsFixed-reset','Adapt-Q'])]
for candidate,controls in targets:
    ratio=np.array([((t[candidate].clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratio)
    fig,ax=plt.subplots(figsize=(11,5.5),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
    for i in range(len(controls)):
        for j in range(len(t)):ax.text(j,i,f'{ratio[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
    ax.set_title(f'Five-seed route development: {candidate} mean error / control');fig.colorbar(im,ax=ax,label='log10 error ratio (blue: candidate lower)');fig.savefig(out/(candidate+'_error_ratios.png'),dpi=180);plt.close(fig)
raw=pd.read_csv(out/'raw_runs.csv');selected=['Old-fixed6','Old-Q','Adapt-fixed6','Adapt-Q','Rule-reset','Q-reset'];rows=[]
for row in raw[raw.Condition.isin(selected)].itertuples():
    d=loadmat(Path(row.SourceDirectory)/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True);L=np.asarray(d['I']['TrendLog']).reshape(-1,7)
    for z in L:rows.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Condition=row.Condition,FE=int(z[0]),Error=z[5]-100*row.FunctionID,TrueDiversityRatio=z[1]/z[6],StagnationFE=z[4]))
r=pd.DataFrame(rows);agg=r.groupby(['FunctionID','Condition','FE']).mean(numeric_only=True).reset_index();agg.to_csv(out/'mean_trends.csv',index=False);r['Phase']=np.minimum(2,np.floor(3*(r.FE-50)/99950)).astype(int)
r.groupby(['FunctionID','Condition','Phase']).agg(MeanDiversityRatio=('TrueDiversityRatio','mean'),MedianStagnationFE=('StagnationFE','median'),Stall1000Rate=('StagnationFE',lambda x:float((x>=1000).mean()))).to_csv(out/'phase_trends.csv')
colors={'Old-fixed6':'#0f766e','Old-Q':'#64748b','Adapt-fixed6':'#2563eb','Adapt-Q':'#c2410c','Rule-reset':'#9333ea','Q-reset':'#d97706'};fig,axes=plt.subplots(8,3,figsize=(14,19),constrained_layout=True)
for i,fid in enumerate(sorted(t.index)):
    for c in selected:
        g=agg[(agg.FunctionID==fid)&(agg.Condition==c)];x=(g.FE-50)/99950
        axes[i,0].semilogy(x,np.maximum(g.Error,1e-12),color=colors[c],linewidth=.9,label=c)
        axes[i,1].plot(x,g.TrueDiversityRatio,color=colors[c],linewidth=.9,label=c)
        axes[i,2].plot(x,g.StagnationFE,color=colors[c],linewidth=.9,label=c)
    axes[i,0].set_ylabel(f'F{fid}: error');axes[i,1].set_ylabel('Trusted diversity / initial');axes[i,2].set_ylabel('Actual stagnation FE')
    for ax in axes[i]:ax.set_xlim(0,1);ax.grid(alpha=.15);ax.axvline(2/3,color='#cbd5e1',linestyle=':',linewidth=.6)
for ax,title in zip(axes[0],['Real error','True population diversity','FE since last global improvement']):ax.set_title(title,fontsize=11)
for ax in axes[-1]:ax.set_xlabel('Fraction of 100k FE')
axes[0,1].legend(frameon=False,fontsize=6,ncol=2);fig.suptitle('All eight functions, five fresh seeds: route A shared search vs route B linked recovery',fontsize=11);fig.savefig(out/'all_function_trends.png',dpi=150);plt.close(fig)
print('Saved two route-control plots and all-function actual trends')
