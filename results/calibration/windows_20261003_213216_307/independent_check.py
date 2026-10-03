from pathlib import Path
from scipy.io import loadmat
from scipy.interpolate import RegularGridInterpolator
import numpy as np,json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
w=out
records=[]
for f in sorted(out.glob('W*/seed_*.mat')):
 d=loadmat(f,simplify_cells=True);m=d['model'];s=d['state'];best=d['Best'];detail=best['Detail']
 route=np.asarray(best['Route'],int);control=np.asarray(best['Control'],float)
 current=np.asarray(s['position'],float);now=float(s['time']);distance=late=waiting=0.;samples_records=[];points_all=[current]
 ground=RegularGridInterpolator((np.asarray(m['Y'])[:,0],np.asarray(m['X'])[0,:]),np.asarray(m['terrainZ']))
 collisions=0;maxclimb=0.;maxturn=0.;minclear=np.inf
 for leg in range(len(route)+1):
  target=np.asarray(m['orders'][route[leg]-1]['xyz'] if leg<len(route) else m['depot'],float)
  move=target-current;h=np.linalg.norm(move[:2]);side=np.array([-move[1],move[0]])/h if h else np.array([1.,0.])
  c=control[leg];mid=current+c[:,0,None]*move;mid[:,:2]+=c[:,1,None]*side;mid[:,2]+=c[:,2]
  points=np.vstack([current,mid,target]);stored=np.asarray(detail['paths'][leg]['points'])
  assert np.allclose(points,stored,atol=1e-12,rtol=0)
  seg=np.diff(points,axis=0);dist=np.linalg.norm(seg,axis=1).sum();distance+=dist
  pitch=np.degrees(np.arctan2(seg[:,2],np.linalg.norm(seg[:,:2],axis=1)));maxclimb=max(maxclimb,float(np.max(np.abs(pitch))))
  xyseg=seg[:,:2];turn=np.degrees(np.arctan2(np.abs(xyseg[:-1,0]*xyseg[1:,1]-xyseg[:-1,1]*xyseg[1:,0]),np.sum(xyseg[:-1]*xyseg[1:],axis=1)))
  maxturn=max(maxturn,float(np.max(turn,initial=0)))
  for a,v in zip(points[:-1],seg):
   t=np.linspace(0,1,max(2,int(np.ceil(np.linalg.norm(v)/.05))+1));q=a+t[:,None]*v;xy=np.clip(q[:,:2],0,m['mapSize'])
   clear=q[:,2]-ground(xy[:,::-1]);minclear=min(minclear,float(clear.min()))
   # 与MATLAB不同实现：先按高度截线段，再求XY圆域最近点。
   for obs in m['obstacles']:
    lo=float(obs['zMin'])-m['obstacleSafety'];hi=float(obs['zMax'])+m['obstacleSafety'];tlo=0.;thi=1.
    if abs(v[2])<1e-12:
     if a[2]<lo or a[2]>hi:continue
    else:
     zt=np.sort((np.array([lo,hi])-a[2])/v[2]);tlo=max(0.,zt[0]);thi=min(1.,zt[1])
    if tlo>thi+1e-12:continue
    center=np.array([obs['x'],obs['y']]);u=a[:2]+tlo*v[:2];z=a[:2]+thi*v[:2];span=z-u
    projection=np.clip(np.dot(center-u,span)/np.dot(span,span),0,1) if np.dot(span,span)>1e-24 else 0.
    if np.linalg.norm(u+projection*span-center)<=obs['r']+m['obstacleSafety']+1e-10:collisions+=1
  points_all.append(points[1:])
  if leg<len(route):
   order=m['orders'][route[leg]-1];arrival=now+dist/m['speed'];wait=max(0,float(order['ready'])-arrival);begin=arrival+wait;ll=max(0,begin-order['due'])
   samples_records.append([order['stationID'],order['ready'],order['due'],arrival,wait,begin,order['service'],begin+order['service'],dist,ll]);late+=ll;waiting+=wait;now=begin+order['service']
  current=target
 finish=now+dist/m['speed'];depotlate=max(0,finish-m['depotDue'])
 assert np.allclose(samples_records,detail['records'],atol=1e-9,rtol=0)
 for actual,key in [(distance,'distance'),(late,'totalLate'),(waiting,'totalWaiting'),(finish,'finishTime'),(depotlate,'depotLate'),(maxclimb,'maxClimbAngle'),(maxturn,'maxTurnAngle')]:assert abs(actual-detail[key])<1e-8,(f,key)
 assert collisions==int(detail['obstacleViolation'])
 assert maxclimb<=m['maxClimbAngle']+1e-8 or detail['totalAngleViolation']>0
 timeok=late<1e-8 and depotlate<1e-8
 assert not timeok and not detail['feasible']
 records.append(dict(file=str(f.relative_to(out)),distance=distance,late=late,returnTime=finish,collisions=collisions,denseMinClearance=minclear,timeFeasible=bool(timeok),independentPassed=True))
report={'verifiedRuns':len(records),'allPassed':True,'denseMaxStep':.05,'records':records}
(w/'independent_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'independent_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS independent Python decode/distance/schedule/climb/turn and analytic cylinder checks for',len(records),'runs.')
