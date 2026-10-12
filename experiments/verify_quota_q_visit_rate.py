"""Independently check saved MATLAB artifacts against the public CSV."""
from pathlib import Path
import argparse, json
import numpy as np
import pandas as pd
from scipy.io import loadmat

p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--complete',action='store_true');args=p.parse_args()
run_dir=args.run_dir.resolve();raw=pd.read_csv(run_dir/'raw_runs.csv')
if args.complete:assert (run_dir/'COMPLETED.json').exists() and len(raw)==40
same_initial={};checked=0
for row in raw.itertuples():
    data=loadmat(run_dir/'runs'/f'job_{row.JobID:04d}.mat',simplify_cells=True)
    T=np.asarray(data['T']).reshape(-1);I=data['I'];B=data['B'];R=np.asarray(I['RoundLog']).reshape(-1,13)
    assert len(T)==row.Budget and np.isfinite(T).all() and (np.diff(T)<=0).all()
    assert abs(float(B['Cost'])-row.FinalCost)<=1e-8*max(1,abs(row.FinalCost))
    assert T[-1]==float(B['Cost']) and len(R)==row.Rounds
    assert np.allclose(R[:,1]-R[:,0],R[:,2]+R[:,3],rtol=0,atol=0)
    assert R[:,2].sum()==row.TracingEvaluations and R[:,3].sum()==row.SeekingEvaluations
    for col, raw_count in [(9,row.TraceGlobalSuccesses),(10,row.SeekGlobalSuccesses)]:assert R[:,col].sum()==raw_count
    # Count improvements from T independently and compare every round with counters.
    delta=np.diff(T[49:]);start=(R[:,0]-50).astype(int);stop=(R[:,1]-50).astype(int)
    cumulative=np.r_[0,np.cumsum(delta<0)]
    assert np.array_equal(cumulative[stop]-cumulative[start],R[:,9]+R[:,10])
    gain=float(R[:,11:].sum());total=float(T[49]-T[-1]);assert abs(gain-total)<=1e-10*max(1,abs(total))
    for frac,col in [(.2,'Error20FE'),(.6,'Error60FE'),(.8,'Error80FE')]:
        v=T[int(round(frac*row.Budget))-1]-100*row.FunctionID
        assert abs(v-getattr(row,col))<=1e-8*max(1,abs(v))
    key=(row.FunctionID,row.Seed,row.Budget);p0=np.asarray(data['p0'])
    assert p0.shape==(50,50) and np.isfinite(p0).all() and ((p0>=-100)&(p0<=100)).all()
    if key in same_initial:assert np.array_equal(same_initial[key],p0)
    else:same_initial[key]=p0
    assert np.asarray(B['Vector']).shape==(50,) and np.isfinite(B['Vector']).all()
    assert ((np.asarray(B['Vector'])>=-100)&(np.asarray(B['Vector'])<=100)).all()
    decisions=np.asarray(I['DecisionLog']).reshape(-1,14);updates=np.asarray(I['UpdateLog']).reshape(-1,8)
    assert len(decisions)<=1000 and len(updates)==len(decisions)
    lo=decisions[:,0].astype(int);hi=decisions[:,1].astype(int)
    assert np.array_equal(decisions[:,7],T[lo-1]) and np.array_equal(decisions[:,8],T[hi-1])
    assert np.all(hi-lo==decisions[:,10]+decisions[:,11]) and np.all(hi-lo<=row.EpisodeFE)
    reward_a=np.asarray(I['RewardLog']).reshape(-1,4);trend=np.asarray(I['TrendLog']).reshape(-1,7)
    gain=np.maximum(0,decisions[:,7]-decisions[:,8])
    assert np.array_equal(reward_a[:,0],trend[:-1,3]) and np.array_equal(reward_a[:,1],gain) and np.array_equal(reward_a[:,3],decisions[:,8])
    if row.RewardMode=='positive':reward=(gain>0).astype(int)
    elif row.RewardMode=='gain':reward=np.minimum(1,gain/np.maximum(reward_a[:,0],np.finfo(float).eps))
    elif row.RewardMode=='binary':reward=10*(gain>0).astype(int)-(gain<=0).astype(int)
    else:raise AssertionError(row.RewardMode)
    assert np.array_equal(reward_a[:,2],decisions[:,9])
    assert np.allclose(reward,decisions[:,9],rtol=0,atol=1e-15)
    assert np.array_equal(trend[:,5],T[trend[:,0].astype(int)-1]) and np.isfinite(trend).all()
    previous=np.r_[False,decisions[:-1,8]<decisions[:-1,7]]
    phase=np.minimum(2,np.floor(3*(lo-50)/(row.Budget-50))).astype(int)
    state_log=np.asarray(I['StateLog']).reshape(-1,3)
    improvements=np.flatnonzero(np.diff(T)<0)+2;improvements=improvements[improvements>50]
    last_map=np.maximum.accumulate(np.where(np.isin(np.arange(1,len(T)+1),improvements),np.arange(1,len(T)+1),50))
    assert np.array_equal(state_log[:,0],lo-last_map[lo-1])
    assert np.array_equal(state_log[:,0],trend[:-1,4])
    if row.StateMode=='previous':expected_signal=(~previous).astype(int)
    else:expected_signal=(state_log[:,0]>=row.StagnationThreshold).astype(int)
    assert np.array_equal(state_log[:,1],expected_signal)
    states=1+2*phase+state_log[:,1]
    assert np.array_equal(state_log[:,2],states)
    assert np.array_equal(decisions[:,2],states) and np.array_equal(decisions[:,6],previous.astype(int)) and np.array_equal(decisions[:,9],reward)
    assert np.array_equal(updates[:,:3],decisions[:,[2,3,9]]) and np.array_equal(updates[:,5:7],decisions[:,:2])
    assert np.array_equal(updates[:-1,3],decisions[1:,2]) and updates[-1,3]==0 and updates[-1,4]==1 and np.all(updates[:-1,4]==0)
    gate=np.asarray(I['GateLog']).reshape(-1,3)
    assert np.array_equal(gate[:,1],state_log[:,1]) and np.all(gate[:,0]==1) and np.array_equal(gate[:,2],decisions[:,3])
    assert np.all(decisions[gate[:,1]==0,3]==3)
    duration=hi-lo;planned=np.where(gate[:,1]==1,row.EpisodeFE,100)
    assert np.array_equal(duration,np.minimum(planned,row.Budget-lo)) and I['EpisodeFE']==row.EpisodeFE and I['RewardBonus']==10
    discount=np.asarray(I['DiscountLog']).reshape(-1);assert np.allclose(discount,.9**(duration/100),rtol=0,atol=1e-15)
    assert np.array_equal(updates[:,7],((decisions[:,12]==0)&(gate[:,1]==1)).astype(int)) and not bool(I['PendingAtEnd'])
    assert np.all(decisions[:,4]==2*decisions[:,3])
    assert lo[0]==50 and hi[-1]==row.Budget and np.array_equal(lo[1:],hi[:-1])
    # Map every real round to its actual decision; validate executed quotas/fallback masks.
    block_index=np.searchsorted(hi,R[:,0],side='right')
    quotas=decisions[block_index,4]
    quota_size=R[:,1]-R[:,0];expected_trace=np.minimum(quotas,np.maximum(1,quota_size-1))
    fallback=(R[:,2]!=expected_trace)|(R[:,3]!=quota_size-expected_trace)
    assert np.array_equal(np.bincount(block_index,weights=R[:,2],minlength=len(decisions)),decisions[:,10])
    assert np.array_equal(np.bincount(block_index,weights=R[:,3],minlength=len(decisions)),decisions[:,11])
    assert np.array_equal(np.bincount(block_index,weights=fallback.astype(int),minlength=len(decisions)),decisions[:,12])
    assert row.QuotaFallbackRounds==int(fallback.sum())
    assert np.array_equal(R[:,0],np.r_[50,R[:-1,1]]) and R[-1,1]==row.Budget
    assert row.PositiveRewardBlocks==int((gain>0).sum()) and row.Decisions==len(decisions)
    replay=np.zeros((6,3));visits=np.zeros((6,3),dtype=int)
    rates=np.asarray(I['RateLog']).reshape(-1);assert I['LearningRateMode']=='visit'
    if row.ModePolicy=='gateq':
        for index,u in enumerate(updates):
            if u[7]:
                st=int(u[0])-1;ac=int(u[1])-1;future=0 if u[4] else discount[index]*replay[int(u[3])-1].max()
                rate=1/(1+visits[st,ac]);assert abs(rates[index]-rate)<1e-15
                replay[st,ac]+=rate*(u[2]+future-replay[st,ac]);visits[st,ac]+=1
        assert np.array_equal(visits,np.asarray(I['QVisits'])) and np.allclose(replay,np.asarray(I['QTable']),rtol=0,atol=1e-12)
        assert np.all(decisions[:,13]==updates[:,7])
    else:assert np.all(decisions[:,13]==0)
    assert row.QUpdates==visits.sum() and I['QUpdates']==visits.sum()
    if row.ModePolicy.startswith('fixed'):assert np.all(decisions[:,4]==int(row.ModePolicy[5:]))
    if row.ModePolicy=='phase':assert np.all(decisions[:,3]==2+(phase==2).astype(int))
    for ac,name in [(1,'Action1Share'),(2,'Action2Share'),(3,'Action3Share')]:assert abs(getattr(row,name)-(decisions[:,3]==ac).mean())<1e-12
    assert row.FreeDecisions==gate[:,1].sum() and row.ForcedFixed6Decisions==(gate[:,1]==0).sum()
    assert np.all(np.asarray(I['QVisits'])[[0,2,4],:]==0) and np.all(np.asarray(I['QTable'])[[0,2,4],:]==0)
    if row.ModePolicy=='gate2':assert np.all(decisions[gate[:,1]==1,3]==1)
    if row.ModePolicy=='gate4':assert np.all(decisions[gate[:,1]==1,3]==2)
    checked+=1
result=dict(RunsChecked=checked,AllCompleted=args.complete,SharedInitialGroups=len(same_initial),Passed=True,Checks='CSV/MAT/FE/monotone-T/mode counters/every-round global successes/gain telescoping/initial populations/bounds/causal states/rewards/Q terminal replay')
(run_dir/'independent_artifact_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
