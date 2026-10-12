"""Plot fixed-quota mean-error ratios and observed feedback rates."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('result_dir',type=Path);a=p.parse_args();r=a.result_dir
s=pd.read_csv(r/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');conds=['2T8S','4T6S','6T4S']
ratios=np.array([((t[c].clip(lower=0)+1e-12)/(t['4T6S'].clip(lower=0)+1e-12)).to_numpy() for c in conds]);values=np.log10(ratios)
fig,ax=plt.subplots(figsize=(10.5,3.8),constrained_layout=True);im=ax.imshow(values,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto')
ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(3),conds);ax.set_title('D50, 100k FE - fixed mode-quota mean error / 4T6S (5 seeds)')
for i in range(3):
    for j in range(len(t)):ax.text(j,i,f'{ratios[i,j]:.3g}x',ha='center',va='center',color='white' if abs(values[i,j])>.6 else '#1f2937',fontsize=10)
fig.colorbar(im,ax=ax,label='log10 mean-error ratio');fig.savefig(r/'quota_error_ratios.png',dpi=180);plt.close(fig)
f=pd.read_csv(r/'feedback_runs.csv');fig,axes=plt.subplots(1,2,figsize=(11,4.2),constrained_layout=True)
for ax,cols,title in [(axes[0],['TraceGlobalPerFE','SeekGlobalPerFE'],'Observed global-best improvements per true FE'),(axes[1],['TraceLocalPerFE','SeekMarginalLocalPerFE'],'Observed local acceptance / marginal improvements per FE')]:
    x=np.arange(3);means=f.groupby('Condition')[cols].mean().reindex(conds)
    for k,col in enumerate(cols):ax.bar(x+(k-.5)*.3,means[col],width=.3,label='Tracing' if k==0 else 'Seeking',color=['#2563eb','#0f766e'][k])
    ax.set_xticks(x,conds);ax.set_title(title,fontsize=10);ax.legend(frameon=False)
fig.suptitle('Mode feedback is observational, not a counterfactual action score',fontsize=11);fig.savefig(r/'quota_feedback.png',dpi=180);plt.close(fig)
print('Saved quota figures')
