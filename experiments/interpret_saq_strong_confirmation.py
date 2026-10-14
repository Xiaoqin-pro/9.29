"""Attach grounded, explicitly scoped interpretation to the strong comparison."""
from pathlib import Path
import json
import pandas as pd
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results/saq_strong_confirmation_29f_10seed_20261014'
means=pd.read_csv(OUT/'function_means.csv',index_col=0)
phase=pd.read_csv(OUT/'phase_gap_diagnosis.csv').set_index('FunctionID')
summary=pd.read_csv(OUT/'overall_comparisons.csv')
raw=pd.read_csv(OUT/'all_runs.csv')
old=ROOT/'results/saq_sparse_framework_ablation_30seed_20261013/function_comparison.csv'
history=pd.read_csv(old);history=history[history.Contrast.eq('C2') & history.FunctionID.isin([6,9,27])].copy()
history['Cohort']='Historical 30-seed ablation, separate from the current 10-seed confirmation'
history['Source']=str(old)
history.to_csv(OUT/'historical_geometry_failure_evidence.csv',index=False)
dev=[1,6,9,13,21,22,27,30];rows=[]
for name,ids in [('EightDevelopmentFunctions',dev),('Other21Functions',[f for f in means.index if f not in dev])]:
    d=means.loc[ids,'ELS-Q']-means.loc[ids,'ELS-Replace']
    rows.append({'Subset':name,'Functions':len(ids),'QMeanWinsVsRule':int((d<0).sum()),'QMeanLossesVsRule':int((d>0).sum()),'Ties':int((d==0).sum())})
pd.DataFrame(rows).to_csv(OUT/'development_vs_other_functions.csv',index=False)
q=raw[raw.Method.eq('ELS-Q')];rule=raw[raw.Method.eq('ELS-Replace')]
usage={'QProbeEvaluations':int(q.ProbeEvaluations.sum()),'QOptimizationCalls':int(q.ObjectiveCalls.sum()),
 'QProbeFraction':float(q.ProbeEvaluations.sum()/q.ObjectiveCalls.sum()),
 'RuleProbeEvaluations':int(rule.ProbeEvaluations.sum()),'RuleOptimizationCalls':int(rule.ObjectiveCalls.sum()),
 'RuleProbeFraction':float(rule.ProbeEvaluations.sum()/rule.ObjectiveCalls.sum())}
(OUT/'probe_budget_usage.json').write_text(json.dumps(usage,indent=2),encoding='utf-8')
lines=['# 强对照之后的诊断与下一步（2026-10-14）','',
 '**当前判断：精英探测与真实替换值得保留为研究组件；当前Q调度尚不适合冻结为最终版本。下一轮优先修稀疏评价的覆盖偏差，并验证Q能否调度更有实际影响的评价配额。**','',
 '## 已完成的比较','',
 '29函数（F1/F3–F30）、D50、100k真实评价、10种子3001–3010。新Q/规则580次全新运行；其余六方法1740次在源码、初始化、预算和当前CEC目标复核后复用。缓存复查77140次目标调用单独计数。',
 '所有新增运行的实际FE、边界、最终档案、真实fitness、pbest和探测写回检查通过。全部负面结果保留。','',
 '## 当前Q调度的稳定性','',
 '- 开发阶段8101–8110的8函数，Q相对规则均值6胜2负。',
 '- 换到3001–3010，相同8函数变为2胜6负；其余21函数为7胜14负，总计9胜20负。',
 '- 因此变化同时涉及种子与函数范围，不能把开发子集的优势直接推广。',
 '- 新Q相对原冻结SAQ-CSO为19胜10负；相对HIDMS/HCLPSO均为4胜25负，相对DMS为7胜22负。',
 '- 新规则版平均秩4.724，新Q为5.172，原冻结版5.897；HIDMS/DMS/HCLPSO为2.345/2.862/3.069。','',
 '## 差距所在阶段','',
 '| 函数 | 20k对照误差比 | 60k对照误差比 | 100k对照误差比 | 新Q最后20k降幅 | 需要检验的问题 |','|---|---:|---:|---:|---:|---|']
