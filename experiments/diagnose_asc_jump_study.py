"""Describe the completed Jump pilot without modifying the declared gate."""
from pathlib import Path
import pandas as pd,json
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'results/asc_jump_study_10seed_20261015'
m=pd.read_csv(out/'function_means.csv').set_index('FunctionID');med=pd.read_csv(out/'function_medians.csv').set_index('FunctionID')
c=pd.read_csv(out/'comparisons.csv');d=pd.read_csv(out/'function_comparisons.csv');metrics=pd.read_csv(out/'run_diagnostics.csv');cfg=json.loads((out/'config.json').read_text(encoding='utf8'))
x=c[(c.Method=='LightJump')&(c.Reference=='Original')].iloc[0];y=c[(c.Method=='NoJump')&(c.Reference=='Original')].iloc[0]
ratio=m.LightJump/m.Original;f9=d[(d.Method=='LightJump')&(d.Reference=='Original')&(d.FunctionID==9)].iloc[0]
counts=metrics.groupby('Method')[['Jumps','PositionResetsFromCode','PositionResetsWithRemainingBudget']].mean()
sig=d[(d.Holm24<.05)]
lines=['# ASC Jump实验：诊断与决策','',
'本轮仅修改原文件已有的useJump和jumpFraction，未改筛选、更新方程、半径和概率控制。所有条件共享其余参数、种子与初始化；Jump后随机流消耗自然分化。',
'', '## 结果','',
f'轻量Jump对原版：{int(x.MeanWins)}胜{int(x.MeanLosses)}负，中位函数均值误差比{x.MedianMeanRatio:.4f}，配对种子{int(x.SeedWins)}胜{int(x.SeedLosses)}负。关闭Jump对原版{int(y.MeanWins)}胜{int(y.MeanLosses)}负。轻量版对关闭版8函数均值更好，但不将均值票数称为显著性。',
'', '| 函数 | 轻量Jump相对原版的均值变化 |','|---:|---:|']
for fid in m.index:lines.append(f'| F{fid} | {(ratio.loc[fid]-1)*100:+.2f}% |')
lines+=['','负值代表误差减少，正值代表恶化。',
'', '## F9不是一个极端样本就能解释','',
f'F9轻量版在10个配对种子中{int(f9.SeedWins)}胜{int(f9.SeedLosses)}负。中位误差也由{med.loc[9,"Original"]:.4f}升至{med.loc[9,"LightJump"]:.4f}；均值恶化{(ratio.loc[9]-1)*100:.2f}%。10种子尚不足以证明普遍性，但该信号不能删除或只以均值挑异常值。',
'', '## Jump次数与规模','',
f'原版平均Jump{counts.loc["Original","Jumps"]:.2f}次、轻量版{counts.loc["LightJump","Jumps"]:.2f}次；两者频率接近，但每次重置20/4个位置，总重置次数均值分别为{counts.loc["Original","PositionResetsFromCode"]:.2f}/{counts.loc["LightJump","PositionResetsFromCode"]:.2f}。这些是事件计数（同一粒子可多次计入），不是独立新粒子数。',
'', '## 统计与结论','',
'轻量版相对原版的8个逐函数检验均未通过本24项Holm校正，不能把开发均值优势写成显著优势，也不能把未显著写成等效。']
for z in sig.itertuples():lines.append(f'本比较族显著项：F{z.FunctionID}，{z.Method} vs {z.Reference}，Holm={z.Holm24:.6g}，均值比={z.MeanRatio:.5f}。')
lines+=['','预定筛查未通过：F9退化超过20%，且不满足F6/F9各不退化10%的约束；轻量版中位均值比也略高于.95。保留原ASC默认值，不扩大到29函数、不按F编号切换Jump、不继续本批调参。',
'当前证据更支持“Jump有用，但强度存在取舍”，不支持“Jump必然破坏收敛”，也不支持“一律减小/删除Jump”。',
'后续若继续研究，应先确认能否用可观测搜索状态区分需要强恢复的过程；无需立即加新评分、Q、概率和半径控制。此方向尚无实现或有效性保证。',
'', '## 运行信息','',
'全部240次优化调用严格100k；每次调用的最优轨迹与算法返回T完全一致。11项预检、240条状态/Jump/参数重放和公开CSV复算通过。原文件SHA未变。错误启动在优化前结束；正式计算结束时的哈希表列名读取异常通过独立校验恢复，没有重新跑或选择性删除样本。']
(out/'DIAGNOSIS.md').write_text(chr(10).join(lines)+chr(10),encoding='utf8')
print(counts.to_string());print(sig[['FunctionID','Method','Reference','Holm24']].to_string(index=False))
