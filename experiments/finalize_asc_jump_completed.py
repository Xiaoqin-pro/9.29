"""Finish the completed pilot if MATLAB misread the post-run hash-table delimiter."""
from pathlib import Path
import hashlib,json
import pandas as pd
import numpy as np
from scipy.io import loadmat
ROOT=Path(__file__).resolve().parents[1];run=ROOT/'results/cec'/Path((ROOT/'work/asc_jump_latest.txt').read_text(encoding='utf8').strip()).name
status=json.loads((run/'status.json').read_text(encoding='utf8'));assert status['Completed']==status['Total']==240
hashes=pd.read_csv(run/'prelaunch_hashes.csv');assert set(['Path','RelativePath','SHA256','Bytes']).issubset(hashes.columns)
for h in hashes.itertuples():
 p=run/h.RelativePath;assert hashlib.sha256(p.read_bytes()).hexdigest()==h.SHA256 and p.stat().st_size==h.Bytes
raw=pd.read_csv(run/'raw_runs.csv');assert len(raw)==240 and raw.Status.eq('ok').all() and raw.ObjectiveCalls.eq(100000).all()
for row in raw.itertuples():
 z=loadmat(run/'runs'/row.Artifact,simplify_cells=True,variable_names=['T','B','rec']);T=np.asarray(z['T']).reshape(-1)
 assert len(T)==100000 and np.isfinite(T).all() and np.all(np.diff(T)<=0)
 assert z['B']['Cost']==T[-1] and z['rec']['Status']=='ok' and z['rec']['ObjectiveCalls']==100000
 assert np.isclose(T[-1],row.FinalCost,rtol=1e-12,atol=1e-9)
event={'Passed':True,'Reason':'MATLAB post-run readtable did not expose Path column; no optimizer or budget error.',
       'FrozenHashesChecked':len(hashes),'SavedRunArtifactsChecked':240,'OptimizationRunsRepeated':0,'FrozenSourcesModified':False}
(run/'completion_recovery.json').write_text(json.dumps(event,ensure_ascii=False,indent=2),encoding='utf8')
status.update(Status='complete',SnapshotHashesVerified=True,CompletionAudit='Python post-run hash and MAT verification')
(run/'status.json').write_text(json.dumps(status,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(event,indent=2))
