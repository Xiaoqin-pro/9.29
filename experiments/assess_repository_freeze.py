"""Recompute comparable same-cohort Q results used in the freeze assessment."""
from pathlib import Path
import hashlib,json
import pandas as pd
root=Path(__file__).resolve().parents[1];out=root/'results/freeze_assessment_20261012';out.mkdir(exist_ok=True)
cohorts=[('development1401','results/cso_mode_q_20261012/raw_runs.csv',{'q':'previousQ','fixed6':'fixed6','fixed4':'fixed4','random':'random','phase':'phase','epsfixed':'epsfixed'}),('confirmation1501','results/cso_mode_q_state_confirm_20261012/raw_runs.csv',{'binaryQ':'previousQ','stag1000':'stallQ','fixed6':'fixed6','fixed4':'fixed4','random':'random','phase':'phase','epsfixed':'epsfixed'}),('new_development1801','results/cso_mode_efficiency_20261012/raw_runs.csv',{'previousQ':'previousQ','stallQ':'stallQ','effQ':'effQ','fixed6':'fixed6','fixed4':'fixed4','random':'random','phase':'phase','epsfixed':'epsfixed','effrule':'effrule'})]
rows=[];files=[]
for cohort,source,names in cohorts:
    p=root/source;files.append(p);x=pd.read_csv(p);x=x[x.Condition.isin(names)].copy();x['Method']=x.Condition.map(names)
    if cohort=='development1401':
        ep=root/'results/cso_mode_q_state_20261012/raw_runs.csv';files.append(ep);extra=pd.read_csv(ep);extra=extra[extra.Condition=='stag1000'].copy();extra['Method']='stallQ';x=pd.concat([x,extra],ignore_index=True)
    pairs=[(candidate,control) for candidate in ['previousQ','stallQ','effQ'] if candidate in set(x.Method) for control in ['fixed6','fixed4','random','phase','epsfixed']]
    if {'previousQ','stallQ'}.issubset(set(x.Method)):pairs.append(('stallQ','previousQ'))
    for candidate,control in pairs:
        aa=x[x.Method==candidate];bb=x[x.Method==control];m=aa.merge(bb,on=['FunctionID','Seed','Budget','Dimension','InitSeed','SearchSeed'],suffixes=('_a','_b'),validate='one_to_one');assert len(m)==len(aa)
        am=m.groupby('FunctionID').FinalError_a.mean();bm=m.groupby('FunctionID').FinalError_b.mean()
        rows.append(dict(Cohort=cohort,Candidate=candidate,Control=control,Functions=len(am),Pairs=len(m),FunctionWins=int((am<bm).sum()),FunctionLosses=int((am>bm).sum()),SeedWins=int((m.FinalError_a<m.FinalError_b).sum()),SeedLosses=int((m.FinalError_a>m.FinalError_b).sum())))
pd.DataFrame(rows).to_csv(out/'comparable_quota_q_cohorts.csv',index=False)
manifest=dict(Scope='Stored data reanalysis, no new optimization; each cohort remains separate; cached development is not independent confirmation.',Sources=[dict(Path=str(f.relative_to(root)).replace('\\','/'),SHA256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in files])
(out/'source_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(pd.DataFrame(rows).query("Control=='fixed6' or Control=='previousQ'").to_string(index=False))
