from pathlib import Path
import argparse,json,hashlib,shutil
import pandas as pd
from verify_saq_sparse_ablation import validate
from report_matched_comparisons import report
p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
raw,curves,checks=validate(a.run_dir,a.out,complete=True);assert checks['QualityRecords']==5220 and checks['NewOptimizationRecords']==4350 and checks['CachedFullRecords']==870
methods=['FullEval-CSO','RandomSparse-Fixed6','SpatialSparse-Fixed4','SpatialSparse-Fixed6','SpatialSparse-RandomQuota','SAQ-CSO']
contrasts=[('C1','SpatialSparse-Fixed6','FullEval-CSO','PrimarySparseFramework'),('C2','SpatialSparse-Fixed6','RandomSparse-Fixed6','PrimaryGeometry'),('Q1','SAQ-CSO','SpatialSparse-Fixed4','SecondaryOriginalFixedQuota'),('Q2','SAQ-CSO','SpatialSparse-Fixed6','SecondaryStrongFixedQuota'),('Q3','SAQ-CSO','SpatialSparse-RandomQuota','SecondaryNonLearningQuota')]
notes=['主要证据是无Q的FullEval→RandomSparse→SpatialSparse链；固定6的筛选对照才隔离geometry。Dense父代cap4及完整轮成本变化属于删除稀疏框架的自然包差异，不能全部归空间排序。', 'Q仅作3项辅助控制。若不胜Fixed6/RandomQuota，主文应限制Q新增收益描述，不通过省略强固定或随机控制声称必要性。没有奖励/状态/学习率调参。', '所有六条件搜索公式、初始化、N50、MR.4、预算进度一致；Dense无虚假fitness，全部新候选真实评价；RandomSparse仅变筛选，cap2/配额6同Fixed6。', 'Full870使用冻结主结果缓存，独立p0/T/Q核验；本轮新4350run，不称5220新优化。实评及额外审计调用分列。', '30seed3001–3030，D50/100k。所有29函数纳入；末轮预算截断。本文主对照五算法范围已固定，不增加外部方法。']
report(raw,a.out,methods,contrasts,'稀疏评价框架六版本消融（2026-10-13）',notes,curves)
metrics=raw.groupby('Condition').agg(MeanRounds=('Rounds','mean'),MeanCandidatePoints=('CandidatePointsGenerated','mean'),MeanEvaluationFraction=('RealEvaluationFraction','mean'),MeanRoundCost=('MeanRoundCost','mean'),MeanSeconds=('Seconds','mean'),MeanQUpdates=('QUpdates','mean'),MeanGateFraction=('GateFraction','mean')).reindex(methods)
metrics.to_csv(a.out/'framework_efficiency.csv');raw[['FunctionID','Seed','Condition','Rounds','CandidatePointsGenerated','RealEvaluationFraction','MeanRoundCost','QUpdates','GateFraction','Action1Share','Action2Share','Action3Share']].to_csv(a.out/'mechanism_runs.csv',index=False)
for f in ['preflight.json']:
 shutil.copy2(a.run_dir/'source_snapshot'/f,a.out/('ablation_'+f))
source=[]
for f in sorted((a.run_dir/'source_snapshot').rglob('*')):
 if f.is_file():source.append({'File':str(f.relative_to(a.run_dir/'source_snapshot')),'SHA256':hashlib.sha256(f.read_bytes()).hexdigest()})
(a.out/'source_manifest.json').write_text(json.dumps({'RunDirectory':str(a.run_dir.resolve()),'Files':source,'NewRuns':4350,'CachedFullRuns':870},ensure_ascii=False,indent=2),encoding='utf-8')
print(metrics.to_string())
