"""Neutral same-seed diagnostics: true diversity, error and FE stagnation."""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];out=root/'results/cso_mode_q_trend_20261012';d=pd.read_csv(out/'diversity_trace.csv');colors={'fixed2':'#60a5fa','fixed4':'#2563eb','fixed6':'#0f766e','q':'#c2410c'}
fig,axes=plt.subplots(4,3,figsize=(13,10),constrained_layout=True)
for i,fid in enumerate(sorted(d.FunctionID.unique())):
    for cond,c in colors.items():
        g=d[(d.FunctionID==fid)&(d.Condition==cond)].groupby('FE').mean(numeric_only=True);x=(g.index-50)/99950
        axes[i,0].semilogy(x,np.maximum(g.Error,1e-12),color=c,label=cond,linewidth=1.25)
        axes[i,1].plot(x,g.RealDiversityRatio,color=c,label=cond,linewidth=1.25)
        axes[i,2].plot(x,g.StagnationFE,color=c,label=cond,linewidth=1.25)
    for j in range(3):
        axes[i,j].axvline(1/3,color='#94a3b8',linestyle=':',linewidth=.8);axes[i,j].axvline(2/3,color='#94a3b8',linestyle=':',linewidth=.8);axes[i,j].set_xlim(0,1);axes[i,j].grid(alpha=.18)
    axes[i,0].set_ylabel(f'F{fid}: mean error');axes[i,1].set_ylabel('True diversity / initial');axes[i,2].set_ylabel('FE since last gbest gain')
for ax,title in zip(axes[0],['Objective error','Trusted population diversity','Actual stagnation length']):ax.set_title(title,fontsize=11)
for ax in axes[-1]:ax.set_xlabel('Fraction of 100k FE budget')
axes[0,1].legend(frameon=False,ncol=2,fontsize=8);fig.suptitle('Exact same-seed replays (2 seeds): diagnostic traces, not independent performance confirmation',fontsize=11)
fig.savefig(out/'true_diversity_stagnation_trends.png',dpi=180);plt.close(fig);print('Saved diagnostic trend figure')
