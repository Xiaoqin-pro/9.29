function [Best,T,info] = DSS_RLCSO_CEC(f,state,maxgen,Particle_Number,seed)
    % 冻结的正式入口；MAQL-V1 参数与核心算法保持一致。
    state.rlMode='modeAware';
    [Best,T,info]=DSS_RLCSO(f,state,maxgen,Particle_Number,seed);
    info.Algorithm='DSS_RLCSO';
end
