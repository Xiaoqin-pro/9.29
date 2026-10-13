from pathlib import Path
import hashlib,json
import pandas as pd
from report_matched_comparisons import report
root=Path(__file__).resolve().parents[1];prior=root/'results/saq_cso_eightway_30seed_20261013';out=root/'results/saq_cso_main_five_30seed_20261013'
methods=['SAQ-CSO','Original-CSO-MR02','CLPSO-AuthorSource','HPSO-TVAC-CEC','SPSO-2011-OfficialC']
raw=pd.read_csv(prior/'all_quality_runs.csv');raw=raw[raw.Condition.isin(methods)].copy();assert len(raw)==4350
verified=json.loads((prior/'independent_artifact_checks.json').read_text());best=json.loads((prior/'independent_matlab_recheck.json').read_text());assert verified['Passed'] and best['Passed']
curves=pd.read_csv(prior/'convergence_nodes.csv')
contrasts=[(f'M{i}','SAQ-CSO',c,'MainComparator') for i,c in enumerate(methods[1:],1)]
notes=['主性能集合为用户在八算法完整比较后指定的五算法子集；不是未看结果前选择的全基线清单。该集合平均排名第一不代表优于所有PSO或SOTA。', '较强HCLPSO/HIDMS/DMS结果仍公开留在八算法归档，正文应给范围说明或补充入口；没有删除原数据。', '同D50/100k；SPSO40粒子，其余50，共享种群前缀。SPSO原生C控制器，时间不同批次且不同实现，不作机制归因。', '五方法4×29=116检验族Holm重算，不沿用八算法203族的票数；此次仅分析缓存，无新增优化。', '完整算法不改；稀疏框架和Q收益由新的同骨架消融检验。']
report(raw,out,methods,contrasts,'最终五算法主性能比较（2026-10-13）',notes,curves)
files=['all_quality_runs.csv','independent_artifact_checks.json','independent_matlab_recheck.json','source_manifest.json']
(out/'source_analysis_provenance.json').write_text(json.dumps({'PriorRelease':str(prior),'InputHashes':[{'File':f,'SHA256':hashlib.sha256((prior/f).read_bytes()).hexdigest()} for f in files],'NewOptimizationRuns':0,'UsesPriorIndependentMATChecks':True},indent=2),encoding='utf-8')
