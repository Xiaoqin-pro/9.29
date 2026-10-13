# HIDMS-PSO正式同格比较协议（2026-10-13）

## 固定来源和算法身份

作者GitHub：FTVarna/HIDMS-PSO；commit `93e9fa6ba399fd24ae955a0b91b3e384d30ac30c`。
原始HIDMSPSO.m SHA256 `4138eec48fbec88706cf578db769f86858f338c9dd66afac78f630f927bfdbcf`。
文献：Varna, F. T.; Husbands, P., HIDMS-PSO: A New Heterogeneous Improved Dynamic Multi-Swarm PSO Algorithm, IEEE SSCI2020, 473–480, DOI10.1109/SSCI47803.2020.9308313。

- 本轮使用2020版，不混用后续HIDMS-PSO-Plus或2023 journal版。
- 原始源码下载在work；全源保留，不覆盖。
- GitHub仓库未声明开源许可证。本地研究使用及核验，暂不向自己的GitHub再发布该派生完整代码；保留出处与版权。

## 原生约束和参数

- 半群体异构，半群体同构，异构半群体按4成员单元组织，所以n需是8的倍数。原源码只检查n%4而reshape实际上要求n%8。
- 本轮N40，5个异构单元，每个master+3slaves；其余20个同构粒子。
- 不能令N50或随意补残余单元来凑相同population。
- Sigmoid惯性(.99→.2)+按粒子当前fitness相对mean(F)±.15；c1 2.5→.5/c2 .5→2.5。
- velocity cap=.15*range，初速0；非均匀mutation p=.1/b=5；通信启用，每10代洗牌；最后10%代采用标准PSO开发。
- 保留原代码的异步更新、单位洗牌、各类exemplar和通信。

## 明确修正

inward master行为2选择最佳slave时，`min(slave_costs)`产生局部1:3索引。原源码`PX(bsId,:)`误把局部索引用成全群体索引；本版改为`PX(sList(bsId),:)`，与源码注释的best-slave语义一致。其它master平均位置中的X/PX混用保持原样，未擅自改机制。

Clock随机seed改为预定searchseed，接受同一初始50点池前40点，同时保留作者原始初始化随机消耗。FE包括初始化；原脚本执行Tmax循环还另加初始化，存在总FE超额，本版按100k硬截断。Tmax=ceil(100k/40)=2500，参数原算式不改，最后剩余代截断。目标外包装按实际标量调用计数，不以代数替代FE。

## 逐点核验

机械oracle从原代码做接口/seed/p0/目标桥/计数截断和已声明一行索引修正；保持搜索块和helper。MATLAB适配器与oracle比较每次objective输入、全T、最终成本、最终RNG和迭代数，独立域/FE/返回best重查。手工best-slave映射见证另列，明确不会凭两份代码一致推断原算法无bug。

正式启动前需通过：D7/D50，预算40/41/57/600/2000，Sphere及CEC F1/F6/F13；额外F6/F13各100k及边界初始群体见证。

## 正式批次

29函数F1/F3–F30，D50，100000真实FE，seed3001–3030，870run；初始化池生成50×50并截取前40点，initSeed=261013000+fid*10000+seed，searchSeed=initSeed+1000000。4worker单线程；在HCLPSO补跑结束后顺序启动，避免两个4worker池竞争。

其它算法来源三列为原批次经MAT和hash核验的缓存，HCLPSO取补跑作者版。运行时跨批次记录，质量比较统一FE，但人口规模40vs50明确标注。未知结果不得写成性能优势；不因该基线太强删除。
