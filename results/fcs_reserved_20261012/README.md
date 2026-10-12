# FCS单保留名额证据

新实现以source_manifest为准，Keep缓存来自2efb00c的FCS-batch，另含B10参考。
Keep/Batch经40组逐点/Best/T/RNG严格回归，所有351配置均保持同一搜索随机流。新增运行完整轨迹在本地results/cec/fcs_reserved_study_20261012_121438/runs/；此处包含所有条件、原始CSV、选择门槛与源码指纹。
复现：MATLAB run_fcs_reserved_study；分析：python experiments/analyze_fcs_reserved_study.py <run-dir> <public-dir>，需要numpy/pandas/scipy。
