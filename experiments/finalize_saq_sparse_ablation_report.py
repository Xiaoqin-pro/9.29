"""Supplement final frozen ablation report with contrast plots and conclusions."""
from pathlib import Path
import json,shutil,hashlib
import pandas as pd,numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];out=root/'results/saq_sparse_framework_ablation_30seed_20261013';run=root/'results/cec/saq_sparse_ablation_30seed_study_20261013_133122'
r=json.loads((out/'overall.json').read_text(encoding='utf-8'));v=json.loads((out/'independent_matlab_recheck.json').read_text());checks=json.loads((out/'independent_artifact_checks.json').read_text());assert v['Passed'] and checks['Passed'] and v['MaxBestDifference']==0 and v['QualityRecords']==5220
summary=pd.read_csv(out/'summary.csv');tests=pd.read_csv(out/'function_comparison.csv');eff=pd.read_csv(out/'framework_efficiency.csv',index_col=0)
ratios=tests[['Contrast','Role','FunctionID','Left','Right','LeftMean','RightMean']].copy();ratios['MeanErrorRatio']=ratios.LeftMean/ratios.RightMean;ratios.to_csv(out/'contrast_error_ratios.csv',index=False)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9})
fig,axes=plt.subplots(3,1,figsize=(11,10),sharex=True)
colors={'C1':'#2176a3','C2':'#41853d','Q1':'#aa783a','Q2':'#b04a65','Q3':'#7b68a4'}
for ax,group,title in zip(axes,[['C1'],['C2'],['Q1','Q2','Q3']],['Sparse Fixed6 / Full evaluation (no Q on both sides)','Spatial Fixed6 / RandomSparse Fixed6 (matched sparse budget)','Q vs fixed and random quota controls']):
 for cid in group:
  z=ratios[ratios.Contrast==cid];label={'C1':'C1: Sparse / FullEval','C2':'C2: Spatial / Random selection','Q1':'Q / Fixed4','Q2':'Q / Fixed6','Q3':'Q / RandomQuota'}[cid]
  ax.plot(np.arange(29),np.log10(z.MeanErrorRatio),'o-',ms=3,lw=1.15,label=label,color=colors[cid])
 ax.axhline(0,color='black',lw=.7);ax.grid(alpha=.2);ax.set_title(title);ax.set_ylabel('log10(left mean error / right)');ax.legend(fontsize=8)
axes[-1].set_xticks(range(29));axes[-1].set_xticklabels([f'F{x}' for x in ratios[ratios.Contrast=='C1'].FunctionID]);fig.tight_layout();fig.savefig(out/'ablation_contrast_ratios.png',dpi=180);plt.close(fig)
core=['FullEval-CSO','RandomSparse-Fixed6','SpatialSparse-Fixed6'];fig,axes=plt.subplots(1,2,figsize=(10,4))
axes[0].bar(range(3),eff.loc[core,'MeanRounds'],color=['#999999','#bb853f','#2176a3']);axes[0].set_ylabel('Mean search rounds at 100k true FE')
axes[1].bar(range(3),100*eff.loc[core,'MeanEvaluationFraction'],color=['#999999','#bb853f','#2176a3']);axes[1].set_ylabel('Evaluated / generated candidates (%)')
for ax in axes:
 ax.set_xticks(range(3));ax.set_xticklabels(['FullEval','RandomSparse','SpatialSparse']);ax.grid(axis='y',alpha=.2)
fig.tight_layout();fig.savefig(out/'framework_rounds_and_evaluation_fraction.png',dpi=180);plt.close(fig)
summary_ratios=[]
for cid,z in ratios.groupby('Contrast',sort=False):summary_ratios.append({'Contrast':cid,'MedianFunctionMeanErrorRatio':float(z.MeanErrorRatio.median()),'GeometricMeanFunctionErrorRatio':float(np.exp(np.log(z.MeanErrorRatio).mean()))})
pd.DataFrame(summary_ratios).to_csv(out/'contrast_ratio_summary.csv',index=False)
for name in ['environment.json','COMPLETED.json','progress.json','job_manifest.csv']:
 shutil.copy2(run/name,out/('run_'+name))
