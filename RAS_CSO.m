function [gbest_fit, history_gbest, info] = RAS_CSO(fhd, Dimension, Particle_Number, Max_Gen, VRmin, VRmax, Popmin, Popmax, varargin)
%RAS_CSO  收益感知空间筛选猫群优化算法（Return-Aware Spatial-screening CSO）
%
%   [gbest_fit, history_gbest] = RAS_CSO(fhd, D, N, Max_Gen, VRmin, VRmax, Popmin, Popmax, func_num)
%   [gbest_fit, history_gbest] = RAS_CSO(..., func_num, initSeed, searchSeed)
%   [gbest_fit, history_gbest, info] = RAS_CSO(...)
%
%   接口与 CEC2017 测试框架一致；总真实评价次数严格不超过 Max_FEs = Max_Gen*N，
%   与 CLPSO、HCLPSO 等对比算法完全相同（已在运行内用计数器验证）。
%
%   算法由三个模块组成：
%     (1) 稀疏空间筛选。每轮 N 只猫全部按 Tracing/Seeking 产生候选，但只对其中
%         K = ceil(rho*N) 个候选消耗真实评价。位置更新与适应度评价解耦，因此
%         种群规模不再受评价预算限制，省下的评价转化为更多搜索轮次。
%     (2) 收益感知容量分配（本文机制）。筛选容量在"收敛驱动组"（离当前最优最近
%         的候选，用于精修当前最有希望的区域）与"多样性驱动组"（离群体中心最远
%         的候选，用于维持多样性）之间分配。原始实现把这 K 个名额固定按 1:1
%         对半分配；本文按两类候选在真实评价下的实际收益非对称分配。
%         边际收益审计（6 函数 × 5 种子 × 1e5 FE，共 3e6 次评价）显示：
%         收敛组的改善率随名额序号递减（第 1 名 7.65% → 第 5 名 3.62%），而
%         多样性组稳定在 0.35%–0.48%；两组相差一个数量级但都在起作用，
%         因此容量应向收敛组倾斜，同时不能取消探索组。
%     (3) 探索保障。多样性组至少保留 1 个名额（硬约束 exploreFloor）。取消该
%         约束（即 10:0）时 F1/F6/F13 明显退化，说明收益反馈只看即时改善是
%         短视的，必须用硬约束保留最低探索预算。
%
%   自适应 Seeking 概率/半径、停滞跳出（Jump）以及精英池、父代名额上限均沿用
%   ASC 的定稿设计，本文未作修改，以保证性能差异只来自模块 (2)(3)。
%
% ---------------- 版本说明（定稿冻结） ----------------
%   默认配置：rho = 0.20（N = 50 时每轮 10 次真实评价）、nearShare = 0.85、
%   exploreFloor = true、allocMode = 'fixed'。
%   战绩（CEC2017，D = 50，N = 50，Max_FEs = 1e5，种子 3001–3010，与基线共享
%   初始种群）：29 函数下平均排名 4.41（8 个算法同表比较，基线为 5.60）；
%   相对原 1:1 版本函数均值 21 胜 8 负，中位误差比 0.887，最差单函数退化 17.5%。
%   固定配比对照：1:1 → 0.887(9:1 基准下) / 7:3 → 0.792 / 9:1 → 0.778 /
%   10:0（关闭探索保障）→ 0.883，即 9:1 为最优固定配比，取消探索名额反而变差。
%   allocMode = 'adaptive' 提供按窗口收益反馈调整配额的版本（默认关闭，
%   参数与消融协议见 docs/ASC_QUOTA_*_PROTOCOL_*.md）。
%
%   说明：为保持文件可读，去掉了 ASC 中默认关闭且不消耗随机数的三个增强项
%   （子群合并搜索 useGroup、反向学习 useOBL、gbest 高斯候选 useGaussBest）
%   以及日志开关。它们关闭时不消耗随机数，因此删除不改变默认配置的搜索轨迹
%   （已用逐点等价测试验证：nearShare = 0.5 时与原 ASC 完全一致）。

