"""Cross-route source and common initial-population checks, full completed batches only."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
import pandas as pd
from scipy.io import loadmat
p=argparse.ArgumentParser();p.add_argument('a',type=Path);p.add_argument('b',type=Path);z=p.parse_args();A=pd.read_csv(z.a/'raw_runs.csv');B=pd.read_csv(z.b/'raw_runs.csv');assert len(A)==360 and len(B)==160
pairs=0
for fid in sorted(A.FunctionID.unique()):
    for seed in sorted(A.Seed.unique()):
        aa=A[(A.FunctionID==fid)&(A.Seed==seed)&(A.Condition=='Old-Q')].iloc[0];bb=B[(B.FunctionID==fid)&(B.Seed==seed)&(B.Condition=='Q-reset')].iloc[0]
        x=loadmat(z.a/'runs'/f'job_{int(aa.JobID):04d}.mat',simplify_cells=True);y=loadmat(z.b/'runs'/f'job_{int(bb.JobID):04d}.mat',simplify_cells=True)
        assert aa.InitSeed==bb.InitSeed and aa.SearchSeed==bb.SearchSeed and np.array_equal(x['p0'],y['p0']);pairs+=1
root=Path(__file__).resolve().parents[1];files=[]
for run in [z.a,z.b]:
    for f in sorted((run/'source_snapshot').rglob('*')):
        if f.is_file():
            rel=f.relative_to(run/'source_snapshot');h=lambda q:hashlib.sha256(q.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
            assert h(f)==h(root/rel),str(rel);files.append(str(rel))
result=dict(CommonInitialGroups=pairs,SourceSnapshots=len(files),Passed=True,Scope='matching actual p0 and unchanged source snapshots; routes may legitimately have different subsequent trajectories')
out=root/'results/cso_two_routes_20261012';out.mkdir(exist_ok=True);(out/'cross_route_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
