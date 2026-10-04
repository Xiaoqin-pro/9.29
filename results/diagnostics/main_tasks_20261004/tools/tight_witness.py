from pathlib import Path
import json, numpy as np, time
from scipy.io import loadmat,savemat
out=Path(__file__).resolve().parent
g=loadmat(out/'witness_graph.mat',simplify_cells=True);dist=g['dist']/6;controls=g['controls'];m=loadmat(out/'input/N20_tight_model.mat',simplify_cells=True)['model'];orders=m['orders'];n=20
ready=np.array([o['ready'] for o in orders]);due=np.array([o['due'] for o in orders]);service=np.array([o['service'] for o in orders])
def score(route):
 t=0.;late=0.;prior=0;length=0.
 for j in route:
  step=dist[prior,j+1]
  if not np.isfinite(step):return 1e9
  t=max(ready[j],t+step);late+=max(0,t-due[j]);t+=service[j];length+=step;prior=j+1
 step=dist[prior,0]
 if not np.isfinite(step):return 1e9
 t+=step;late+=max(0,t-240);length+=step
 return 10000*late+length
rng=np.random.default_rng(12345);bestvalue=1e9;best=None;started=time.time()
for start in range(30):
 route=np.argsort(due,kind='stable') if start==0 else rng.permutation(n);value=score(route)
 for it in range(4000):
  if it%200==0:temperature=1000*(.01**(it/4000))
  a,b=rng.choice(n,2,replace=False);candidate=route.copy()
  if it%2:candidate[a],candidate[b]=candidate[b],candidate[a]
  else:
   customer=candidate[a];candidate=np.insert(np.delete(candidate,a),b,customer)
  cost=score(candidate)
  if cost<value or (cost-value)/temperature<700 and rng.random()<np.exp(-(cost-value)/temperature):route=candidate;value=cost
  if value<bestvalue:bestvalue=value;best=route.copy()
  if bestvalue<300:break
 if bestvalue<300:break
print('diagnostic finite-graph witness score',bestvalue,'starts',start+1,'seconds',time.time()-started,flush=True)
found=bool(bestvalue<300)
if found:
 c=np.zeros((n+1,2,3));sequence=[0]+(best+1).tolist()+[0]
 for leg,(a,b) in enumerate(zip(sequence[:-1],sequence[1:])):
  one=np.asarray(controls[a,b],float);lam,d,h=one
  if lam<=.6:c[leg,0]=one;c[leg,1]=[(1+lam)/2,d/2,h/2]
  else:c[leg,0]=[lam/2,d/2,h/2];c[leg,1]=one
 keys=np.zeros(n);keys[best]=np.linspace(.05,.95,n);x=c.copy();x[:,:,0]=(x[:,:,0]-.2)/.6;x[:,:,1]=(x[:,:,1]+15)/30;x[:,:,2]/=12
 assert np.all(x>=-1e-10)&np.all(x<=1+1e-10)
 savemat(out/'witness_N20_tight.mat',{'position':np.r_[keys,x.ravel(order='F')],'route':best+1,'control':c,'diagnosticFiniteGraphScore':bestvalue})
(out/'tight_witness_result.json').write_text(json.dumps({'found':found,'finiteGraphScore':bestvalue,'seconds':time.time()-started,'use':'diagnostic only, not population injection'},indent=2),encoding='utf-8')
