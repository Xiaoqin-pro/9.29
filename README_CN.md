# 三维无人机配送算法比较平台（platform-20261004）

## 目的与状态

应用是固定测试舞台，研究重点是PSO、猫群CSO、CLPSO、GWO和后续算法的公平比较。
本版已完成可运行框架、独立可解性检查和小样本验证，不再继续修改地形、障碍、碰撞罚函数。
**状态是已验证候选平台，不是完成30次正式比较的论文基准。** 不能预先承诺某个新算法一定更好，也不能按新算法的输赢挑选实例/seed。
N10-tight仍0/5，CSO在简单场景仍0/5；保留这两个结果，不为消除失败继续调应用。先锁定本版本做后续统一协议研究，正式定稿需预先约定的新seed/更充分重复验证。

## 干净的八文件结构

```text
main.m           参数、建模、共享rand种群、直接for循环、保存和统计
CreateModel.m    CSV订单/时间窗、真实地形、圆柱威胁区
Fitness.m        排序解码、lambda/d/h转XYZ、全部目标与硬约束
PlotSolution.m   路线/编号/时间窗、收敛和箱线图
PSO.m            标准连续粒子群
CSO.m            猫群Seeking/Tracing
CLPSO.m          逐维综合学习粒子群
GWO.m            三领导者灰狼
```

另只有data/、results/和本说明，没有独立配置类、管理器、初始化修复文件或数据缓存MAT。
代码沿用胎儿心电项目的参数直接写、数组与for循环风格。

## 运行

```matlab
cd('D:\111\Desktop\噜噜\9.29');
main
```

开头 `runComparison=false`：单图PSO演示，`scenarioID=1`为N6-wide，`cfg.terrainType=2`为多峰。
默认seedBase=20271004，不以“找到可行”为条件重抽seed。不保证任意seed都成功；失败图明确标Infeasible candidate。

`runComparison=true`：四算法比较。参数直接写：

```matlab
algorithms = {'PSO','CSO','CLPSO','GWO'};
population = 30;
maxEvaluations = 3000;
runs = 5;
seedBase = 20271004;
mapIDs = 2;
caseIDs = 1:6;
```

主实验是代表地图×六场景。地形鲁棒性改成 `mapIDs=1:3; caseIDs=3;`，固定N8-wide，避免立即铺满巨量实验。
一次搜索的FE包括初始种群，不把CSO候选组算成一次评价。最后一次Fitness复算仅是验证，不计入搜索FE。
同地图、同任务规模、同repeat共用一个初始随机矩阵；wide/tight配对seed。算法执行顺序按repeat轮换，减轻顺序/JIT计时偏差（仍需正式计时预热）。
每批结果含原始Best/T/info/model/state、raw_runs.csv、summary.csv及代码/输入快照。

## 新版本问题规模与控制变量域

核心订单数为6/8/10，而不是旧10/15/20。原因：K1下旧15/20的试探仍全失败；当前不以反复修改应用救大规模结果。
订单子集嵌套：

- N6：1,5,9,13,17,20；
- N8：1,3,5,7,9,13,17,20；
- N10：1,3,5,7,9,11,13,15,17,20。

旧版本及旧15/20压力结果在历史批次input/和平台整定备份中保留，不能混算。

每航段一个控制点，连续向量维度为 `D=N+3*(N+1)`：N6=27、N8=35、N10=43。

```text
lambda ∈ [0.2,0.8]
d      ∈ [-15,15]
h      ∈ [0,12]
C = A + lambda*(B-A) + d*side + h*vertical
```

控制点不在端点附近扎堆；h只允许在端点连线上方，因此航段可上升/下降，但控制点本身不允许下钻到基准线下方。
**这是明确的新变量域，不只是“更聪明初始化”，也不是与旧K2/±25完全相同的可行域。** 所有位置仍由均匀rand生成，无路线注入、无repair、无引导枚举。
可解性见证只在项目外构造，随后独立复算，不被传给任何算法初值。

## 异质外生预约窗口

六组：N6/N8/N10 × wide/tight。CSV直接保存实际ready/due，main/CreateModel不再读取会悄悄携带旧模型的experiment_cases.mat。
同一站点跨任务规模和三地图共用预约中心及紧迫类别，不依赖任何算法或参考路线到达时间。
规则在CSV与scenario_manifest.json公开：

```text
class = 1 + mod(stationID-1,3)
center     = [75,95,115](class)
baseWidth  = [120,160,200](class)
wide scale = 1.2
tight scale= 0.5
ready = max(0,center-scale*baseWidth/2)
due   = center+scale*baseWidth/2
```

tight名义窗口宽60/80/100，wide为144/192/240；ready裁到0后实际宽度可能变短。类别是模拟中的相对紧迫等级，不声称这些数是现实业务测量。
窗口比此前候选24/30等宽得多：已验证小窗口仍将顺序限制得太强，选择较宽预约时段是本轮建模整定，不是算法改进。
wide/tight同中心同类别且区间包含；它们用于控制任务难度，不保证5次小样本中成功率严格单调。

## 保持不变的约束和评价

地形三张Copernicus GLO-90 DSM、六圆柱位置/半径/高度未改。速度6、服务时间3、服务高度8、净空4、安全膨胀2、最高高度42、25°爬升/下降、120°水平转向、仓库[0,240]不变。
提前到达等待，服务开始超过Due不可行；最终返仓。服务站点允许悬停调整航向。
目标：三维航程+0.05等待+2平滑项；原罚权重不变，算法档案显式可行优先。
原解析圆柱相交和地形双线性格内净空极值仍保留；没有新增连续穿透函数，没有降低净空或移走障碍。
地图和所有时空量是标准化仿真单位，不是实际米/秒航区。原TIF/MAT、来源和哈希保留，DSM含植被/建筑。

