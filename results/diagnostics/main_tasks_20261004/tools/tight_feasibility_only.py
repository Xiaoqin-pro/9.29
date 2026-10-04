from pathlib import Path
import json,csv,numpy as np
from scipy.io import loadmat,savemat
from scipy.optimize import milp,Bounds,LinearConstraint
from scipy.sparse import lil_matrix
out=Path(r'C:\Users\111\Documents\Codex\2026-09-29\d-111-desktop-new\mainstudy929_20261004_135427')
g=loadmat(out/'witness_graph.mat',simplify_cells=True);L=g['dist'];m=loadmat(out/'input/N20_tight_model.mat',simplify_cells=True)['model'];orders=m['orders'];n=20
# Tight feasibility only, no travel minimization: one controlled follow-up to finite graph diagnostic.
edges=[(i,j,float(L[i,0 if j==n+1 else j])) for i in range(n+1) for j in range(1,n+2) if i!=j and not(i==0 and j==n+1) and np.isfinite(L[i,0 if j==n+1 else j])]
E=len(edges);D=E+n+2;cost=np.zeros(D);lower=np.zeros(D);upper=np.ones(D);upper[E:]=240;lower[E]=upper[E]=0
for j,o in enumerate(orders,1):lower[E+j]=o['ready'];upper[E+j]=o['due']
integ=np.zeros(D);integ[:E]=1
A=lil_matrix((2*n+2+E,D));lb=np.full(A.shape[0],-np.inf);ub=np.full(A.shape[0],np.inf);r=0
for node in range(n+1):
 for k,(i,j,d) in enumerate(edges):
  if i==node:A[r,k]=1
 lb[r]=ub[r]=1;r+=1
for node in range(1,n+2):
 for k,(i,j,d) in enumerate(edges):
  if j==node:A[r,k]=1
 lb[r]=ub[r]=1;r+=1
for k,(i,j,d) in enumerate(edges):
 service=0 if i==0 else orders[i-1]['service'];M=max(0,upper[E+i]+service+d/6-lower[E+j]);A[r,E+j]=1;A[r,E+i]=-1;A[r,k]=-M;lb[r]=service+d/6-M;r+=1
res=milp(cost,integrality=integ,bounds=Bounds(lower,upper),constraints=LinearConstraint(A.tocsr(),lb,ub),options={'time_limit':60,'mip_rel_gap':0})
report={'scenario':'N20_tight','found':res.x is not None,'solverStatus':int(res.status),'message':res.message,'limitation':'finite witness graph only; infeasible in graph does not prove full K2 infeasibility'}
if res.x is not None:
 successors={i:j for k,(i,j,d) in enumerate(edges) if res.x[k]>.5};route=[];last=0
 for _ in range(n):last=successors[last];route.append(last)
 assert sorted(route)==list(range(1,n+1)) and successors[last]==n+1
 c=np.zeros((n+1,2,3));legs=[0]+route+[0]
 for k,(i,j) in enumerate(zip(legs[:-1],legs[1:])):
  lam,d,h=np.asarray(g['controls'][i,j],float)
  if lam<=.6:c[k,0]=[lam,d,h];c[k,1]=[(1+lam)/2,d/2,h/2]
  else:c[k,0]=[lam/2,d/2,h/2];c[k,1]=[lam,d,h]
 x=c.copy();x[:,:,0]=(x[:,:,0]-.2)/.6;x[:,:,1]=(x[:,:,1]+15)/30;x[:,:,2]/=12;keys=np.zeros(n);keys[np.array(route)-1]=np.linspace(.05,.95,n)
 savemat(out/'witness_N20_tight.mat',{'position':np.r_[keys,x.ravel(order='F')],'route':np.array(route),'control':c})
(out/'tight_feasibility_only.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(report)
