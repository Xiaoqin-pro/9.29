import pandas as pd
from pathlib import Path
import numpy as np
p=Path(r'D:\111\Desktop\噜噜\9.29\results\cec\ase_lshade_D30_D100_3seed_20261011_164009')
x=pd.read_csv(p/'raw_runs.csv')
methods=['ASE-CSO','L-SHADE-standard']
rows=[]
for (d,fid,fn,m),g in x.groupby(['Dimension','FunctionID','Function','Method'],sort=True):
    e=g.FinalError
    rows.append({'Dimension':d,'FunctionID':fid,'Function':fn,'Method':m,'Runs':len(g),
        'MeanError':e.mean(),'MedianError':e.median(),'StdError':e.std(ddof=1),'MinError':e.min(),'MaxError':e.max(),
        'MeanError20FE':g.Error20FE.mean(),'MeanError60FE':g.Error60FE.mean(),'MeanError80FE':g.Error80FE.mean(),
        'MeanSeconds':g.Seconds.mean(),'StdSeconds':g.Seconds.std(ddof=1),'MeanEvaluations':g.Evaluations.mean(),
        'MaxBestRecheckAbsDiff':g.BestRecheckAbsDiff.max(),'MeanFinalPopulationSize':g.FinalPopulationSize.mean()})
summary=pd.DataFrame(rows); summary.to_csv(p/'summary.csv',index=False)
pairs=[]
for d in sorted(x.Dimension.unique()):
  for fid,fn in x[x.Dimension==d][['FunctionID','Function']].drop_duplicates().sort_values('FunctionID').itertuples(index=False):
    xa=x[(x.Dimension==d)&(x.FunctionID==fid)&(x.Method==methods[0])].sort_values('Seed').FinalError.to_numpy()
    xb=x[(x.Dimension==d)&(x.FunctionID==fid)&(x.Method==methods[1])].sort_values('Seed').FinalError.to_numpy()
    pairs.append({'Dimension':d,'FunctionID':fid,'Function':fn,'MethodA':methods[0],'MethodB':methods[1],
      'MeanA':xa.mean(),'MeanB':xb.mean(),'MedianA':np.median(xa),'MedianB':np.median(xb),
      'WinsA':int((xa<xb).sum()),'WinsB':int((xb<xa).sum()),'Ties':int((xa==xb).sum()),
      'MeanLog10RatioAoverB':np.mean(np.log10(np.maximum(xa,np.finfo(float).tiny)/np.maximum(xb,np.finfo(float).tiny))),
      'PairedMeanDiffAminusB':np.mean(xa-xb)})
pd.DataFrame(pairs).to_csv(p/'pairwise_comparison.csv',index=False)
wide=x.pivot_table(index=['Dimension','FunctionID','Function','Seed'],columns='Method',values='FinalError').reset_index()
vals=wide[methods].to_numpy(); best=np.argmin(vals,axis=1); wide['BestMethod']=[methods[i] for i in best]; wide['BestError']=vals[np.arange(len(wide)),best]
wide.to_csv(p/'seed_comparison.csv',index=False)
means=summary.pivot_table(index=['Dimension','FunctionID','Function'],columns='Method',values='MeanError'); ranks=means.rank(axis=1,ascending=True)
over=[]
for d in sorted(x.Dimension.unique()):
  mm=means.loc[d] if d in means.index.get_level_values(0) else means.iloc[0:0]
  for m in methods:
    xx=x[(x.Dimension==d)&(x.Method==m)]
    over.append({'Dimension':d,'Method':m,'FunctionsBest':int((mm[m]==mm.min(axis=1)).sum()),'AverageFunctionRank':ranks.loc[d,m].mean(),'MedianFunctionRank':ranks.loc[d,m].median(),'MeanSecondsPerRun':xx.Seconds.mean(),'TotalRuns':len(xx),'ValidRuns':int((xx.Status=='ok').sum())})
pd.DataFrame(over).to_csv(p/'overall_summary.csv',index=False)
with open(p/'README.md','a',encoding='utf-8') as f:
 f.write('\nGenerated tables:\n- summary.csv: per-dimension/function/method mean, median, standard deviation, checkpoints and runtime.\n- pairwise_comparison.csv: 3-seed paired wins and differences.\n- seed_comparison.csv: final error for each dimension/function/seed.\n- overall_summary.csv: function wins, ranks and runtime.\n')
print(pd.DataFrame(over).to_string(index=False))
