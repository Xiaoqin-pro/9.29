function [Best,T,info] = DSS_MAQLCSO(f,state,maxgen,Particle_Number,seed)
    state.rlMode='modeAware';
    [Best,T,info]=DSS_RLCSO(f,state,maxgen,Particle_Number,seed);
    info.Algorithm='DSS_MAQLCSO';
end
