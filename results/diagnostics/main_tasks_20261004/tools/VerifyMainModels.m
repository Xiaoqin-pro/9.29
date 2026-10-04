function VerifyMainModels
root='D:\111\Desktop\噜噜\9.29';addpath(root);out=fileparts(mfilename('fullpath'));
text=fileread(fullfile(root,'main.m'));a=strfind(text,'cfg.threatFile =');b=strfind(text,'if ~runComparison');eval(text(a(1):b(1)-1));
names={'N10_wide','N10_tight','N15_wide','N15_tight','N20_wide','N20_tight'};ns=[10 10 15 15 20 20];
cfg.nControlPoints=2;
for number=1:6
 cfg.nOrders=ns(number);cfg.stationFile=fullfile(out,'input',[names{number} '.csv']);
 for map=1:3
  cfg.terrainType=map;model=CreateModel(cfg);xyz=reshape([model.orders.xyz],3,[])';ground=interp2(model.X,model.Y,model.terrainZ,xyz(:,1),xyz(:,2));
  assert(max(abs(xyz(:,3)-ground-8))<1e-10);
  assert(model.minClearance==4&&model.maxAltitude==42&&model.maxClimbAngle==25&&model.maxTurnAngle==120);
  if map==1,xy=reshape([model.orders.xy],2,[])';tw=[[model.orders.ready];[model.orders.due]];
  else,assert(isequal(xy,reshape([model.orders.xy],2,[])')&&isequal(tw,[[model.orders.ready];[model.orders.due]]));end
  if map==2,save(fullfile(out,'input',[names{number} '_model.mat']),'model');end
 end
end
previous=[];
for n=[10 15 20]
 wide=readmatrix(fullfile(out,'input',sprintf('N%d_wide.csv',n)));tight=readmatrix(fullfile(out,'input',sprintf('N%d_tight.csv',n)));
 assert(isequal(wide(:,[1:3 6:9]),tight(:,[1:3 6:9])));
 assert(all(wide(:,4)<=tight(:,4))&&all(wide(:,5)>=tight(:,5)));
 assert(all(ismember(previous,wide(:,1))));previous=wide(:,1);
end
fprintf('PASS expanded nested N10/15/20, heterogeneous external appointments, three unchanged terrain models.\n');
end
