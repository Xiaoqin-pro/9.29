# platform-20261004整定证据

当前版本是可运行的已验证候选平台，不宣称已完成正式论文基准验收。
核心6/8/10单，K1，lambda[.2,.8]、d[-15,15]、h[0,12]，不同站点的外生中心/宽度，wide1.2/tight.5。其他地形/障碍/硬约束及罚函数不变。

confirmation/30个PSO原始MAT对应pso_confirmation.csv：4/5、3/5、5/5、3/5、1/5、0/5。
witness/18个MAT仅验证每个地图/任务可解，不参与初始化。witness_checks.csv说明全部找到。
source/input为最终工程快照；IndependentCheck.py及independent_checks.json复查30个确认、20个四算法比较、9个鲁棒性、1个默认单图，共60个结果。
exploration/保留失败及MATLAB路径误用记录，不能选性删除；它们不是正式排名。tools/是构造期脚本，部分依赖本机路径与外部备份，不是日常入口。
新的主程序没有读取任何witness，只按seed产生rand矩阵。正式CSO0/5与N10tight0/5保留，不做效果承诺。
详细变量、预约规则、条件与限制见项目根目录README及data/scenario_manifest.json。
