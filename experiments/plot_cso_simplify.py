"""Static development-study plots from the completed public result tables."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

p=argparse.ArgumentParser();p.add_argument('result_dir',type=Path);a=p.parse_args();r=a.result_dir
s=pd.read_csv(r/'summary.csv');c=pd.read_csv(r/'comparisons.csv');funcs=sorted(s.FunctionID.unique());conds=['SMP3','NoSeekingElite'];budgets=sorted(s.Budget.unique())
fig,axes=plt.subplots(2,1,figsize=(11,5.4),constrained_layout=True)
for ax,budget in zip(axes,budgets):
    t=s[s.Budget==budget].pivot(index='FunctionID',columns='Condition',values='MeanError')
    ratios=np.array([((t[x].clip(lower=0)+1e-12)/(t.B10.clip(lower=0)+1e-12)).to_numpy() for x in conds])
    near=np.array([((t[x]<=1e-8)&(t.B10<=1e-8)).to_numpy() for x in conds])
    values=np.log10(ratios);values[near]=0
    im=ax.imshow(values,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto')
    ax.set_xticks(range(len(funcs)),['F'+str(f) for f in funcs]);ax.set_yticks(range(2),['Two seeking candidates','No seeking elite offset'])
    ax.set_title(f'D50, {budget:,} FE - mean error / B10 (3 fresh seeds)',fontsize=11)
    for i in range(2):
        for j in range(len(funcs)):
            text='both near 0' if near[i,j] else f'{ratios[i,j]:.2g}x'
            ax.text(j,i,text,ha='center',va='center',color='white' if abs(values[i,j])>.6 else '#1f2937',fontsize=9)
fig.colorbar(im,ax=axes,label='log10 mean-error ratio (blue: lower, red: higher)',shrink=.82)
fig.savefig(r/'error_ratios.png',dpi=180);plt.close(fig)
fig,ax=plt.subplots(figsize=(8,4.2),constrained_layout=True)
labels=[];vals=[]
for budget in budgets:
    for cond in conds:
        row=c[(c.Budget==budget)&(c.Condition==cond)].iloc[0]
        labels.append(f'{cond}\n{budget//1000}k FE');vals.append(row.MedianPairedTimeRatio)
ax.bar(labels,vals,color=['#2563eb','#0f766e']*2,width=.62)
ax.axhline(1,color='#6b7280',linestyle='--',label='B10')
for x,v in enumerate(vals):ax.text(x,v+.015,f'{v:.3f}',ha='center',fontsize=10)
ax.set_ylim(0,max(1.13,max(vals)+.12));ax.set_ylabel('Median paired runtime / B10');ax.set_title('Matched D50 runs: eight functions, three seeds');ax.legend(frameon=False)
fig.savefig(r/'runtime_ratios.png',dpi=180);plt.close(fig)
print('Saved error_ratios.png and runtime_ratios.png')
