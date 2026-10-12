"""Recompute stored V4.1 mode-control comparisons; no optimization is run."""
import json
from pathlib import Path
import pandas as pd

root = Path(__file__).resolve().parents[1]
sources = [
    'results/cec/cec2017_v41_fixed_mr_20261008_112746/raw_runs.csv',
    'results/cec/cec2017_v41_state_ablation_20261008_110725/raw_runs.csv',
    'results/cec/cec2017_v41_baseline_norecovery_20261008_105500/raw_runs.csv',
]
snapshots = root / 'results/cso_reassessment_20261012/source_snapshots'
fixed, q, rnd = [pd.read_csv(snapshots / p) for p in ['legacy_fixed_mr_raw.csv', 'legacy_state_ablation_raw.csv', 'legacy_no_recovery_raw.csv']]
q = q[q.Algorithm == 'V4.1-Q-9State-NoRecovery']
rows = []
for alg, df in list(fixed.groupby('Algorithm')) + list(rnd.groupby('Algorithm')):
    m = q.merge(df, on=['FunctionID', 'Run', 'InitSeed', 'SearchSeed', 'Evaluations'], suffixes=('_q', '_c'), validate='one_to_one')
    assert len(m) == 18
    qm = m.groupby('FunctionID').BestError_q.mean()
    cm = m.groupby('FunctionID').BestError_c.mean()
    rows.append(dict(Control=alg, Pairs=len(m), QFunctionWins=int((qm<cm).sum()), ControlFunctionWins=int((qm>cm).sum()), QSeedWins=int((m.BestError_q<m.BestError_c).sum()), ControlSeedWins=int((m.BestError_q>m.BestError_c).sum())))
out = root / 'results/cso_reassessment_20261012'
out.mkdir(exist_ok=True)
pd.DataFrame(rows).to_csv(out / 'legacy_mode_q_comparison.csv', index=False)
means = fixed.groupby(['FunctionID', 'Algorithm']).BestError.mean().unstack()
means['BestFixedByFunction'] = means.idxmin(axis=1)
means.to_csv(out / 'legacy_fixed_mr_function_means.csv')
(out / 'source_note.json').write_text(json.dumps(dict(analysis='Historical stored observations; no new optimization runs; means and raw paired comparisons, not significance tests. Old latest source is not an immutable run snapshot; archived results are not new mechanism verification. MR changes both candidate-mode populations and true-FE quota in old V4.1.', source_raw=sources), ensure_ascii=False, indent=2), encoding='utf-8')
quota = pd.read_csv(snapshots / 'legacy_quota_raw.csv')
quota_means = quota.groupby(['FunctionID', 'Algorithm']).BestError.mean().unstack()
quota_means['BestFixedByFunction'] = quota_means.idxmin(axis=1)
quota_means.to_csv(out / 'legacy_quota_function_means.csv')
print(pd.DataFrame(rows).to_string(index=False))
print('Fixed-quota best function counts:', quota_means.BestFixedByFunction.value_counts().to_dict())
