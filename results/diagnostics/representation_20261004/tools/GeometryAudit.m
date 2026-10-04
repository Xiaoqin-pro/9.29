function GeometryAudit
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
base=load(fullfile(root,'results','peaks','N6_wide','main_result.mat'));
model=base.model;state=base.state;N=model.nOrders;route=base.Best.Route;
keys=zeros(1,N);keys(route)=linspace(.05,.95,N);
control=zeros(N+1,1,3);control(:,:,1)=.5;control(:,:,2)=.5;control(:,:,3)=0;
[~,straight]=Fitness([keys control(:)'],model,state);
paths=base.Best.Detail.paths;direct=straight.paths;
ratios=zeros(numel(paths),1);collisions=zeros(numel(paths),1);terrain=zeros(numel(paths),1);
for i=1:numel(paths)
 ratios(i)=paths{i}.distance/direct{i}.distance;
 collisions(i)=direct{i}.obstacleViolation;terrain(i)=direct{i}.terrainViolation;
end
report=table((1:numel(paths))',ratios,collisions,terrain,'VariableNames',{'Leg','DetourRatio','DirectObstacleCount','DirectTerrainViolation'});
writetable(report,fullfile(out,'N6_geometry_audit.csv'));
% Add one exactly redundant control point to every K1 path: K2 can express it safely.
model.nControlPoints=2;C=zeros(N+1,2,3);
for i=1:N+1
 c=reshape(base.Best.Control(i,1,:),1,3);
 if c(1)<=.6
  C(i,1,:)=c;C(i,2,:)=[(1+c(1))/2 c(2)/2 c(3)/2];
 else
  C(i,1,:)=[c(1)/2 c(2)/2 c(3)/2];C(i,2,:)=c;
 end
end
C(:,:,1)=(C(:,:,1)-.2)/.6;C(:,:,2)=(C(:,:,2)+15)/30;C(:,:,3)=C(:,:,3)/12;
[cost,detail]=Fitness([keys C(:)'],model,state);
assert(detail.feasible&&abs(detail.distance-base.Best.Detail.distance)<1e-9);
fprintf('PASS K2 can exactly represent the current K1 safe path within same variable bounds; K2 does not automatically make it prettier.\n');
fprintf('Direct legs obstacle-blocked=%d terrain-blocked=%d (overlap possible), optimized detour ratios min%.3f max%.3f.\n', ...
 sum(collisions>0),sum(terrain>0),min(ratios),max(ratios));
save(fullfile(out,'geometry_audit.mat'),'report','detail');
end
