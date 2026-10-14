# 公开数据复算

主结果目录：results/saq_strong_confirmation_29f_10seed_20261014。

公开CSV包含2320行、29函数、10种子、8方法。新增580次优化运行；其余1740次复用已核验对照。原始逐运行MAT与完整源码/CEC快照保留在本地results/cec/，不放入Git。

不需要私有MAT即可核对均值、标准差、平均秩、配对检验和阶段节点：

    python experiments/verify_saq_strong_public.py results/saq_strong_confirmation_29f_10seed_20261014

重新运行确认实验需要本地既有对照原件；先按docs/SAQ_STRONG_CONFIRMATION_PROTOCOL_20261014.md核验缓存及源码，再启动MATLAB的run_saq_strong_confirmation。重新下载文本源码后的Git换行变化允许CRLF→LF归一化，历史快照原始SHA仍单独核对。

HIDMS使用已审计索引修正版；DMS为SIS2005论文重构版；HCLPSO为作者代码适配版。详细出处、种群设置和既有测试见各算法头部与docs/协议。

优先阅读DIAGNOSIS_AND_NEXT_STEP.md，然后查看largest_gaps.png及function_curves/。
