# FCS修复开发证据（2026-10-12）

源码修复提交：931e52a。原始运行目录：fcs_repaired_full_20261012_102652
原协议：docs/FCS_REPAIR_PROTOCOL_20261012.md。MAT完整轨迹和点级日志保存在本地results/cec对应目录；此处上传完整运行CSV、比较/条件统计、行为验收和执行源码指纹。
运行：MATLAB setup_project(true); addpath experiments; run_fcs_repaired_pilot; 分析：python experiments/analyze_fcs_repaired.py <run-dir> <public-dir>，需要numpy/pandas/scipy。
CSV文字已统一LF；source_manifest同时给实际执行字节hash和LF归一hash，以兼容Git行尾转换。
