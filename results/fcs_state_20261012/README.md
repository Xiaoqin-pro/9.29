# FCS相对质量状态证据

新源码以source_manifest为准，奖励缓存来自774b4f3/S0缓存来自2efb00c。
旧状态与固定控制等价经19组精确回归验证。新增运行完整轨迹在本地results/cec/fcs_state_study_20261012_113217/runs/；此处包含所有条件、原始CSV、选择门槛与源码指纹。
复现：MATLAB run_fcs_state_study；分析：python experiments/analyze_fcs_state_study.py <run-dir> <public-dir>，需要numpy/pandas/scipy。
