function test_RAS_CSO
%TEST_RAS_CSO  RAS_CSO 与已验证实现的逐点等价性审计
%
%   RAS_CSO 是 ASC-NoFarness 的整理版：搜索核心（Tracing/Seeking/Jump/自适应
%   概率与半径/精英池/父代名额上限）逐字沿用，只把空间筛选的容量分配改成
%   收益感知的非对称配额。本测试证明两件事：
%     (1) 默认配置（nearShare = 0.85、探索保障开启）与已验证的
%         ASC_NoFarness_QuotaBalance(0.85) 在最优值、以及逐评价点的
%         best-so-far 轨迹上完全一致；
%     (2) 把 nearShare 调回 0.5、关闭探索保障后，与原版 ASC_NoFarness
%         （即固定 1:1 配额）完全一致；
%   此外检查评价次数恰好等于预算、以及每轮"多样性组至少 1 个名额"的硬约束。
%
%   这里的目标函数调用属于审计调用，不计入任何性能预算。

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, '-begin');
addpath(fullfile(root, 'data', 'cec2017'), '-begin');
addpath(fullfile(root, 'archive', 'legacy'), '-begin');

D = 50;  N = 50;  Max_Gen = 2000;            % Max_FEs = Max_Gen * N = 1e5
lb = -100 * ones(1, D);  ub = 100 * ones(1, D);
initSeed = 261026001;  searchSeed = 262026001;

% RAS_CSO 按标准 CEC2017 框架约定以列向量调用 fhd；本仓库的包装函数接收行向量
% 后再转置，因此测试里做一次适配。
fh = @(x, fn) CEC2017Function(x', fn);

% 生成一份 nearShare = 0.5、关闭探索保障的临时副本，用于还原原版 1:1 行为
vdir = tempname;  mkdir(vdir);
cleanupDir = onCleanup(@() removeTempDir(vdir));
src  = fileread(fullfile(root, 'RAS_CSO.m'));
var  = strrep(src, 'function [gbest_fit, history_gbest, info] = RAS_CSO(', ...
                    'function [gbest_fit, history_gbest, info] = RAS_CSO_REF50(');
var  = strrep(var, 'nearShare      = 0.85;', 'nearShare      = 0.50;');
var  = strrep(var, 'exploreFloor   = true;', 'exploreFloor   = false;');
fid_v = fopen(fullfile(vdir, 'RAS_CSO_REF50.m'), 'w');  fprintf(fid_v, '%s', var);  fclose(fid_v);
addpath(vdir, '-begin');

checks = {};
old = pwd;  cleanupPwd = onCleanup(@() cd(old));
cd(fullfile(root, 'data', 'cec2017'));

for fid = [1 13 21]
    f = @(x) CEC2017Function(x, fid);
    % 参考实现一：原版 ASC-NoFarness（固定 1:1 配额）
    rng(initSeed, 'twister');  p0 = lb + rand(N, D) .* (ub - lb);
    st = struct('initialPopulation', p0, 'lowerBound', lb, 'upperBound', ub, ...
        'maxEvaluations', 100000);
    [B0, T0] = ASC_NoFarness(f, st, [], N, searchSeed);
    % 参考实现二：已验证的 0.85 配额实现
    st2 = st;  st2.nearShare = 0.85;
    [B85, T85] = ASC_NoFarness_QuotaBalance(f, st2, [], N, searchSeed);
    % 待审计：RAS_CSO 默认配置与 1:1 变体
    [Bg, Tg, Ig]  = RAS_CSO(fh, D, N, Max_Gen, -100, 100, -100, 100, fid, initSeed, searchSeed);
    [B50, T50, I50] = RAS_CSO_REF50(fh, D, N, Max_Gen, -100, 100, -100, 100, fid, initSeed, searchSeed);

    assert(Bg == B85.Cost && isequal(Tg(:), T85(:)), ...
        'F%d：RAS_CSO 默认配置与已验证的 0.85 实现不一致。', fid);
    assert(B50 == B0.Cost && isequal(T50(:), T0(:)), ...
        'F%d：RAS_CSO 的 1:1 变体与原版 ASC-NoFarness 不一致。', fid);
    assert(Ig.Evaluations == Max_Gen * N && I50.Evaluations == Max_Gen * N, ...
        'F%d：真实评价次数不等于预算。', fid);

    RL = Ig.RoundLog;
    assert(all(RL(:, 2) == RL(:, 3) + RL(:, 4)), 'F%d：各组名额之和与配额不符。', fid);
    assert(all(RL(RL(:, 2) >= 2, 4) >= 1), 'F%d：探索保障被违反。', fid);
    assert(all(RL(RL(:, 2) == 10, 3) == 9), 'F%d：满配额轮的收敛组名额应为 9。', fid);
    checks{end+1} = struct('Function', fid, 'IdenticalTo0p85', true, ...
        'IdenticalToBaseline', true, 'Evaluations', Ig.Evaluations, ...
        'Rounds', Ig.Rounds, 'MinDivSlots', min(RL(RL(:,2)>=2, 4)));
end

disp(struct2table([checks{:}]));
disp('PASS：RAS_CSO 与两个已验证实现在 3 个函数、1e5 次评价上逐点完全一致。');

    function removeTempDir(d)
        if contains(path, d), rmpath(d); end
        if isfolder(d), rmdir(d, 's'); end
    end
end
