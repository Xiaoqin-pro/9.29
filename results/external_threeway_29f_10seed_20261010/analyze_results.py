"""Analyze saved endpoints only; never launches an optimizer or modifies raw CSVs."""
from pathlib import Path
import hashlib
import json
from itertools import product

import numpy as np
import pandas as pd
from scipy.stats import wilcoxon

ROOT = Path(__file__).resolve().parent
METHODS = ['ASE-CSO', 'CLPSO', 'NRLPSO']
FUNCTIONS = [1, *range(3, 31)]
SEEDS = list(range(101, 111))
raw = pd.read_csv(ROOT / 'raw_runs.csv')
expected = set(product(METHODS, FUNCTIONS, SEEDS))
actual = set(raw[['method', 'function_id', 'seed']].itertuples(index=False, name=None))
audit = {
    'expected_rows': 870, 'actual_rows': len(raw),
    'duplicate_keys': int(raw.duplicated(['method', 'function_id', 'seed']).sum()),
    'missing_keys': sorted(expected - actual), 'unexpected_keys': sorted(actual - expected),
    'status_counts': raw.status.value_counts().to_dict(),
    'reported_FE_counts': {str(k): int(v) for k, v in raw.evaluations.value_counts().items()},
    'all_endpoints_finite': bool(np.isfinite(raw.final_cost).all()),
    'dimension': 30, 'budget': 60000, 'workers': 4, 'seeds': SEEDS,
    'reported_FE_not_independently_instrumented': True,
    'convergence_saved': False, 'initial_populations_saved': False,
    'nrlpso_baseline_validated': False,
    'nrlpso_label': 'unvalidated_MATLAB_adaptation_N50_k5',
    'RLAM_included': False,
    'metabox_source_commit': '5565a281ce4e03efc1f6a41230507d5b66637ace',
    'source_snapshot_time': 'post_run',
}
if len(raw) != 870 or audit['duplicate_keys'] or expected != actual:
    raise ValueError('Incomplete or duplicated run grid')
if not (raw.status.eq('ok').all() and raw.evaluations.eq(60000).all()
        and audit['all_endpoints_finite']):
    raise ValueError('Invalid run status, reported FE, or endpoint')

# Raw CSV stores f(x), not error. Bias removal does not change within-function ranks.
raw['final_error'] = raw.final_cost - 100 * raw.function_id
raw['baseline_scope'] = np.where(raw.method.eq('NRLPSO'),
    'unvalidated_adapter_exploratory_only', 'frozen_repository_implementation')
raw.to_csv(ROOT / 'raw_runs_with_errors.csv', index=False)
summary = raw.groupby(['method', 'function_id'], sort=False).agg(
    mean_error=('final_error', 'mean'), median_error=('final_error', 'median'),
    std_error=('final_error', 'std'), min_error=('final_error', 'min'),
    max_error=('final_error', 'max'), mean_seconds=('seconds', 'mean'),
    n=('final_error', 'size')).reset_index()
summary.to_csv(ROOT / 'summary_errors.csv', index=False)
pairs = raw.pivot(index=['function_id', 'seed'], columns='method', values='final_error')
means = pairs.groupby(level='function_id').mean()
comparisons, detailed = [], []
for a, b in [('ASE-CSO', 'CLPSO'), ('ASE-CSO', 'NRLPSO'), ('NRLPSO', 'CLPSO')]:
    scope = 'repository_comparison' if b == 'CLPSO' and a == 'ASE-CSO' else 'exploratory_adapter_only'
    comparisons.append(dict(method_a=a, method_b=b, scope=scope,
        function_mean_wins=int((means[a] < means[b]).sum()),
        function_mean_losses=int((means[a] > means[b]).sum()),
        function_mean_ties=int((means[a] == means[b]).sum()),
        paired_wins=int((pairs[a] < pairs[b]).sum()),
        paired_losses=int((pairs[a] > pairs[b]).sum()),
        paired_ties=int((pairs[a] == pairs[b]).sum())))
    for fid in FUNCTIONS:
        x, y = pairs.loc[fid, a], pairs.loc[fid, b]
        detailed.append(dict(method_a=a, method_b=b, scope=scope, function_id=fid,
            mean_a=means.loc[fid, a], mean_b=means.loc[fid, b],
            relative_mean_improvement_a=(means.loc[fid, b] - means.loc[fid, a]) / max(abs(means.loc[fid, b]), 1e-12),
            paired_wins=int((x < y).sum()), paired_losses=int((x > y).sum()),
            paired_ties=int((x == y).sum())))
pd.DataFrame(comparisons).to_csv(ROOT / 'pairwise_summary.csv', index=False)
pd.DataFrame(detailed).to_csv(ROOT / 'comparison.csv', index=False)

# Inference is limited to the frozen local ASE-CSO/CLPSO implementations.
stats = []
for fid in FUNCTIONS:
    diff = (pairs.loc[fid, 'ASE-CSO'] - pairs.loc[fid, 'CLPSO']).to_numpy()
    pvalue = 1.0 if np.all(diff == 0) else float(wilcoxon(diff, alternative='two-sided', method='auto').pvalue)
    stats.append(dict(function_id=fid, p_two_sided=pvalue))
order = sorted(range(len(stats)), key=lambda i: stats[i]['p_two_sided'])
running = 0.0
for rank, i in enumerate(order):
    running = max(running, min(1.0, (len(stats) - rank) * stats[i]['p_two_sided']))
    stats[i]['p_holm_29'] = running
    stats[i]['significant_holm_005'] = running < 0.05
pd.DataFrame(stats).to_csv(ROOT / 'ase_clpso_paired_statistics.csv', index=False)
audit['ase_clpso_significant_functions_after_Holm'] = sum(x['significant_holm_005'] for x in stats)
audit['mean_seconds'] = {str(k): float(v) for k, v in raw.groupby('method').seconds.mean().items()}
audit['files_sha256'] = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
    for p in [ROOT / 'raw_runs.csv', ROOT / 'raw_runs_typed.csv', ROOT / 'summary.csv',
              ROOT / 'analyze_results.py', *sorted((ROOT / 'source_snapshot').glob('*.m'))]}
(ROOT / 'audit_manifest.json').write_text(json.dumps(audit, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

columns = ['ASE-CSO', 'CLPSO', 'NRLPSO']
table = ['| 函数 | ASE-CSO 平均误差 | CLPSO 平均误差 | 未校验 NRLPSO 适配版平均误差 |',
         '|---|---:|---:|---:|']
for fid in FUNCTIONS:
    table.append('| F{} | {} |'.format(fid, ' | '.join(f'{means.loc[fid,m]:.6g}' for m in columns)))
(ROOT / 'mean_error_table.md').write_text('\n'.join(table) + '\n', encoding='utf-8')
print(json.dumps({'audit_passed_for_record_grid': True, 'comparisons': comparisons,
                  'mean_seconds': audit['mean_seconds'],
                  'holm_significant_functions': audit['ase_clpso_significant_functions_after_Holm']}, indent=2))