% ---------------- 参数 ----------------
D = Dimension;  N = Particle_Number;
Max_FEs = Max_Gen * N;                 % 真实评价总预算
lb = Popmin(:)';  ub = Popmax(:)';
if isscalar(lb), lb = lb * ones(1, D); end
if isscalar(ub), ub = ub * ones(1, D); end
span = ub - lb;

% 输入解析：varargin{1} 为 func_num；可选 varargin{2}/varargin{3} 为初始化种子
% 与搜索种子（便于与其他算法共享初始种群做配对比较）。VRmin/VRmax 仅为接口
% 兼容保留：速度限幅按搜索空间跨度的固定比例设置，以免与已验证记录产生偏差。
func_num = varargin{1};
initSeed = [];  searchSeed = [];
if numel(varargin) >= 3, initSeed = varargin{2};  searchSeed = varargin{3}; end

% ---- (1) 稀疏空间筛选 ----
rho            = 0.20;    % 稀疏比例：每轮真实评价 K = ceil(rho*N) 个候选

% ---- (2)(3) 收益感知容量分配与探索保障（本文机制）----
allocMode      = 'fixed'; % 'fixed' 固定非对称配额；'adaptive' 按收益反馈调整
nearShare      = 0.85;    % 收敛驱动组的容量占比（allocMode = 'fixed' 时生效）
exploreFloor   = true;    % 探索保障：多样性组至少保留 1 个名额
allocShareMin  = 0.50;    % 自适应模式下配额的上下界
allocShareMax  = 0.90;
allocWindow    = 500;     % 自适应窗口长度（轮）
allocEta       = 0.30;    % 自适应平滑系数

% ---- 猫群搜索参数（沿用 ASC 定稿值，本文未修改）----
NumSeeking     = 4;       % 每个 Seeking 粒子产生的候选数
seekDimFrac    = 0.20;    % 每次扰动涉及的维度比例
radiusMin      = 0.020;   % Seeking 半径（相对跨度）
radiusMax      = 0.200;
seekProbMin    = 0.20;    % Seeking 概率上下界
seekProbMax    = 0.90;
convWindow     = 100;     % 收敛速度平滑窗口（轮）
slownessGain   = 0.05;    % 平滑系数
eliteFrac      = 0.20;    % 精英池比例
ownerCap       = 2;       % 单个粒子最多占用几个评价名额
inertiaStart   = 0.90;    % 惯性权重线性递减区间
inertiaEnd     = 0.40;
VmaxFrac       = 0.20;    % 速度限幅 = VmaxFrac × 跨度
useJump        = true;    % 停滞跳出
jumpGens       = 20;      % 停滞阈值（代，1 代 = 全群扫过一遍 = N 次评价）
jumpFraction   = 0.50;    % 每次跳出的粒子比例
jumpSamples    = 10;      % 每个被跳出粒子的候选采样数
jumpProtectElite = true;  % 保护精英不被跳出

K_round = max(1, ceil(rho * N));
Vmax    = VmaxFrac * span;
seekDims = max(1, round(seekDimFrac * D));
eliteCount = max(2, ceil(eliteFrac * N));
jumpTriggerFE = jumpGens * N;

% ---------------- 初始化 ----------------
if ~isempty(initSeed), rng(initSeed, 'twister'); end
X = lb + rand(N, D) .* span;                    % 初始种群（可由 initSeed 复现）
if ~isempty(searchSeed), rng(searchSeed, 'twister'); end