notes={1:'中期开发慢，后期仍强烈改善；统一重启会干扰有效追赶',6:'持续改善但精修效率落后，评价分配与局部搜索都需检查',
 9:'20k已落后，差距在中期急剧扩大；早期覆盖和盆地进入值得优先查',
 5:'先领先后落后，尾段进展很小，具有过早集中迹象',8:'先领先后落后，尾段进展很小，需检查覆盖和盆地',
 13:'新组件大幅优于原冻结版，但强者在20k前已找到更好的区域',22:'早期已落后且尾段进展小，单纯晚期恢复不足以解释差距'}
for fid in [1,6,9,5,8,13,22]:
    r=phase.loc[fid]
    lines.append(f"| F{fid} | {r.Ratio20k:.3g} | {r.Ratio60k:.3g} | {r.Ratio100k:.3g} | {r.QTail20kRelativeDrop:.2%} | {notes[fid]} |")
lines+=['','对照是各函数最终均值最好的五个PSO之一，属于事后描述选择；曲线本身不能证明严格局部最优或唯一原因。','',
 '## 现成消融指向的覆盖问题','',
 '原30种子C2只改变筛选，固定10FE/轮、6T/4S、cap2和同搜索公式。几何筛选在26函数均值更好，但F6/F9/F27显著更差。','',
 '| 历史函数 | 几何筛选均值 | 随机筛选均值 | Holm全族P |','|---|---:|---:|---:|']
for r in history.itertuples():lines.append(f'| F{r.FunctionID} | {r.LeftMean:.5g} | {r.RightMean:.5g} | {r.HolmAll:.5g} |')
lines+=['','这组历史30种子证据与本轮10种子不混成一张性能表；它支持筛选策略存在函数依赖性，不能据此断言唯一原因就是父代覆盖。','',
 '## Q动作的实际影响与反馈','',
 f"新Q总探测{usage['QProbeEvaluations']:,}次，占{usage['QOptimizationCalls']:,}次优化调用的{usage['QProbeFraction']:.3%}；规则版为{usage['RuleProbeFraction']:.3%}。当前动作每100FE最多改变1个名额，直接改变的评价份额很小；对后续轨迹的影响另行分析。",
 'mode_gain_diagnostics.csv按固定评价顺序还原Tracing/Seeking/探测的直接全局更新，delayed_credit_diagnostics.csv记录当前负反馈但后500/1000FE出现改善的窗口。后续改善包含其他搜索动作，不能全部归给某次探测。',
 '例如F6尾段，新Q的Tracing直接全局更新率约0.049%，Seeking约0.457%，精英探测约7.35%。频率不等价最终收益，但说明固定配额和短窗口反馈值得单独检验。','',
 '## 下一轮建议：一个主问题、逐项验证','',
 '1. 先复查现有FreshQ/FCS等历史实现，再做覆盖策略的单因素对照：当前几何筛选与保留少量随机/轮换覆盖名额。保持候选公式、半径、总FE、原有真记忆规则一致，分离策略与搜索随机流。',
 '2. 覆盖验证有效后，让Q选择几何利用和覆盖探索的评价配额。保持一个控制器和很少的动作，不同时引入新的搜索算子。精英探测继续作为已验证候选组件，是否保留由对照决定。',
 '3. 根据模式和延迟日志检查100FE反馈及奖励尺度。可以对照原冻结版的+10/−1设定；先声明参数和开发集合，再运行，不按函数分别设置。',
 '4. 若F1/F6仍持续被强者拉开，再针对Tracing的精修能力做一个独立改动；这样能分清评价覆盖和搜索本身各自的作用。',
 '本报告提出下一轮验证，不宣称这些修改已经成功。当前确认过程使用固定开发版参数，未在这29函数运行中改动。','',
 '## 统计范围','',
 '10种子用于定位趋势。逐函数Q对7对照共203个检验采用全局Holm；当前最小P约0.001953，而首项阈值约0.000246，不能用本轮“未显著”推导等效。最终投稿显著性需更充分种子数。',
 '没有通过缩小检验族或省略负面函数制造显著优势。总体平均秩与逐函数胜负均是同一2320行数据的描述。','',
 '## 文件','',
 '- REPORT.md：完整对照统计；mean_std_zh.csv：逐函数均值±标准差。',
 '- all29_convergence.pdf：全部29函数；function_curves/：逐函数PNG/PDF。',
 '- largest_gaps.png：最大差距8函数；phase_gap_diagnosis.csv：阶段差距。',
 '- historical_geometry_failure_evidence.csv：独立历史覆盖证据。']
(OUT/'DIAGNOSIS_AND_NEXT_STEP.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Saved detailed diagnosis and next-step contract.')
