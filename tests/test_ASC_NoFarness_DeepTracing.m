function test_ASC_NoFarness_DeepTracing
%TEST_ASC_NOFARNESS_DEEPTRACING  深开发变体与配额实现的谱系审计
%
%   ASC_NoFarness_DeepTracing 在 ASC_NoFarness_QuotaBalance 的基础上只加了一个
%   开关 resetVelOnSeek：Seeking 轮是否清零速度。本测试证明三件事：
%     (1) 默认（resetVelOnSeek = true、自适应 Seeking 概率）与配额实现在最优值
%         与逐评价点 best-so-far 轨迹上完全一致；
%     (2) 关闭速度重置后搜索轨迹确实发生变化（否则开关没生效）；
%     (3) 固定 Seeking 概率时，逐轮 SeekProb 恒等于设定值，且真实评价次数
%         仍精确等于预算。
%
%   这里的目标函数调用属于审计调用，不计入任何性能预算。

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, '-begin');
addpath(fullfile(root, 'data', 'cec2017'), '-begin');
addpath(fullfile(root, 'archive', 'legacy'), '-begin');
out = fullfile(root, 'work', 'dt_validation_20261015');
if ~isfolder(out), mkdir(out); end
old = pwd;  cleanup = onCleanup(@() cd(old));
cd(fullfile(root, 'data', 'cec2017'));

D = 50;  N = 50;  budget = 100000;
lb = -100 * ones(1, D);  ub = 100 * ones(1, D);
initSeed = 261026001;  searchSeed = 262026001;
checks = {};

for fid = [1 13 21]
    f = @(x) CEC2017Function(x, fid);
    rng(initSeed, 'twister');  p0 = lb + rand(N, D) .* (ub - lb);
    base = struct('initialPopulation', p0, 'lowerBound', lb, 'upperBound', ub, ...
        'maxEvaluations', budget, 'nearShare', 0.85);

    [Bq, Tq] = ASC_NoFarness_QuotaBalance(f, base, [], N, searchSeed);
    [Bd, Td, Id] = ASC_NoFarness_DeepTracing(f, base, [], N, searchSeed);
    assert(Bd.Cost == Bq.Cost && isequal(Td(:), Tq(:)), ...
        'F%d：默认配置与配额实现不一致。', fid);

    st2 = base;  st2.resetVelOnSeek = false;
    [Bv, Tv] = ASC_NoFarness_DeepTracing(f, st2, [], N, searchSeed);
    assert(~isequal(Tv(:), Tq(:)), 'F%d：关闭速度重置没有改变搜索轨迹。', fid);

    st3 = base;  st3.useAdaptiveProb = false;  st3.seekProbFixed = 0.05;
    [Bf, Tf, If] = ASC_NoFarness_DeepTracing(f, st3, [], N, searchSeed);
    RL = If.RoundLog;
    assert(all(abs(RL(:, 4) - 0.05) < 1e-12), 'F%d：固定 Seeking 概率未生效。', fid);
    assert(If.Evaluations == budget, 'F%d：真实评价次数不等于预算。', fid);

    checks{end+1} = struct('Function', fid, 'MatchesQuotaBalance', true, ...
        'VelResetChangesSearch', true, 'FixedProbRespected', true, ...
        'Evaluations', If.Evaluations, 'Rounds', If.Rounds);
end

disp(struct2table([checks{:}]));
disp('PASS：深开发变体的默认配置与配额实现逐点一致，两个开关均按预期生效。');

writetable(struct2table([checks{:}]), fullfile(out, 'checks.csv'));
rep = struct('Passed', true, 'Checks', numel(checks), ...
    'EngineSHA256', sha(fullfile(root, 'ASC_NoFarness_DeepTracing.m')), ...
    'OriginalSHA256', sha(fullfile(root, 'ASC_NoFarness.m')), 'MATLAB', version);
f = fopen(fullfile(out, 'validation.json'), 'w');
fprintf(f, '%s', jsonencode(rep, PrettyPrint=true));  fclose(f);
end

function d = sha(path)
f = fopen(path, 'r');  b = fread(f, inf, '*uint8');  fclose(f);
m = java.security.MessageDigest.getInstance('SHA-256');  m.update(b);
d = lower(reshape(dec2hex(typecast(m.digest(), 'uint8'), 2).', 1, []));
end
