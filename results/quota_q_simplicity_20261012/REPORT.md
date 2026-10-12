# 配额Q机制删除结果（2026-10-12）

200新run/20M真实FE，八函数五原开发seed，同search骨架/三quota/reward+10，仅删除gate及进一步删stallbit。120旧质量缓存不算新；200Best重查、10smoke单列。完整MAT/state/reward/Q/FE和实际120cachedp0核验通过。

八条件rank：{'Fixed6': 3.25, 'Gated-Q6-Bonus10': 3.25, 'Phase': 3.5, 'Random': 4.5, 'Simple-Q6': 4.5, 'EpsFixed6': 5.0, 'Original-Q6-Bonus1': 5.375, 'Simple-Q3': 6.625}。

- Simple-Q6表6×3，强对照门未通过，rank4.500。
- Simple-Q3表3×3，强对照门未通过，rank6.625。

按先写门选定：无，保留候选/不定版。

Q6去门、Q3再去stallbit，均无恢复/holding/visit-rate，Search公式不改；简洁不等于效果保证。Fixed6、全程Random/Phase/Eps提供同chance对照，旧Q和较稳gatedcandidate不删除。五seed同格开发非独立确认，不把平均rank票数说显著。
