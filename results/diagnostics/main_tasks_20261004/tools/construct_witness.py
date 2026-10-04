from pathlib import Path
import json, numpy as np
from scipy.io import loadmat,savemat
from scipy.optimize import milp,Bounds,LinearConstraint
from scipy.sparse import lil_matrix
out=Path(__file__).resolve().parent
g=loadmat(out/'witness_graph.mat',simplify_cells=True);graph=g['dist'];controls=g['controls'];base=g['model'];pool=[int(o['stationID']) for o in base['orders']]
reports=[]
for n in [10,15,20]:
 for label in ['wide','tight']:
  name=f'N{n}_{label}';model=loadmat(out/'input'/f'{name}_model.mat',simplify_cells=True)['model'];orders=model['orders']
  select=[0]+[1+pool.index(int(o['stationID'])) for o in orders];length=graph[np.ix_(select,select)]
  # Start0, orders1..n, return n+1. Positive service/travel time excludes subtours.
  edges=[]
  for i in range(n+1):
   for j in range(1,n+2):
    if i==j or (i==0 and j==n+1):continue
    L=length[i,0 if j==n+1 else j]
    if np.isfinite(L):edges.append((i,j,float(L)))
  E=len(edges);total=E+n+2
  cost=np.zeros(total);cost[:E]=[e[2] for e in edges]
  lower=np.zeros(total);upper=np.ones(total);upper[E:]=240
  lower[E]=upper[E]=0
  for j,o in enumerate(orders,1):lower[E+j]=o['ready'];upper[E+j]=o['due']
  integrality=np.zeros(total);integrality[:E]=1
  A=lil_matrix((2*n+2+E,total));lo=np.full(A.shape[0],-np.inf);hi=np.full(A.shape[0],np.inf);r=0
  for node in range(n+1):
   for k,(i,j,L) in enumerate(edges):
    if i==node:A[r,k]=1
   lo[r]=hi[r]=1;r+=1
  for node in range(1,n+2):
   for k,(i,j,L) in enumerate(edges):
    if j==node:A[r,k]=1
   lo[r]=hi[r]=1;r+=1
  M=500
  for k,(i,j,L) in enumerate(edges):
   service=0 if i==0 else orders[i-1]['service']
   A[r,E+j]=1;A[r,E+i]=-1;A[r,k]=-M;lo[r]=service+L/6-M;r+=1
  result=milp(cost,integrality=integrality,bounds=Bounds(lower,upper),constraints=LinearConstraint(A.tocsr(),lo,hi),options={'time_limit':30,'mip_rel_gap':.01})
  found=result.x is not None
  if found:
   successor={i:j for k,(i,j,L) in enumerate(edges) if result.x[k]>.5};route=[];current=0
   for _ in range(n):current=successor[current];route.append(current)
   assert successor[current]==n+1 and sorted(route)==list(range(1,n+1))
   c=np.zeros((n+1,2,3));legs=[0]+route+[0]
   for leg,(i,j) in enumerate(zip(legs[:-1],legs[1:])):
    one=np.asarray(controls[select[i],select[j]],float)
    lam,d,h=one
    if lam<=.6:c[leg,0]=one;c[leg,1]=[(1+lam)/2,d/2,h/2]
    else:c[leg,0]=[lam/2,d/2,h/2];c[leg,1]=one
   keys=np.zeros(n)
   for rank,j in enumerate(route):keys[j-1]=.05+.9*rank/(n-1)
   normalized=c.copy();normalized[:,:,0]=(normalized[:,:,0]-.2)/.6;normalized[:,:,1]=(normalized[:,:,1]+15)/30;normalized[:,:,2]/=12
   assert np.all(normalized>=-1e-10) and np.all(normalized<=1+1e-10)
   vector=np.r_[keys,normalized.ravel(order='F')]
   savemat(out/f'witness_{name}.mat',{'position':vector,'route':np.array(route),'control':c,'solverStatus':result.status,'solverObjective':result.fun})
  record={'scenario':name,'found':found,'solverStatus':int(result.status),'solverMessage':result.message,'searchDomain':'finite diagnostic safe-link graph, witness only, no injection'}
  reports.append(record);print(record,flush=True)
(out/'witness_solver.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
