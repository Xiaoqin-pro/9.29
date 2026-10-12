"""Plot all ten-seed confirmation functions; no selection of winning cases."""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('result_dir',type=Path);a=p.parse_args();r=a.result_dir
s=pd.read_csv(r/'summary.csv');m=pd.read_csv(r/'paired_runs.csv');c=pd.read_csv(r/'comparison.csv').iloc[0]
t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');ratios=(t.SMP3.clip(lower=0)+1e-12)/(t.B10.clip(lower=0)+1e-12)
fig,ax=plt.subplots(figsize=(10,4.5),constrained_layout=True)
x=np.arange(len(t));ax.bar(x,np.log10(ratios),color=np.where(ratios<=1,'#2563eb','#c2410c'),width=.65)
for i,v in enumerate(ratios):
    g=m[m.FunctionID==t.index[i]];wins=int((g.ErrorDifference<0).sum());loss=int((g.ErrorDifference>0).sum())
    ax.text(i,np.log10(v)+(0.025 if v>=1 else -0.025),f'{v:.3g}x\n{wins}:{loss}',ha='center',va='bottom' if v>=1 else 'top',fontsize=10)
ax.axhline(0,color='#64748b',linewidth=1);ax.set_xticks(x,['F'+str(i) for i in t.index]);ax.set_ylabel('log10(mean error SMP3 / B10)')
ax.set_title('D50, 100k FE - ten fresh paired seeds\nLabels: mean-error ratio and SMP3:B10 seed wins',fontsize=12)
ymin,ymax=ax.get_ylim();ax.set_ylim(min(ymin,-.18)-.1,max(ymax,.18)+.1);fig.savefig(r/'error_ratios.png',dpi=180);plt.close(fig)
fig,ax=plt.subplots(figsize=(10,4.1),constrained_layout=True)
vals=[m[m.FunctionID==fid].TimeRatio for fid in t.index]
ax.boxplot(vals,positions=x,widths=.52,patch_artist=True,boxprops=dict(facecolor='#93c5fd',edgecolor='#2563eb'),medianprops=dict(color='#1e3a8a'),tick_labels=['F'+str(i) for i in t.index])
ax.axhline(1,color='#64748b',linestyle='--',label='B10 runtime');ax.axhline(float(c.MedianPairedTimeRatio),color='#0f766e',linestyle=':',label=f'Overall paired median {c.MedianPairedTimeRatio:.3f}')
ax.set_ylabel('Paired runtime SMP3 / B10');ax.set_title('D50, 100k FE - runtime by function (10 pairs each)');ax.legend(frameon=False);fig.savefig(r/'runtime_ratios.png',dpi=180);plt.close(fig)
print('Saved confirmation error and runtime figures')
