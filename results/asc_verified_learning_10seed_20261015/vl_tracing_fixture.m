function trialVelocity=vl_tracing_fixture(p,inertia,vel_i,x_i,pbest_i,eliteVector, ...
    eliteIdxList,exploreFlag,pbestAll,D)
%TRACINGVELOCITY  The Tracing velocity update, isolated so it can be replayed.
%
% B0 reproduces the original expression exactly, including the single
% rand(1,D) draw, so routing the update through this helper cannot change the
% published ASC-NoFarness trajectory.  B1 adds the particle's own verified
% personal best as a second learning direction; B2 additionally lets the
% explore-type particles compose their social direction dimension by dimension
% from several verified elite personal bests instead of a single exemplar.
if strcmp(p.learnMode,'B0')
    trialVelocity=inertia*vel_i+2*rand(1,D).*(eliteVector-x_i);
    return
end
c1=2*p.cognitiveShare;
c2=2*(1-p.cognitiveShare);
if strcmp(p.learnMode,'B2')&&exploreFlag
    rows=eliteIdxList(randi(numel(eliteIdxList),1,D));
    exemplar=reshape(pbestAll(sub2ind(size(pbestAll),rows(:),(1:D)')),1,D);
else
    exemplar=eliteVector;
end
trialVelocity=inertia*vel_i+c1*rand(1,D).*(pbest_i-x_i)+c2*rand(1,D).*(exemplar-x_i);
end


