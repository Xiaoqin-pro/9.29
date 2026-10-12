"""Plot all controls and the actual small-Q policy distribution."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('result_dir',type=Path);a=p.parse_args();r=a.result_dir
s=pd.read_csv(r/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['fixed2','fixed4','fixed6','random','phase','epsfixed']
ratios=np.array([((t.q.clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);values=np.log10(ratios)
fig,ax=plt.subplots(figsize=(11,5.5),constrained_layout=True);im=ax.imshow(values,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto')
ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls);ax.set_title('D50, 100k FE - Q mean error / each control (5 fresh seeds)')
for i in range(len(controls)):
    for j in range(len(t)):ax.text(j,i,f'{ratios[i,j]:.3g}x',ha='center',va='center',color='white' if abs(values[i,j])>.6 else '#1f2937',fontsize=10)
fig.colorbar(im,ax=ax,label='log10 mean-error ratio (blue: Q lower)');fig.savefig(r/'q_error_ratios.png',dpi=180);plt.close(fig)
d=pd.read_csv(r/'policy_diagnostics.csv').set_index('Condition').reindex(['fixed2','fixed4','fixed6','random','phase','epsfixed','q']);fig,axes=plt.subplots(1,2,figsize=(11,4.2),constrained_layout=True)
x=np.arange(len(d));base=np.zeros(len(d))
for col,color,label in [('Action1Share','#60a5fa','2T8S'),('Action2Share','#2563eb','4T6S'),('Action3Share','#0f766e','6T4S')]:axes[0].bar(x,d[col],bottom=base,color=color,label=label);base+=d[col].to_numpy()
axes[0].set_xticks(x,d.index,rotation=25);axes[0].set_ylabel('Mean decision share');axes[0].set_title('Actual executed action distribution');axes[0].legend(frameon=False)
axes[1].bar(x,d.PositiveRewardBlocks/d.Decisions,color='#0f766e');axes[1].set_xticks(x,d.index,rotation=25);axes[1].set_ylabel('Fraction of positive global-reward blocks');axes[1].set_title('Actual 100-FE feedback rate')
fig.savefig(r/'q_policy_feedback.png',dpi=180);plt.close(fig)
print('Saved Q/control and actual-policy figures')