## 已完成的验证（不是最终论文统计）

代表地图PSO独立新seed确认，30粒子/3000 FE，六组各5次：

| 场景 | 可行 |
|---|---:|
| N6-wide | 4/5 |
| N6-tight | 3/5 |
| N8-wide | 5/5 |
| N8-tight | 3/5 |
| N10-wide | 1/5 |
| N10-tight | 0/5 |

简单N6-wide、四算法共享种群各5次：PSO5/5、CSO0/5、CLPSO3/5、GWO5/5。
这不代表普遍算法排名：样本少、单一场景。没有按CSO失败调弱它，也没有已验证的“提出算法”。后续应给各基线同等、独立的参数调整机会，使用新seed作正式测试。
代表N8-wide、PSO每图3次：ridge/peaks/mountain均3/3。三张地图并未设定成难度等级，仅作为空间环境维度。
18个地图×任务组合均有完整可行见证；这些见证从未进入rand初值。
手算时间表、K1边界、profiler精确评价数、固定seed复现、共享种群72次小预算接口检查通过。
最终60个运行由Python独立核对XYZ、三维距离、服务时刻、净空格内极值、圆柱相交、角度和Cost。

证据位置：

- results/platform_setup/20261004：PSO六场景30次、18个可解性见证、独立检查与探索记录；
- results/experiments/platform_20261004_123344_589：简单场景四基线20次；
- results/experiments/platform_20261004_124041_765：代表场景三地图9次；
- results/peaks/N6_wide：当前单图完整结果，距离267.865、成本269.752、可行、首次可行FE291。

旧results/calibration、diagnostics及历史实验保持原样，输入/代码快照标明其版本；不能与新平台成绩混合。
探索阶段发生过MATLAB当前目录优先导致外部试验加载旧Fitness的问题，已在平台exploration说明，相关成绩未纳入最终验收；最终60次均调用正式工程并独立复算。

## 加入你自己的算法

新算法使用与PSO相同签名 `[Best,T,info]=Method(model,state,maxgen,population,seed)`。
必须读取同一 `state.initialPopulation`、调用同一Fitness、严格尊重state.maxEvaluations、记录实际FE（含初始化和任何新候选/局部搜索）。
返回Best.Vector/Route/Control/Cost/Detail及info.InitialPopulation、Evaluations、FirstFeasibleEvaluation等现有字段；T按FE记录。
将方法名加入main开头algorithms列表即可；统计/画图不再写死四算法数量。不要为自己的算法注入额外答案、单独提高预算或排除失败seed。
先固定场景再比较；如结果不支持优越性，就如实报告或在独立训练实例上改算法，不能反向改正式实例。

## 数据与备份

data/包含三张原TIF/MAT、threat_zones.csv、20点站点池delivery_stations.csv、六场景CSV与scenario_manifest.json。实际运行读取六份CSV；20点池仅保留扩展素材。
不再需要场景MAT重建器或时间窗校准开关。要改实例，显式编辑CSV并另立版本，不在实验过程中自动生成。
完整前版备份和构造/验证脚本在：

```text
C:\Users\111\Documents\Codex\2026-09-29\d-111-desktop-new\platform929_20261004_115612
```

teacher和10.2未修改。当前不主动提交/上传GitHub。

## 表示能力和资源审计：不要把当前六点候选当最终主实验

用户指出地图任务密度与K1表示过于简化，本轮重新定位：N6仅适合作为校验/简单层，当前6/8/10不能就此宣称论文平台最终冻结。
固定peaks/N10-wide，PSO、FE10000、三个新seed，对照K1/K2×P30/P60：可行次数2/3、3/3、3/3、3/3。
K2在较充分统一预算下可解，但不自动更短/更平滑；P60也不必然质量更好。跨K平滑项的采样点数不同，不可无条件混比。
四算法K1/K2实际FE127的profiler审计通过，CSOSeeking候选没有漏记。订单规模、控制点数量、种群/预算要分别整定，不能只追求可行率或图好看。
下一阶段主场景候选应考虑N10/N15/N20和K2，在固定预约规则下试P30/60、FE10000/30000；通过独立seed验证后再决定，不预设谁获胜。
本轮当前八文件、算法、候选CSV和硬约束均未修改，仅新增诊断证据：results/diagnostics/representation_20261004。

## N10/N15/N20主任务资源整定（2026-10-04，未覆盖现有候选）

固定K2/原变量域及异质预约规则，N15-wide训练P30/60×FE10000/30000，各3个seed：可行1/3、0/3、0/3、2/3。
按训练前协议选择P60/FE30000，独立3个seed：N10wide3/3、N10tight0/3（几何安全但迟到）、N15wide/tight均0/3、N20wide0/3。
因此未将大任务和高预算改为当前正式默认，不能因训练2/3就冻结。N10/K2可以继续作为主实例候选；更大规模尚不稳定。
发现当前预约规则扩展后的N20tight(.5scale)是**数据本身不可行**：完整乐观XYZ时间模型精确子集DP无可行顺序，必要14单独立Python DP也无解。该组合不再按算法失败统计。
只做可解性检查，.6scale已获得并用完整Fitness验证3D见证，但尚未应用现有CSV；要修正数据必须另立版本并重新验证，不混改原试验。
27次完整记录、独立复核、证书、资源规则和明确限制见results/diagnostics/main_tasks_20261004。当前根目录八个MATLAB文件、算法/地图/硬约束/候选CSV保持不变。
