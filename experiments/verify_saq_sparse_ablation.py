"""Independent saved-artifact validation for sparse-framework ablations.
Works on partial progress too; no significance analysis until full5220 records.
"""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
import pandas as pd
from scipy.io import loadmat


def validate(run_dir,output,complete=False):
    run=Path(run_dir).resolve();out=Path(output).resolve();out.mkdir(parents=True,exist_ok=True)
    raw=pd.read_csv(run/'raw_runs.csv');assert raw.Status.eq('ok').all()
    if complete:assert len(raw)==5220 and (run/'COMPLETED.json').exists()
    pre=json.loads((run/'source_snapshot/preflight.json').read_text(encoding='utf-8'))
    assert pre['Passed'] and pre['Full100kNewVariants']==5
    root=Path(__file__).resolve().parents[1]
    for key,rel in [('Engine','src/SAQ_CSO_FrameworkAblation.m'),('Variant','src/SAQ_CSO_AblationVariant.m'),('FrozenMain','src/ASE_CSO_QuotaQ_Compact.m')]:
        path=run/'source_snapshot'/rel;assert hashlib.sha256(path.read_bytes()).hexdigest()==pre['SourceHashes'][key]
        assert path.read_bytes()==(root/rel).read_bytes(),f'Current code differs from running snapshot {rel}'
    assert raw.Budget.eq(100000).all() and raw.Population.eq(50).all() and raw.Dimension.eq(50).all()
    assert raw.ObjectiveCalls.eq(100000).all() and raw.Evaluations.eq(100000).all() and raw.PostRunRecheckCalls.eq(1).all() and raw.OutsideCalls.eq(0).all()
    assert not raw.duplicated(['FunctionID','Seed','Variant']).any()
    same_p0={};curve=[];checked=0;roundchecks=0;qchecks=0;nodes=np.unique(np.r_[50,np.linspace(2000,100000,60).round().astype(int),20000,60000,80000,100000])
    for r in raw.itertuples():
        d=loadmat(run/'runs'/f'job_{r.JobID:04d}.mat',simplify_cells=True);I=d['I'];B=d['B'];job=d['job'];T=np.asarray(d['T']).reshape(-1);p0=np.asarray(d['p0'])
        for field in ['JobID','FunctionID','Seed','InitSeed','SearchSeed','Budget','Variant','Condition']:assert job[field]==getattr(r,field)
        assert len(T)==100000 and np.isfinite(T).all() and np.all(np.diff(T)<=0)
        assert np.isclose(B['Cost'],r.FinalCost,rtol=1e-13,atol=1e-7) and T[-1]==B['Cost']
        assert np.isclose(T[49],r.InitialCost,rtol=1e-13,atol=1e-7)
        assert np.isclose(r.FinalError,r.FinalCost-100*r.FunctionID,rtol=1e-11,atol=1e-7)
        v=np.asarray(B['Vector']).reshape(-1);assert len(v)==50 and np.isfinite(v).all() and ((v>=-100)&(v<=100)).all()
        assert p0.shape==(50,50) and np.array_equal(p0,np.asarray(I['InitialPopulation'])) and np.isfinite(p0).all() and ((p0>=-100)&(p0<=100)).all()
        key=(r.FunctionID,r.Seed)
        if key in same_p0:assert np.array_equal(p0,same_p0[key])
        else:same_p0[key]=p0
        if bool(r.FromCache):
            assert r.Variant=='Full';old=loadmat(Path(r.SourceDirectory)/'runs'/f'job_{int(r.SourceJobID):04d}.mat',simplify_cells=True)
            assert np.array_equal(old['T'],T) and np.array_equal(old['p0'],p0) and old['B']['Cost']==B['Cost']
            assert np.array_equal(old['I']['QTable'],I['QTable']) and np.array_equal(old['I']['RoundLog'],I['RoundLog'])
        else:
            assert I['AblationVariant']==r.Variant
            assert I['EvaluationMode']==('dense' if r.Variant=='Dense-NoQ' else 'sparse')
            assert I['ScreenPolicy']==('random' if r.Variant=='RandomSparse-Fixed6' else 'geometry') and I['VirtualTracing']
        R=np.asarray(I['RoundLog']).reshape(-1,13);assert len(R)==I['Rounds']==r.Rounds
        assert np.array_equal(R[:,0],np.r_[50,R[:-1,1]]) and R[-1,1]==100000
        assert np.array_equal(R[:,1]-R[:,0],R[:,2]+R[:,3]) and np.all(R[:,1]>R[:,0])
        assert np.all(R[:,4]+R[:,5]==50)
        assert R[:,2].sum()==r.TracingEvaluations==I['TracingEvaluations'] and R[:,3].sum()==r.SeekingEvaluations==I['SeekingEvaluations']
        assert r.TracingEvaluations+r.SeekingEvaluations==99950
        generated=float((R[:,4]+4*R[:,5]).sum());assert generated==r.CandidatePointsGenerated
        assert np.isclose(99950/generated,r.RealEvaluationFraction,rtol=1e-13) and np.isclose(99950/len(R),r.MeanRoundCost,rtol=1e-13)
        if r.Variant=='Dense-NoQ':
            assert np.array_equal(R[:-1,2],R[:-1,4]) and np.array_equal(R[:-1,3],4*R[:-1,5])
            assert R[-1,2]<=R[-1,4] and R[-1,3]<=4*R[-1,5] and I['MaxParentEvaluations']<=4 and len(R)<9995
        else:
            assert len(R)==9995 and np.all(R[:-1,1]-R[:-1,0]==10) and I['MaxParentEvaluations']<=2
        if r.Variant!='Full':
            F=np.asarray(I['FrameworkLog']).reshape(-1,7)
            assert np.array_equal(F[:,:3],R[:,[0,1,4]]) and np.array_equal(F[:,3],4*R[:,5]) and np.array_equal(F[:,4:6],R[:,2:4])
            assert np.all(F[:,6]==int(r.Variant=='Dense-NoQ'))
        successes=np.r_[0,np.cumsum(np.diff(T[49:])<0)]
        assert np.array_equal(successes[(R[:,1]-50).astype(int)]-successes[(R[:,0]-50).astype(int)],R[:,9]+R[:,10])
        assert np.isclose(R[:,11:].sum(),T[49]-T[-1],rtol=1e-10,atol=1e-6)
        DL=np.asarray(I['DecisionLog']).reshape(-1,14);U=np.asarray(I['UpdateLog']).reshape(-1,8);G=np.asarray(I['GateLog']).reshape(-1,3);SL=np.asarray(I['StateLog']).reshape(-1,3)
        RL=np.asarray(I['RewardLog']).reshape(-1,4);discount=np.asarray(I['DiscountLog']).reshape(-1)
        assert len(DL)==I['Decisions']==r.Decisions and len(U)==len(DL)
        lo=DL[:,0].astype(int);hi=DL[:,1].astype(int);assert np.array_equal(lo,np.r_[50,hi[:-1]]) and hi[-1]==100000
        assert np.array_equal(DL[:,7],T[lo-1]) and np.array_equal(DL[:,8],T[hi-1]) and np.array_equal(hi-lo,DL[:,10]+DL[:,11])
        reward=np.where(DL[:,7]>DL[:,8],10,-1);assert np.array_equal(DL[:,9],reward) and np.array_equal(RL[:,2],reward)
        assert np.array_equal(RL[:,1],DL[:,7]-DL[:,8]) and np.array_equal(RL[:,3],DL[:,8])
        changes=np.r_[False,np.diff(T)<0];changes[:50]=False;last=np.maximum.accumulate(np.where(changes,np.arange(1,len(T)+1),50))
        assert np.array_equal(SL[:,0],lo-last[lo-1]);sig=(SL[:,0]>=1000).astype(int);phase=np.minimum(2,np.floor(3*(lo-50)/99950)).astype(int)
        assert np.array_equal(SL[:,1],sig)
        gated=r.Variant in ['Full','RandomQuota'];states=phase+1 if gated else 1+2*phase+sig
        assert np.array_equal(DL[:,2],states) and np.array_equal(SL[:,2],states)
        assert np.array_equal(G[:,0],np.full(len(DL),int(gated))) and np.array_equal(G[:,1],sig if gated else np.ones(len(DL)))
        assert np.array_equal(G[:,2],DL[:,3]) and np.array_equal(DL[:,4],2*DL[:,3])
        if gated:assert np.all(DL[sig==0,4]==6)
        elif r.Variant=='Fixed4':assert np.all(DL[:,4]==4)
        else:assert np.all(DL[:,4]==6)
        bi=np.searchsorted(hi,R[:,0],side='right');qt=DL[bi,4];cost=R[:,1]-R[:,0];diagnostic_budget=np.minimum(10,100000-R[:,0]);expected=np.minimum(qt,np.maximum(1,diagnostic_budget-1))
        # Original quota diagnostics keep10-slot plan even in dense, where noQ uses it.
        fallback=(R[:,2]!=expected)|(R[:,3]!=diagnostic_budget-expected)
        assert np.array_equal(np.bincount(bi,weights=R[:,2],minlength=len(DL)),DL[:,10]) and np.array_equal(np.bincount(bi,weights=R[:,3],minlength=len(DL)),DL[:,11])
        assert np.array_equal(np.bincount(bi,weights=fallback,minlength=len(DL)),DL[:,12])
        eligible=(DL[:,12]==0)&(G[:,1]==1)
        assert np.array_equal(U[:,:3],DL[:,[2,3,9]]) and np.array_equal(U[:,5:7],DL[:,:2]) and np.array_equal(U[:,7],eligible)
        assert np.array_equal(U[:-1,3],states[1:]) and U[-1,4]==1 and U[-1,3]==0
        assert np.allclose(discount,.9**((hi-lo)/100),rtol=0,atol=1e-15) and not I['PendingAtEnd']
        if r.Variant=='Full':
            replay=np.zeros((3,3));visits=np.zeros((3,3),int)
            for j,u in enumerate(U):
                if u[7]:
                    st=int(u[0])-1;ac=int(u[1])-1;future=0 if u[4] or sig[j+1]==0 else discount[j]*replay[int(u[3])-1].max()
                    replay[st,ac]+=.1*(u[2]+future-replay[st,ac]);visits[st,ac]+=1
            assert np.allclose(replay,I['QTable'],rtol=0,atol=1e-12) and np.array_equal(visits,I['QVisits']) and visits.sum()==r.QUpdates
            assert np.array_equal(DL[:,13],eligible)
        else:assert I['QUpdates']==r.QUpdates==0 and np.all(np.asarray(I['QVisits'])==0) and np.all(DL[:,13]==0)
        for frac,col in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:assert np.isclose(T[round(frac*100000)-1]-100*r.FunctionID,getattr(r,col),rtol=1e-11,atol=1e-7)
        for fe,val in zip(nodes,T[nodes-1]):curve.append({'FunctionID':r.FunctionID,'Seed':r.Seed,'Condition':r.Condition,'FE':int(fe),'Error':float(val-100*r.FunctionID)})
        checked+=1;roundchecks+=len(R);qchecks+=len(DL)
        if checked%500==0:print(f'VALIDATED {checked}/{len(raw)}',flush=True)
    result={'Passed':True,'FullBatch':complete,'QualityRecords':checked,'SharedPopulationGroups':len(same_p0),'RoundChecks':roundchecks,'DecisionChecks':qchecks,'CachedFullRecords':int(raw.FromCache.sum()),'NewOptimizationRecords':int((~raw.FromCache.astype(bool)).sum()),'NoNewObjectiveChecksInPython':True,'CachedTraceAndQExact':True,'PreflightSourceSHAEqual':True}
    (out/'independent_artifact_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    curves=pd.DataFrame(curve).groupby(['FunctionID','Condition','FE']).Error.mean().reset_index()
    print(json.dumps(result,indent=2));return raw,curves,result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--out',type=Path,required=True);p.add_argument('--complete',action='store_true');a=p.parse_args();validate(a.run_dir,a.out,a.complete)
