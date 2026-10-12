"""Learning necessity with the same two actions; show deletion steps without cherry-picking."""
from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];out=root/'results/quota_q_compact_20261012';s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['Fixed6','Compact-Random','Compact-Eps6','Compact-Rule4','Gated-Q6-Bonus10','Simple-Q6','Simple-Q3'];ratio=np.array([((t['Compact-Q'].clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratio)
fig,ax=plt.subplots(figsize=(11,6),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
 for j in range(len(t)):ax.text(j,i,f'{ratio[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Effective 3x2 quota Q: mean error / controls (five development seeds)');fig.colorbar(im,ax=ax,label='log10 error ratio');fig.savefig(out/'compact_error_ratios.png',dpi=180);plt.close(fig)
p=pd.read_csv(out/'actual_quota_policy.csv');g=p.groupby('Condition')[['FourTraceShare','SixTraceShare','FreeRate','FreeFourTraceShare','FreePositiveRate']].mean();g.to_csv(out/'policy_summary.csv')
fig,axes=plt.subplots(1,2,figsize=(10,3.8),constrained_layout=True);x=np.arange(len(g));axes[0].bar(x,g.FourTraceShare,label='4T6S',color='#2563eb');axes[0].bar(x,g.SixTraceShare,bottom=g.FourTraceShare,label='6T4S',color='#0f766e');axes[0].set_xticks(x,g.index,rotation=20);axes[0].set_ylabel('Mean actual decision share');axes[0].legend(frameon=False)
axes[1].bar(x,g.FreePositiveRate,color='#0f766e');axes[1].set_xticks(x,g.index,rotation=20);axes[1].set_ylabel('Positive rewards during actual stalled choices');fig.suptitle('Same healthy fallback and same two actions: Q must add value over rules');fig.savefig(out/'compact_policy.png',dpi=180);plt.close(fig);print('Saved compact Q quality and actual two-action policy')
