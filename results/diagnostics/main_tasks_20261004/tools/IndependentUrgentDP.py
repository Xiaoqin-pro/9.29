from pathlib import Path
import numpy as np,json,time
from scipy.io import loadmat
from scipy.spatial.distance import cdist
out=Path(__file__).resolve().parent.parent
m=loadmat(out/'input/N20_tight_model.mat',simplify_cells=True)['model']
orders=[o for o in m['orders'] if o['due']<=135];n=len(orders)
nodes=np.vstack([m['depot']]+[o['xyz'] for o in orders]);travel=cdist(nodes,nodes)/6
ready=np.array([o['ready'] for o in orders]);due=np.array([o['due'] for o in orders]);service=np.array([o['service'] for o in orders])
dp=np.full((1<<n,n),np.inf);started=time.time();reached=0
for j in range(n):
 t=max(ready[j],travel[0,j+1])
 if t<=due[j]+1e-7:dp[1<<j,j]=t+service[j]
for mask in range(1,1<<n):
 for i in np.flatnonzero(np.isfinite(dp[mask])):
  reached+=1
  for j in range(n):
   if mask&(1<<j):continue
   start=max(ready[j],dp[mask,i]+travel[i+1,j+1]);newmask=mask|(1<<j)
   if start<=due[j]+1e-7 and start+service[j]<dp[newmask,j]:dp[newmask,j]=start+service[j]
finish=dp[-1]+travel[1:,0];found=bool(np.any(finish<=240+1e-7));assert not found
report={'scenario':'N20_tight','test':'independent Python exact earliest-departure subset DP','stations':[int(o['stationID']) for o in orders],'found':found,'reachedStates':reached,'timeTolerance':1e-7,'seconds':time.time()-started,'meaning':'Necessary14-station subset infeasible with optimistic directXYZ travel; full K2 problem infeasible under same deadlines. Removing optional orders cannot make lower-bound travel more expensive, and inserting other orders cannot shorten Euclidean direct legs.'}
(out/'independent_urgent_certificate.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(report)