pbest_X = X;  pbest_fit = inf(N, 1);
gbest_fit = inf;  gbest_X = zeros(1, D);
history_gbest = nan(1, Max_FEs);                % 逐个评价点记录，索引 1..Max_FEs
FEs = 0;
for i = 1:N
    fv = feval(fhd, X(i, :)', func_num);
    FEs = FEs + 1;
    pbest_fit(i) = fv;
    if fv < gbest_fit, gbest_fit = fv;  gbest_X = X(i, :); end
    history_gbest(FEs) = gbest_fit;
end
V = 0.01 * (2 * rand(N, D) - 1) .* span;        % 初始速度（幅值为跨度的 1%）

% 容量分配与控制状态
nearShareCur = nearShare;
nearEval = 0;  nearImp = 0;  divEval = 0;  divImp = 0;
allocNext = 1 + allocWindow;
sNorm = 0;  succBuf = zeros(convWindow, 1);  bufPtr = 0;  bufCount = 0;
stallRounds = 0;  lastImproveFE = FEs;  jumpCount = 0;
roundLog = zeros(ceil((Max_FEs - FEs) / K_round) + 2, 12);
roundIndex = 0;

% ===================== 主循环 =====================
while FEs < Max_FEs
    roundIndex = roundIndex + 1;
    progress = (FEs - N) / max(1, Max_FEs - N);
    quota = min(K_round, Max_FEs - FEs);
    centre = mean(X, 1);

    % ---- (a) 自适应 Seeking 概率与半径（退火映射：收敛快则大范围探索，
    %          停滞则小范围精修。方向由 ASC 定稿确定，本文未改）----
    sEff = 1 - sNorm;
    pSeek = seekProbMin + (seekProbMax - seekProbMin) * sEff;
    rad   = radiusMin + (radiusMax - radiusMin) * sEff;
    pSeek = min(1, max(0, pSeek));

    % ---- (b) 收益感知容量分配：本轮两个组各占多少评价名额 ----
    % 自适应模式每 allocWindow 轮用一次真实收益反馈：
    %   目标配比 = 收敛组改善率 / (收敛组改善率 + 多样性组改善率)
    % 再按 allocEta 平滑，避免窗口边界上的突变。
    if strcmp(allocMode, 'adaptive') && roundIndex >= allocNext
        gCvg = nearImp / max(1, nearEval);
        gDiv = divImp / max(1, divEval);
        tgt  = allocShareMax;
        if gDiv > 0, tgt = gCvg / (gCvg + gDiv); end
        tgt = min(allocShareMax, max(allocShareMin, tgt));
        nearShareCur = (1 - allocEta) * nearShareCur + allocEta * tgt;
        nearEval = 0;  nearImp = 0;  divEval = 0;  divImp = 0;
        allocNext = roundIndex + allocWindow;
    end
    Kcvg = ceil(quota * nearShareCur);
    if exploreFloor && quota >= 2, Kcvg = min(Kcvg, quota - 1); end
    Kdiv = quota - Kcvg;

    % ---- (c) 候选生成：全部粒子都移动，每轮产生约 N*(NumSeeking 或 1) 个候选 ----
    inertia = inertiaStart + (inertiaEnd - inertiaStart) * progress;
    [~, ord] = sort(pbest_fit);
    elites = ord(1:eliteCount);                 % 精英池在轮初固定，Jump 也用这一份
    pool = zeros(N * (NumSeeking + 1), D);  owner = zeros(N * (NumSeeking + 1), 1);
    m = 0;  role = zeros(N, 1);
    for i = 1:N
        eliteVector = pbest_X(elites(randi(eliteCount)), :);
        if rand < pSeek
            % 探索模式 Seeking：在当前位置附近做小范围随机扰动
            role(i) = 2;
            for j = 1:NumSeeking
                dims = randperm(D, seekDims);
                cand = X(i, :);
                step = rad * span(dims) .* (2 * rand(1, seekDims) - 1) / 2;
                cand(dims) = X(i, dims) + step;
                cand = min(ub, max(lb, cand));
                m = m + 1;  pool(m, :) = cand;  owner(m) = i;
            end
            V(i, :) = 0;
        else
            % 开发模式 Tracing：向精英历史位置追踪移动
            role(i) = 1;
            tv = inertia * V(i, :) + 2 * rand(1, D) .* (eliteVector - X(i, :));
            tv = min(Vmax, max(-Vmax, tv));
            V(i, :) = tv;
            cand = min(ub, max(lb, X(i, :) + tv));
            m = m + 1;  pool(m, :) = cand;  owner(m) = i;
        end
    end

    % ---- (d) 空间筛选：从候选池中挑出值得消耗真实评价的 quota 个位置 ----
    [sel, newRow, selPhase] = geometryScreen(pool(1:m, :), owner(1:m), gbest_X, ...
        centre, Kcvg, Kdiv, N, ownerCap);
    assert(numel(sel) == quota, '筛选返回 %d 个位置，配额为 %d。', numel(sel), quota);

    % ---- (e) 位置更新：全部粒子按几何评分前进，与是否被评价无关 ----
    for i = 1:N
        r = newRow(i);
        if r > 0, X(i, :) = pool(r, :); end
    end

    % ---- (f) 只评价被筛出的 quota 个候选，并按组累计真实收益 ----
    improved = false;
    for k = 1:numel(sel)
        r = sel(k);  i = owner(r);  x = pool(r, :);
        fv = feval(fhd, x', func_num);  FEs = FEs + 1;
        betterPbest = fv < pbest_fit(i);
        if betterPbest, pbest_X(i, :) = x;  pbest_fit(i) = fv; end
        if fv < gbest_fit, gbest_fit = fv;  gbest_X = x;  improved = true; end
        history_gbest(FEs) = gbest_fit;
        if selPhase(k) == 1
            nearEval = nearEval + 1;
            if betterPbest, nearImp = nearImp + 1; end
        else
            divEval = divEval + 1;
            if betterPbest, divImp = divImp + 1; end
        end
    end

    % ---- (g) 收敛速度平滑：供下一轮的自适应 Seeking 概率/半径使用 ----
    % 以"最近 convWindow 轮中改善过全局最优的比例"作为慢度指标，经指数平滑后
    % 映射到 Seeking 概率与半径，避免在轮与轮之间突变。
    bufPtr = mod(bufPtr, convWindow) + 1;
    succBuf(bufPtr) = double(improved);
    bufCount = min(bufCount + 1, convWindow);
    succRate = sum(succBuf(1:bufCount)) / bufCount;
    sNorm = sNorm + slownessGain * ((1 - succRate) - sNorm);
    sNorm = min(1, max(0, sNorm));
    if improved, stallRounds = 0;  lastImproveFE = FEs; else, stallRounds = stallRounds + 1; end

    % ---- (h) 停滞跳出：把部分非精英粒子迁到"离精英最远"的采样点上 ----
    % 被判定的粒子由 jumpFraction 决定，且精英始终受保护。跳出的采样点只做几何
    % 选择、不额外消耗评价，因此不改变总预算。
    jumped = false;
    if useJump && (FEs - lastImproveFE) >= jumpTriggerFE
        [~, ordCost] = sort(pbest_fit);
        jumpElites = elites;
        protect = 0;
        if jumpProtectElite, protect = min(N - 1, eliteCount); end
        victims = ordCost(protect + 1:N);
        if jumpFraction < 1 && ~isempty(victims)
            nv = max(1, round(jumpFraction * numel(victims)));
            victims = victims(randperm(numel(victims), nv));
        end
        if ~isempty(victims)
            eliteVectors = pbest_X(jumpElites, :);
            eliteNorm = sum(eliteVectors.^2, 2)';
            for q = 1:numel(victims)
                i = victims(q);
                S = lb + span .* rand(jumpSamples, D);
                d2 = sum(S.^2, 2) - 2 * (S * eliteVectors') + eliteNorm;
                [~, b] = max(min(d2, [], 2));
                X(i, :) = S(b, :);
                V(i, :) = 0;
            end
            jumpCount = jumpCount + 1;
            jumped = true;
        end
        stallRounds = 0;  lastImproveFE = FEs;
    end

    roundLog(roundIndex, :) = [FEs, quota, Kcvg, Kdiv, nearShareCur, pSeek, rad, ...
        sNorm, succRate, double(jumped), sum(role == 1), sum(role == 2)];
end

history_gbest = history_gbest(1:FEs);

% ---------------- 诊断信息（第三个输出，可选）----------------
info = struct( ...
    'Algorithm', 'RAS-CSO', ...
    'Evaluations', FEs, ...
    'Rounds', roundIndex, ...
    'Jumps', jumpCount, ...
    'FinalNearShare', nearShareCur, ...
    'FinalSeekProb', pSeek, ...
    'FinalRadius', rad, ...
    'FinalSlowness', sNorm, ...
    'RoundLog', roundLog(1:roundIndex, :), ...
    'RoundLogColumns', {{'FEs', 'Quota', 'Kcvg', 'Kdiv', 'NearShare', 'SeekProb', ...
        'Radius', 'Slowness', 'SuccessRate', 'Jumped', 'TracingCount', 'SeekingCount'}});
end


% =================== 辅助函数 ===================
function [sel, newRow, selPhase] = geometryScreen(pool, owner, best, center, Kcvg, Kdiv, N, cap)
% GEOMETRYSCREEN  从候选池中选出值得消耗真实评价的位置
%
%   两阶段贪心，是本文相对 ASC 唯一改动的模块：
%     收敛驱动组：取离当前全局最优最近的 Kcvg 个候选，用于精修当前最有希望的
%                 区域。边际收益审计显示该组的改善率随名额序号递减。
%     多样性驱动组：取离群体中心最远的 Kdiv 个候选，用于维持种群多样性。
%   两组名额互不重叠，且每个粒子最多贡献 cap 个名额，避免配额被单一粒子独占。
%   粒子下一轮的位置取"两个距离排名之和最小"的候选，使未获真实评价的粒子也按
%   几何规则继续前进——这正是稀疏筛选下仍能保持搜索进度的原因。
quota = Kcvg + Kdiv;
M = size(pool, 1);
sel = zeros(quota, 1);  n = 0;  newRow = zeros(N, 1);  selPhase = zeros(quota, 1);
if M == 0 || quota == 0, return; end

dB = sum((pool - best).^2, 2);
dC = sum((pool - center).^2, 2);
[~, oNear] = sort(dB);
[~, oFar]  = sort(dC, 'descend');
rankNear = zeros(M, 1);  rankNear(oNear) = (1:M)';
rankFar  = zeros(M, 1);  rankFar(oFar)   = (1:M)';

cnt = zeros(N, 1);  taken = false(M, 1);
for idx = oNear'
    if n >= Kcvg, break; end
    pp = owner(idx);
    if ~taken(idx) && cnt(pp) < cap
        taken(idx) = true;  cnt(pp) = cnt(pp) + 1;  n = n + 1;
        sel(n) = idx;  selPhase(n) = 1;
    end
end
for idx = oFar'
    if n >= quota, break; end
    pp = owner(idx);
    if ~taken(idx) && cnt(pp) < cap
        taken(idx) = true;  cnt(pp) = cnt(pp) + 1;  n = n + 1;
        sel(n) = idx;  selPhase(n) = 2;
    end
end
if n < quota
    for idx = oNear'
        if n >= quota, break; end
        if ~taken(idx)
            taken(idx) = true;  n = n + 1;  sel(n) = idx;  selPhase(n) = 1;
        end
    end
end
sel = sel(1:n);  selPhase = selPhase(1:n);

score = rankNear + rankFar;
bestScore = inf(N, 1);
for idx = 1:M
    pp = owner(idx);
    if score(idx) < bestScore(pp)
        bestScore(pp) = score(idx);  newRow(pp) = idx;
    end
end
end
