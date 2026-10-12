"""Show every developed feedback candidate against the same strong fixed control."""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];out=root/'results/cso_mode_q_state_20261012';s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');conds=['binaryQ','positive','gain','stag500','stag1000']
ratio=np.array([((t[c].clip(lower=0)+1e-12)/(t.fixed6.clip(lower=0)+1e-12)).to_numpy() for c in conds]);v=np.log10(ratio)
fig,ax=plt.subplots(figsize=(11,4.8),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(conds)),['Original Q','Positive reward','Magnitude reward','500-FE stall state','1000-FE stall state'])
for i in range(len(conds)):
    for j in range(len(t)):ax.text(j,i,f'{ratio[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('Development only: mean error / Fixed6 (5 reused paired seeds)');fig.colorbar(im,ax=ax,label='log10 error ratio');fig.savefig(out/'feedback_candidates.png',dpi=180);plt.close(fig);print('Saved all-feedback-candidate development comparison')
