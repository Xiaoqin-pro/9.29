from pathlib import Path
import json
import numpy as np
from scipy.io import loadmat
from scipy.interpolate import RegularGridInterpolator
out=Path(__file__).resolve().parent.parent
rows=[]
files=list((out/'runs').glob('*.mat'))
for file in sorted(files):
    v=loadmat(file,simplify_cells=True);m=v['model'];s=v['state'];best=v['Best'];detail=best['Detail'];mode='full'
    route=np.asarray(best['Route'],int).ravel();n=len(route);vector=np.asarray(best['Vector'],float)
    orders=m['orders'];current=np.asarray(s['position'],float);now=max(float(s['time']),float(m['depotReady']))
    distance=waiting=late=smooth=angle=terrain=obstacle=mapv=altv=0.;maxclimb=maxturn=0.;minclear=np.inf;records=[]
    if mode!='route':
        controls=vector[n:].reshape((n+1,int(m['nControlPoints']),3),order='F') if mode=='full' else vector.reshape((n+1,int(m['nControlPoints']),3),order='F')
        controls[:,:,0]=float(m['minControlRatio'])+controls[:,:,0]*(float(m['maxControlRatio'])-float(m['minControlRatio']))
        controls[:,:,1]=-float(m['maxSideOffset'])+2*float(m['maxSideOffset'])*controls[:,:,1]
        controls[:,:,2]=float(m['minHeightOffset'])+(float(m['maxHeightOffset'])-float(m['minHeightOffset']))*controls[:,:,2]
        for i in range(n+1):controls[i]=controls[i,np.argsort(controls[i,:,0],kind='stable')]
        assert np.allclose(controls,best['Control'],atol=1e-12,rtol=0)
        gx=np.asarray(m['X'],float)[0];gy=np.asarray(m['Y'],float)[:,0];ground=RegularGridInterpolator((gy,gx),np.asarray(m['terrainZ'],float))
    if mode!='control':
        ids=np.asarray(s['activeIDs'],int);expected=ids[np.argsort(vector[:n],kind='stable')]
        assert np.array_equal(route,expected)
    else:assert np.array_equal(route,v['fixedRoute'])
    for leg in range(n+1):
        target=np.asarray(orders[route[leg]-1]['xyz'] if leg<n else m['depot'],float);move=target-current
        if mode=='route':points=np.vstack([current,target])
        else:
            horizontal=np.linalg.norm(move[:2]);side=np.array([-move[1],move[0]])/horizontal if horizontal else np.array([1.,0.])
            c=controls[leg];mid=current+c[:,0,None]*move;mid[:,:2]+=c[:,1,None]*side;mid[:,2]+=c[:,2]
            points=np.vstack([current,mid,target]);assert np.allclose(points,detail['paths'][leg]['points'],atol=1e-11,rtol=0)
        segments=np.diff(points,axis=0);length=np.linalg.norm(segments,axis=1).sum();distance+=length
        if mode!='route':
            pitch=np.degrees(np.arctan2(segments[:,2],np.linalg.norm(segments[:,:2],axis=1)))
            a=segments[:-1,:2];b=segments[1:,:2];turn=np.degrees(np.arctan2(np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0]),np.sum(a*b,axis=1)))
            angle+=np.maximum(0,np.abs(pitch)-m['maxClimbAngle']).sum()+np.maximum(0,turn-m['maxTurnAngle']).sum()
            smooth+=((turn/m['maxTurnAngle'])**2).sum()+((np.diff(pitch)/m['maxClimbAngle'])**2).sum()
            maxclimb=max(maxclimb,np.max(np.abs(pitch)));maxturn=max(maxturn,np.max(turn,initial=0))
            mapv+=(np.maximum(0,-points[:,:2])+np.maximum(0,points[:,:2]-m['mapSize'])).sum();altv+=np.maximum(0,points[:,2]-m['maxAltitude']).sum()
            for start,delta in zip(points[:-1],segments):
                cuts=[0.,1.]
                for axis,grid in [(0,gx),(1,gy)]:
                    if abs(delta[axis])>np.finfo(float).eps:cuts.extend((grid-start[axis])/delta[axis])
                cuts=np.unique([t for t in cuts if 0<=t<=1]);minimum=np.inf
                # Independent per-cell quadratic minimum: fit z-ground at local u=0,.5,1.
                for lo,hi in zip(cuts[:-1],cuts[1:]):
                    t=np.array([lo,(lo+hi)/2,hi]);p=start+t[:,None]*delta;xy=np.clip(p[:,:2],0,m['mapSize']);h=p[:,2]-ground(xy[:,::-1])
                    aa=2*(h[2]+h[0]-2*h[1]);bb=h[2]-h[0]-aa;local=min(h[0],h[2])
                    if aa>1e-12:
                        u=np.clip(-bb/(2*aa),0,1);local=min(local,h[0]+bb*u+aa*u*u)
                    minimum=min(minimum,local)
                terrain+=max(0,m['minClearance']-minimum);minclear=min(minclear,minimum)
                # Independent cylinder intersection: height clip then nearest XY point.
                for obs in m['obstacles']:
                    low=obs['zMin']-m['obstacleSafety'];high=obs['zMax']+m['obstacleSafety'];lo=0.;hi=1.
                    if abs(delta[2])<np.finfo(float).eps:
                        if start[2]<low or start[2]>high:continue
                    else:
                        pair=np.sort((np.array([low,high])-start[2])/delta[2]);lo=max(lo,pair[0]);hi=min(hi,pair[1])
                    if lo>hi+1e-12:continue
                    a=start[:2]+lo*delta[:2];b=start[:2]+hi*delta[:2];span=b-a;center=np.array([obs['x'],obs['y']])
                    u=np.clip(np.dot(center-a,span)/np.dot(span,span),0,1) if np.dot(span,span)>1e-24 else 0.
                    if np.linalg.norm(a+u*span-center)<=obs['r']+m['obstacleSafety']+1e-10:obstacle+=1
        if leg<n:
            o=orders[route[leg]-1];arrival=now+length/m['speed'];wait=max(0,o['ready']-arrival);begin=arrival+wait;amount=max(0,begin-o['due']);now=begin+o['service']
            records.append([o['stationID'],o['ready'],o['due'],arrival,wait,begin,o['service'],now,length,amount]);waiting+=wait;late+=amount
        current=target
    finish=now+length/m['speed'];depotlate=max(0,finish-m['depotDue']);objective=distance+.05*waiting+m['smoothWeight']*smooth
    cost=objective
    for value,weight in [(late+depotlate,1000),(angle,10000),(terrain,10000),(obstacle,10000),(mapv,10000),(altv,10000)]:
        if value>1e-8:cost+=100000+weight*value
    assert abs(cost-best['Cost'])<1e-6,(file.name,'cost',cost,best['Cost'])
    checks=[(distance,'distance'),(late,'totalLate'),(waiting,'totalWaiting'),(depotlate,'depotLate'),(finish,'finishTime'),(angle,'totalAngleViolation'),(terrain,'terrainViolation'),(obstacle,'obstacleViolation'),(mapv,'mapViolation'),(altv,'altitudeViolation')]
    for actual,key in checks:assert abs(actual-detail[key])<1e-7,(file.name,key,actual,detail[key])
    assert np.allclose(records,detail['records'],atol=1e-8,rtol=0)
    feasible=all(x<1e-8 for x in [late,depotlate,angle,terrain,obstacle,mapv,altv]);assert feasible==bool(detail['feasible'])
    rows.append(dict(file=str(file.relative_to(out)),mode=mode,passed=True,feasible=feasible,distance=float(distance),late=float(late),collisions=int(obstacle),terrainViolation=float(terrain),angleViolation=float(angle),cost=float(cost)))
assert len(rows)==27
(out/'independent_checks.json').write_text(json.dumps(dict(verifiedRuns=len(rows),allPassed=True,records=rows),indent=2),encoding='utf-8')
print('PASS independent decoding/geometry/time/Cost for',len(rows),'final platform runs.')
