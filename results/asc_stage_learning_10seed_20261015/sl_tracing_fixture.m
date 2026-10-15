function trialVelocity=sl_tracing_fixture(p,inertia,vel_i,x_i,pbest_i,eliteVector,D, ...
    useCog,cogStream)
%TRACINGVELOCITY  The Tracing velocity update, isolated so it can be replayed.
%
% The social-only branch reproduces the original expression exactly, including
% the single rand(1,D) draw, so routing the update through this helper cannot
% change the published ASC-NoFarness trajectory.  The cognitive branch keeps that
% same global draw for its social term and takes the cognitive coefficient from
% the dedicated stream, which never touches the global stream.  The two
% coefficients sum to 2, so the expected total learning weight per dimension is
% 1.0 in both branches and the comparison isolates the learning direction.
if ~useCog
    trialVelocity=inertia*vel_i+2*rand(1,D).*(eliteVector-x_i);
    return
end
c1=2*p.cognitiveShare;
c2=2*(1-p.cognitiveShare);
rSocial=rand(1,D);
rCog=rand(cogStream,1,D);
trialVelocity=inertia*vel_i+c1*rCog.*(pbest_i-x_i)+c2*rSocial.*(eliteVector-x_i);
end


