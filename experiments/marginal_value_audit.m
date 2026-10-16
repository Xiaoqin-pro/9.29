function out = marginal_value_audit(funcs, seeds, nearShare)
%MARGINAL_VALUE_AUDIT  空间筛选两个阶段的边际收益审计
%
%   out = marginal_value_audit(funcs, seeds, nearShare)
%
%   在 nearShare 指定的固定配额下跑 D=50、N=50、1e5 次真实评价，按"候选属于
%   收敛驱动组还是多样性驱动组、以及它在组内的名额序号"统计真实评价的改善
%   情况。输出用于说明 RAS-CSO 的容量分配动机：
%     * 收敛组内部边际收益递减（越靠后的名额越难改善 pbest）；
%     * 多样性组的名义收益低但稳定，不能整体取消；
%     * 因此容量应当在两组之间非对称分配，并保留最低探索名额。
%
%   审计本身不改变搜索：ASC_NoFarness_QuotaAudit 与同配额的
%   ASC_NoFarness_QuotaBalance 在本函数覆盖的配置下逐点一致（见自检断言）。
%
%   示例：
%     out = marginal_value_audit([1 6 9 13 14 21], 3001:3005, 0.5);

if nargin < 1, funcs = [1 6 9 13 14 21]; end
if nargin < 2, seeds = 3001:3005; end
if nargin < 3, nearShare = 0.50; end

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, '-begin');
addpath(fullfile(root, 'data', 'cec2017'), '-begin');
addpath(fullfile(root, 'archive', 'legacy'), '-begin');
old = pwd;  cleanup = onCleanup(@() cd(old));
cd(fullfile(root, 'data', 'cec2017'));

D = 50;  N = 50;  budget = 100000;  lb = -100 * ones(1, D);  ub = 100 * ones(1, D);
slot = struct('eval', zeros(2, 10), 'imp', zeros(2, 10), 'glob', zeros(2, 10));
parity = 0;

for fid = funcs
    f = @(x) CEC2017Function(x, fid);
    for sd = seeds
        initSeed = 261026000 + (sd - 3000);      % 与 30 种子对比批一致的初始种群
        rng(initSeed, 'twister');  p0 = lb + rand(N, D) .* (ub - lb);
        st = struct('initialPopulation', p0, 'lowerBound', lb, 'upperBound', ub, ...
            'maxEvaluations', budget, 'nearShare', nearShare);
        [B1, ~, I1] = ASC_NoFarness_QuotaAudit(f, st, [], N, 262026000 + (sd - 3000));
        A = I1.MarginalAudit;
        slot.eval = slot.eval + squeeze(A(:, :, 1));
        slot.imp  = slot.imp  + squeeze(A(:, :, 2));
        slot.glob = slot.glob + squeeze(A(:, :, 3));
        [B2, ~] = ASC_NoFarness_QuotaBalance(f, st, [], N, 262026000 + (sd - 3000));
        parity = max(parity, abs(B1.Cost - B2.Cost));
    end
end

assert(parity == 0, '审计实现与配额实现在同一配置下不一致（差异 %g）。', parity);

out = struct();
out.nearShare = nearShare;
out.functions = funcs;
out.seeds = seeds;
out.slotEval = slot.eval;      % 行 1 = 收敛驱动组，行 2 = 多样性驱动组
out.slotImp  = slot.imp;
out.slotGlob = slot.glob;
out.nearRate = slot.imp(1, :) ./ max(1, slot.eval(1, :));
out.divRate  = slot.imp(2, :) ./ max(1, slot.eval(2, :));
out.nearRateTotal = sum(slot.imp(1, :)) / sum(slot.eval(1, :));
out.divRateTotal  = sum(slot.imp(2, :)) / max(1, sum(slot.eval(2, :)));
out.globNear = sum(slot.glob(1, :));
out.globDiv  = sum(slot.glob(2, :));

fprintf('\n空间筛选边际收益审计（nearShare=%.2f，D=50，N=50，1e5 FE，%d 函数 × %d 种子）\n', ...
    nearShare, numel(funcs), numel(seeds));
fprintf('%-6s %-14s %-14s %-10s | %-14s %-14s %-10s\n', ...
    '序号', '收敛组评价', '收敛组改善', '改善率', '多样性组评价', '多样性组改善', '改善率');
for k = 1:10
    if out.slotEval(1, k) == 0 && out.slotEval(2, k) == 0, continue; end
    fprintf('%-6d %-14d %-14d %-10.4f | %-14d %-14d %-10.4f\n', k, ...
        out.slotEval(1, k), out.slotImp(1, k), out.nearRate(k), ...
        out.slotEval(2, k), out.slotImp(2, k), out.divRate(k));
end
fprintf('合计：收敛组 %.4f，多样性组 %.4f；改善全局最优次数 收敛组 %d / 多样性组 %d\n', ...
    out.nearRateTotal, out.divRateTotal, out.globNear, out.globDiv);
fprintf('审计与配额实现的逐点一致性检查：最大差异 %g\n', parity);
end