accepted={'Complete':True,'QualityRecords':5220,'NewRuns':4350,'CachedFullRuns':870,'Passed':True,'ObjectiveAuditCallsOutsideBudget':5220,'MaxBestDifference':0,'ResultDirectory':str(out),'SourceDirectory':str(run)}
(out/'ACCEPTED.json').write_text(json.dumps(accepted,ensure_ascii=False,indent=2),encoding='utf-8')
report=out/'REPORT.md';s=report.read_text(encoding='utf-8');s+='''

## 已完成结果与可写结论

- 主框架C1：SpatialSparse-Fixed6对FullEval均值24胜5负，654/216配对seed；145族Holm后13显著好、0显著差、16未显著。中位函数均值误差比0.876（描述性跨函数比值）。双方无Q，同搜索骨架，支持这一D50/100k场景下稀疏框架整体价值。
- 空间筛选C2：对RandomSparse-Fixed6均值26胜3负，601/269配对seed；9显著好、3显著差、17未显著。三个更差函数F6/F9/F27全部如实保留。相同10FE/轮、6T4S、cap2及虚拟/锚点规则，支持geometry相对于随机选择的总体收益，不能说每函数均优。
- Q辅助：Full对Fixed4均值17:12、对Fixed6为18:11、对RandomQuota13:16；三组145族Holm均无显著函数。RandomQuota平均排名2.483，Full2.621。数据没有证明学习替代随机选择的必要性；未显著也不证明等效。保持Q为主算法辅助调度可描述，但不把整体收益归Q或隐去RandomQuota。

## 资源/运行时边界

全评价平均714.4轮，每轮约139.9次实评；稀疏版9995轮，每完整轮10次实评，约为全评价轮数的14倍。稀疏实评占所生成新候选约7.14%，这是候选评价比例，不是“评价20%的粒子”。算法各自总FE都100k，不能把此比例说成整次运行减少92.86%总FE。

FullEval平均2.305秒，空间Fixed6为8.345秒，完整SAQ为9.082秒（SAQ取此前批次缓存，不严格归因时间差）。稀疏框架在廉价CEC上没有CPU速度优势，收益是同真实FE预算下的质量及更多搜索轮次。候选生成/几何排序仍耗时，不声称同FE更快。

## 完整验收与数据范围

5220份MAT/CSV/FE/每轮计数/状态奖励/终端Q记录独立核验通过；870份缓存Full的轨迹与Q精确匹配。另一个MATLAB进程重评5220个best，最大差0，按seed重建5220个初始种群也全部匹配。增加5220次审计objective调用单列，不算各优化run的100k预算。

新优化4350、缓存870；全部29函数×30seed保留。完整MAT与source_snapshot在本地results/cec保留，发布逐seedCSV、mean/std、机制计数、预定比较、图和核验记录。主性能五算法表与本六版本消融是不同comparison family，平均排名不能混用。

此批不增加新机制、没有再调Q超参数。下一研究决策应基于上述范围，稀疏框架是当前最强结论；三维无人机应用尚未作为本结果证据。
''';report.write_text(s,encoding='utf-8')
t='''# 稀疏框架消融最终结果（2026-10-13）

D50、100k真实FE、CEC2017 F1/F3–F30、30seed3001–3030、N50。六版本5220份有效记录（新4350+缓存Full870），无失败；不删不利函数、不修改搜索机制。

|预定比较（左vs右）|均值胜/负|145项Holm显著优/劣/NS|
|---|---:|---:|
'''
for z in r['Contrasts']:t+=f"|{z['Left']} vs {z['Right']}|{z['MeanWins']}/{z['MeanLosses']}|{z['HolmBetter']}/{z['HolmWorse']}/{z['HolmNS']}|\n"
t+='''
## 主要结论

1. 稀疏评价框架：无Q的SpatialFixed6胜FullEval24:5、显著13/0/16，支持同骨架有限评价资源下的整体价值。全评价完整轮评全部1Ttrial及4Snewcandidates，cap和轮成本变化属删除框架的自然整体差异；不能单归geometry。
2. 空间筛选：同10FE/6T4S/cap2/虚拟锚点下，SpatialFixed6胜RandomSparse26:3、显著9/3/17。F6/F9/F27更差是边界，不宣称万能筛选。
3. Q仅有轻微均值变化，Full不胜RandomQuota总体；RandomQuota平均排名2.483、Full2.621、Fixed6 2.966、Fixed4 3.103、FullEval4.862、RandomSparse4.966。所有Q比较Holm后无显著函数；无法声称学到比随机不可替代的收益，也不能把未显著写成等效。

## 机制与性能边界

- FullEval平均714.4轮，稀疏9995轮。每个稀疏完整轮10trueFE；全评价约139.9FE/轮。
- 稀疏真实评价/新生成候选约7.14%。不是评价20%粒子，也不是全run目标总调用少于100k。
- FullEval平均2.305秒，SpatialFixed6约8.345，Full约9.082（缓存先前批次）。不支持同FE CPU更快，论文讲有限真实评价资源效率和质量，不把CPU额外开销藏掉。

## 核验

5220MAT完整独立检查，870缓存逐轨迹和Q精确匹配；所有best另进程重评最大差0；5220种群按seed重新生成均匹配。新优化4350/435M实际FE；缓存870/87M先前FE；独立best审计新增5220次单列，不冒称新5220优化。

完整结果：results/saq_sparse_framework_ablation_30seed_20261013/REPORT.md。五算法主比较另在results/saq_cso_main_five_30seed_20261013，不混不同平均rank或统计校正family。

本批只统计和发布，不执行新参数开发或无人机实验。
'''
(root/'docs/SAQ_SPARSE_ABLATION_RESULTS_20261013.md').write_text(t,encoding='utf-8')
print('Supplemental plots, final evidence summary and ACCEPTED.json written')
