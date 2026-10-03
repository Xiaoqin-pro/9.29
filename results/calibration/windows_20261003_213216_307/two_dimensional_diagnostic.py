from pathlib import Path
import csv,math,time,json
root=Path(__file__).resolve().parents[3]
w=Path(__file__).resolve().parent
def count_routes(file,width):
 rows=list(csv.DictReader(file.open(encoding='utf-8-sig')))
 xy=[(float(r['X']),float(r['Y'])) for r in rows]
 ready=[float(r['Ready']) for r in rows];due=[r+width for r in ready]
 service=[float(r['Service']) for r in rows];n=len(rows);allbits=(1<<n)-1
 dist=[[math.dist(a,b)/6 for b in xy] for a in xy]
 start=[math.dist((40,50),b)/6 for b in xy]
 memo_calls=0;routes=[];count=0;t0=time.time()
 def dfs(mask,last,t,path):
  nonlocal memo_calls,count
  memo_calls+=1
  if mask==allbits:
   if t+start[last]<=240+1e-8:
    count+=1
    if len(routes)<5:routes.append([int(rows[i]['ID']) for i in path])
   return
  remain=[j for j in range(n) if not mask>>j&1]
  travel=dist[last] if last>=0 else start
  if any(max(ready[j],t+travel[j])>due[j]+1e-8 for j in remain):return
  for j in remain:
   begin=max(ready[j],t+travel[j])
   if begin<=due[j]+1e-8:dfs(mask|1<<j,j,begin+service[j],path+[j])
 dfs(0,-1,0,[])
 return dict(file=file.name,width=width,count=count,examples=routes,nodes=memo_calls,seconds=time.time()-t0,
  assumptions='2D Euclidean travel, speed=6, service as CSV, waiting allowed, customer service-start deadlines, depot due=240; no terrain/threat/angle')
results=[]
for n,widths in [(10,[12,18,24,30,45]),(15,[12]),(20,[12])]:
 for width in widths:
  r=count_routes(root/'data/experiment_cases'/f'N{n}_tight.csv',width)
  results.append(r);print(r,flush=True)
(w/'two_dimensional_diagnostic.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
