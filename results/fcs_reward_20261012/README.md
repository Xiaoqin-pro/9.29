# FCS奖励开发证据

源码提交774b4f3，S0缓存控制来自2efb00c。
P/.9的默认等价经22组回归验证。新增运行完整轨迹在本地results/cec/fcs_reward_study_20261012_110014/runs/；此处包含所有条件、原始CSV、选择门槛与源码指纹。
复现：MATLAB run_fcs_reward_study；分析：python experiments/analyze_fcs_reward_study.py <run-dir> <public-dir>，需要numpy/pandas/scipy。
