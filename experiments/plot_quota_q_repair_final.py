"""Show improvements and unresolved strong controls without hiding prior variants."""
from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];out=root/'results/quota_q_smooth_rate_20261012';s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');candidate='Bonus10-100';controls=['alwaysQ','fixed6','100-gateq','VisitRate-Bonus10-100','SmoothRate-Bonus10-100','100-gaterandom','100-gateeps6','500-gaterandom'];ratio=np.array([((t[candidate].clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratio)
fig,ax=plt.subplots(figsize=(11,6),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
 for j in range(len(t)):ax.text(j,i,f'{ratio[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Same-seed repair development: fixed-alpha gated +10 Q mean error / all strong controls');fig.colorbar(im,ax=ax,label='log10 error ratio (blue Q lower)');fig.savefig(out/'repair_error_ratios.png',dpi=180);plt.close(fig)
selected=['alwaysQ','100-gateq','500-gateq','Bonus10-100','VisitRate-Bonus10-100','SmoothRate-Bonus10-100','fixed6','100-gateeps6','500-gaterandom'];ranks=s.groupby('Condition').Rank.mean().reindex(selected);fig,ax=plt.subplots(figsize=(12,4.4),constrained_layout=True);x=np.arange(len(ranks));colors=['#94a3b8','#64748b','#60a5fa','#2563eb','#1d4ed8','#0f766e','#7c3aed','#9333ea','#a855f7'];ax.bar(x,ranks,color=colors)
for i,z in enumerate(ranks):ax.text(i,z+.12,f'{z:.3g}',ha='center',fontsize=9)
ax.set_xticks(x,selected,rotation=25,ha='right',fontsize=8);ax.set_ylabel('Average function rank within all 16 candidates');ax.set_title('Repair progression improves original Q, but strongest simple controls remain');fig.savefig(out/'repair_progress_ranks.png',dpi=180);plt.close(fig)
print('Saved complete repair/error and rank progression plots')
