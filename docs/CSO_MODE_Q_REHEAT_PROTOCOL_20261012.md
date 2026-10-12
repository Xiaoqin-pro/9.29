> 已撤回（2026-10-12）：用户明确Q只控制真实评价配额。下文为未执行草案，不再作为当前实验协议。两次启动均在预检阶段退出，未创建smoke或正式优化批。算法和runner草稿保留以追溯，runner已阻止自动执行。

# Q控制的Seeking半径动作预试（2026-10-12）

## 用户锚点与本轮问题
用户强调仍以Q-learning为主，并授权检索半径方法、多个有限尝试。之前stag1000独立640run确认未过Fixed6/Random/Phase强门，不能称成功。截图F22曲线体现前期快速下降/平台与后期继续进步，但曲线本身不证明div或局部最优，须结合真实群体。源码Seeking幅度baseWidth=.05*(ub−lb)/2，随(1−progress)缩至零，现有三个配额动作都无法改变这一幅度。

本轮只给现有action1（2T8S）一个明确的停滞搜索行为：当实际决策state的真实stall>=1000FE时，允许改变Seeking范围扰动宽度；action2/3、健康状态完全保持原公式。Q仍6×3表、100FE决策、±1奖励，alpha.1/gamma.9/eps.1，B10/SMP5、MR=.4、精英项与几何筛选、10FE预算、真实锚点和回滚不变。它是“Q选择有限评价资源及停滞搜索强度”，不是给Q再叠多个学习器。

## 三个有限半径候选
- reset：上述触发时用初始baseWidth，原始实现仍单一乘法，最简单。
- floor：上述触发时使用baseWidth*max(.2,1−progress)，保留初始幅度20%下限。
- spread：每决策前从realPop的坐标std计算width=min(baseWidth,max(.1baseWidth,.5std(realPop)))，该100FE块固定此width。只读已评价真实锚点，不能用虚拟位置或CEC最优值。

三者不重新初始化个体，不凭空增加目标调用，仍评价筛选出的既有Seeking候选，只改变原范围扰动幅度，不引入额外跳跃候选。要改善真实锚点需真实评价和原接受条件。Q如果不选action1就无恢复；no-reheat开关严格恢复原State入口轨迹。

## 文献来源与阅读范围
2021 Mohammad Shehab等DCSO作者稿arXiv:2107.08908的2.2/3.2节：经典Seeking按当前坐标±SRD扰动，作者DCSO用更广的随机乘法且去掉SRD，同时改模式与候选选择。因此它只是搜索范围影响探索的依据，不据其整体性能推导半径必有效。
2021 Tsai等Adjustable mode ratio and focus boost search strategy，Applied Computing and Intelligence，DOI10.3934/aci.2021005：末段用local refinement、可调MR与速度简化，提醒后期可能需要精细搜索而非统一扩半径。2020 ACSO DOI10.1155/2020/1291526及2025 improved CSO DOI10.1007/s10586-025-05586-5亦有多机制适配，不直接移植整套。
reset/floor/spread为本项目有界设计，不称原论文精确复现。原乘法半径有坐标平移敏感和近零扰动趋零问题，CEC有shift，不优先采用纯坐标比例。三个候选不分函数定制、不加第四网格。

## 骨架与Q必要性对照
D50/100k八函数F1/F3/F6/F9/F12/F13/F22/F30，五新seed1601–1605，InitSeed=21301012+fid*10000+seed、SearchSeed+1M。八条件：fixed6、Q-no-reheat、三种Q-radius、三种Rule-radius，总320新run，32MFE。Rule同state和radius，在非停滞用6T4S、停滞直接用2T8S；它用于检验Q选择是否超过直接执行恢复规则。不沿用旧seed缓存主控制。四process worker单线程，先F1/F12八条件600FE共16smoke。

运行前检查no-reheat三模式Best/T/RNG/Q表逐点等价、fixed6有恢复开关也完全相同、真实stall状态/Reward、条件active==(useReheat & stall & action1)、effective width、FE/cap2、Q重放。记录ReheatLog/RadiusWidths/RadiusRoundLog/TrendLog，源快照固定。

## 预写选择与后续
每个radius候选的Q须平均函数排名低于Fixed6、Q-no-reheat和同radius Rule，对每个对照>=4/8函数均值不差、>=20/40配对seed不差，无双方>1e-8时误差均值>10倍退化；过门才补同radius Random/EpsFixed控制（80新run同格，依照来源快照缓存原三控制），然后十新seed确认。若多个过，整体平均排名低者优先，同rank以reset>floor>spread顺序优先更简单公式。若Q不能胜Rule，半径有效也不称学习有效，不写成功故事。

失败版本全部公开，不通过改门/删函数/固定seed来让Q成功。五seed仅开发，确认批内冻结方法、后续完整CEC/标准500k/D100需另验证。以阶段与真实div/stall曲线解释机制，观察性曲线不能支持保证逃出局部最优。
