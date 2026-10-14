"""Descriptive diagnosis of the completed four-operator pilot."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.io import loadmat
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'results/saq_four_operator_10seed_20261014'
cfg=json.loads((out/'config.json').read_text(encoding='utf8'))
run=ROOT/'results/cec'/Path((ROOT/'work/saq_four_operator_latest.txt').read_text(encoding='utf8').strip()).name
assert json.loads((run/'config.json').read_text(encoding='utf8'))['Seeds']==cfg['Seeds']
raw=pd.read_csv(out/'all_runs.csv');records=[]
for row in raw[raw.Method.eq('FO-Q')].itertuples():
 I=loadmat(run/'runs'/row.Artifact,simplify_cells=True)['info'];e=np.atleast_2d(I['EscapeLog'])
 for action in [2,3,4]:
  z=e[e[:,3]==action]
  records.append(dict(FunctionID=row.FunctionID,Seed=row.Seed,Action=action,Evaluations=len(z),
                      WorseThanCurrentParent=int((z[:,5]>=z[:,6]).sum()),ParentImprovement=int(z[:,8].sum()),GlobalImprovement=int(z[:,9].sum())))
a=pd.DataFrame(records);a.to_csv(out/'alternative_acceptance_diagnosis.csv',index=False)
curves=pd.read_csv(out/'convergence_nodes.csv');means=curves.groupby(['FunctionID','Method','FE']).BestError.mean();gap=[]
for fid in cfg['FunctionIDs']:
 row={'FunctionID':fid}
 for fe in [10000,20000,40000,60000,80000,100000]:row[f'QOverBase{fe}']=means.loc[(fid,'FO-Q',fe)]/means.loc[(fid,'FO-Base',fe)]
 gap.append(row)
gap=pd.DataFrame(gap);gap.to_csv(out/'q_stage_gap.csv',index=False)
runtime=raw.groupby('Method').agg(Runs=('Seconds','size'),MeanAlgorithmSeconds=('Seconds','mean'),MaxAlgorithmSeconds=('Seconds','max'),OptimizationCalls=('ObjectiveCalls','sum'),AuditCalls=('PostRunRecheckCalls','sum'))
runtime.to_csv(out/'runtime_summary.csv')
report="""# 四算子失败诊断

开发门未通过。所有320条状态、奖励和Q更新核验通过，因此目前没有证据把失败归因于Q实现错误。

1. Q相对base在F1/F13/F22均值更好，F6/F9/F21/F27/F30更差。F9的差距在10k即出现并不断扩大；F21前期领先后被超过。不能将两者都写成单纯后期局部最优。
2. Q替代候选实评中，同伴517800点/父代改善7634，高斯1466822点/父代改善200966，反向571780点/父代改善716。这里是既定在线策略下的描述，不是随机化动作因果比较。
3. 老师第6页Algorithm1先更新X/V，pbest/global只在实评改善时更新，新X没有因不改善而回退。本次FO继续贪心Seeking，反向候选多数不改善，无法留下不同搜索起点。此差异提供位置保留候选的实现依据，但尚未证明是整体失败的唯一原因。
4. Q的窗奖励由所有Tracing/Seeking改进产生，不能将窗口奖励全部归因于Seeking动作；尤其高斯的频繁即时改善不代表最终误差更好。没有从这一现象直接推导一个复杂的新奖励。
5. 对比老师，FO还存在Seeking而非全群体调度、部分坐标算子、100FE决策而非逐代、有效改善判定等适配差异。此版本借鉴其分工，不是原论文逐项复现。

下一步单独记录在docs/SAQ_FOUR_MOTION_PROTOCOL_20261014.md：固定四动作和状态，仅验证探索新位置保留及高斯/反向的速度处理。若机制失败，不追加该版Q调度。

运行时间：本批约43分钟。单次常规9.6秒、Q23.2秒、随机23.8秒、规则30.6秒；4版本批内等待最慢版，80批算法时间约40.8分钟。额外核验7279792调用（相对32M优化约22.75%），耗时表的Seconds只计算法、不包含核验。候选生成与重复数据整理是主要慢点；尚未运行逐行profiling，不宣称具体函数的耗时占比。
"""
(out/'DIAGNOSIS.md').write_text(report,encoding='utf8')
print(runtime.round(2).to_string());print(gap.round(3).to_string(index=False))
