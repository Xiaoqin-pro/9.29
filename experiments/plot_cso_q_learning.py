"""Behavior changed does not equal optimization improved: paired initialization comparison."""
from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];out=root/'results/cso_q_learning_20261012';zero=pd.read_csv(out/'original_learning_summary.csv');lower=pd.read_csv(out/'lower_init_learning_summary.csv')
metrics=['ExploitSwitchRate','GapBelow01Rate','PositiveRewardRate'];labels=['Switch on greedy state revisit','Greedy value gap < 0.1','Positive global-reward blocks'];x=np.arange(3);fig,ax=plt.subplots(figsize=(10,4.2),constrained_layout=True)
ax.bar(x-.17,zero[metrics].mean(),.34,label='Q initial value 0',color='#2563eb');ax.bar(x+.17,lower[metrics].mean(),.34,label='Q initial value -10',color='#0f766e');ax.set_xticks(x,labels,fontsize=9);ax.set_ylim(0,1);ax.set_ylabel('Mean fraction over 40 matched runs');ax.set_title('Policy stability improves, but reward frequency does not');ax.legend(frameon=False);fig.savefig(out/'learning_behavior.png',dpi=180);plt.close(fig)
s=pd.read_csv(out/'summary.csv');t=s.pivot(index='FunctionID',columns='Condition',values='MeanError');controls=['effQ','fixed6','epsfixed','effrule','phase','random'];ratios=np.array([((t['LowerInit-effQ'].clip(lower=0)+1e-12)/(t[c].clip(lower=0)+1e-12)).to_numpy() for c in controls]);v=np.log10(ratios)
fig,ax=plt.subplots(figsize=(11,5.2),constrained_layout=True);im=ax.imshow(v,cmap='RdBu_r',vmin=-1,vmax=1,aspect='auto');ax.set_xticks(range(len(t)),['F'+str(i) for i in t.index]);ax.set_yticks(range(len(controls)),controls)
for i in range(len(controls)):
 for j in range(len(t)):ax.text(j,i,f'{ratios[i,j]:.3g}x',ha='center',va='center',color='white' if abs(v[i,j])>.6 else '#1f2937',fontsize=9)
ax.set_title('40 same-seed development runs: lower-init Q mean error / control');fig.colorbar(im,ax=ax,label='log10 error ratio (blue: candidate lower)');fig.savefig(out/'initial_value_error_ratios.png',dpi=180);plt.close(fig)
comparison=pd.DataFrame({'OriginalZero':zero[metrics+['MeanGreedyGap','MedianGreedyGap']].mean(),'LowerInit':lower[metrics+['MeanGreedyGap','MedianGreedyGap']].mean()});comparison.to_csv(out/'learning_behavior_comparison.csv');print(comparison.to_string());print('Saved learning behavior and true error figures')
