import pandas as pd
from pathlib import Path
import numpy as np
p=Path(r"D:\111\Desktop\噜噜\9.29\results\cec\threeway_D100_3seed_20261011_161327")
x=pd.read_csv(p/'raw_runs.csv')
x['Error']=x['FinalError']
methods=['ASE-CSO','CLPSO','NRLPSO-PaperAligned']
rows=[]
for (fid,fn,m),g in x.groupby(['FunctionID','Function','Method'],sort=True):
    e=g['Error']
    rows.append({'FunctionID':fid,'Function':fn,'Method':m,'Runs':len(g),
        'MeanError':e.mean(),'MedianError':e.median(),'StdError':e.std(ddof=1),
        'MinError':e.min(),'MaxError':e.max(),'MeanSeconds':g['Seconds'].mean(),
        'StdSeconds':g['Seconds'].std(ddof=1),'MeanEvaluations':g['Evaluations'].mean(),
        'MeanObjectiveCalls':g['ObjectiveCalls'].mean(),
        'MeanMutationEvaluations':g['MutationEvaluations'].mean(),
        'MeanMutationCalls':g['MutationCalls'].mean(),
        'MeanMutationOutOfBounds':g['MutationOutOfBounds'].mean(),
        'MaxBestRecheckAbsDiff':g['BestRecheckAbsDiff'].max()})
summary=pd.DataFrame(rows)
summary.to_csv(p/'summary.csv',index=False)
# Per-function paired comparisons
pairs=[]
for i,a in enumerate(methods):
  for b in methods[i+1:]:
    for fid,fn in x[['FunctionID','Function']].drop_duplicates().sort_values('FunctionID').itertuples(index=False):
      xa=x[(x.FunctionID==fid)&(x.Method==a)].sort_values('Seed')['Error'].to_numpy()
      xb=x[(x.FunctionID==fid)&(x.Method==b)].sort_values('Seed')['Error'].to_numpy()
      pairs.append({'FunctionID':fid,'Function':fn,'MethodA':a,'MethodB':b,
        'MeanA':xa.mean(),'MeanB':xb.mean(),'MedianA':np.median(xa),'MedianB':np.median(xb),
        'WinsA':int((xa<xb).sum()),'WinsB':int((xb<xa).sum()),'Ties':int((xa==xb).sum()),
        'MeanLog10RatioAoverB':np.mean(np.log10(np.maximum(xa,np.finfo(float).tiny)/np.maximum(xb,np.finfo(float).tiny))),
        'PairedMeanDiffAminusB':np.mean(xa-xb)})
pd.DataFrame(pairs).to_csv(p/'pairwise_comparison.csv',index=False)
# Seed-level wide table and winner
wide=x.pivot_table(index=['FunctionID','Function','Seed'],columns='Method',values='Error').reset_index()
for m in methods: wide[m]=wide[m].astype(float)
vals=wide[methods].to_numpy(); idx=np.argmin(vals,axis=1)
wide['BestMethod']=[methods[i] for i in idx]
wide['BestError']=vals[np.arange(len(wide)),idx]
wide.to_csv(p/'seed_comparison.csv',index=False)
# Overall function wins and average ranks by function mean
means=summary.pivot_table(index=['FunctionID','Function'],columns='Method',values='MeanError')
ranks=means.rank(axis=1,method='average',ascending=True)
over=[]
for m in methods:
  over.append({'Method':m,'FunctionsBest':int((means[m]==means.min(axis=1)).sum()),
    'AverageFunctionRank':ranks[m].mean(),'MedianFunctionRank':ranks[m].median(),
    'MeanSecondsPerRun':x[x.Method==m].Seconds.mean(),'TotalRuns':int((x.Method==m).sum()),
    'ValidRuns':int(((x.Method==m)&(x.Status=='ok')).sum()),
    'MeanFinalErrorAcrossRuns':x[x.Method==m].Error.mean()})
pd.DataFrame(over).to_csv(p/'overall_summary.csv',index=False)
# Update README
readme=p/'README.md'
readme.write_text(readme.read_text(encoding='utf-8')+'\nGenerated tables:\n- summary.csv: function/method mean, median, standard deviation, extrema, runtime and audit metrics.\n- pairwise_comparison.csv: all three method pairs with 3-seed wins/losses and paired differences.\n- seed_comparison.csv: one row per function and seed with all final errors and the best method.\n- overall_summary.csv: function wins, average rank, runtime and valid-run counts.\n',encoding='utf-8')
print('generated',len(x),'raw rows',len(summary),'summary rows',len(pairs),'pair rows')
print(pd.DataFrame(over).to_string(index=False))
