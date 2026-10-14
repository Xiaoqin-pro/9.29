function test_SAQ_CSO_Anchor
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
out=fullfile(root,'work','saq_anchor_validation_20261014');if ~isfolder(out),mkdir(out);end
N=50;D=7;lb=-100*ones(1,D);ub=100*ones(1,D);rng(123);p0=lb+rand(N,D).*(ub-lb);
mode='sphere';points=[];checks=cell(0,1);
s=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1250,...
 'policy','rule','acceptance','replace','screenMode','geometry','audit',true,...
 'progressWindowFE',10,'progressThreshold',1e6);
for budget=[50 51 52 55 59 61 151 152 155 159 161 1250 2050]
 s.maxEvaluations=budget;points=[];[B,T,I]=SAQ_CSO_Anchor(@objective,s,[],N,456);actual=points;
 points=[];[BR,TR,IR]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
 assert(isequal(B,BR)&&isequal(T,TR)&&isequal(actual,points));
 assert(isequal(I.ProbeLog,IR.ProbeLog)&&isequal(I.RoundLog,IR.RoundLog));
 assert(I.Evaluations==budget&&numel(T)==budget);
end
checks{end+1}=struct('Check','Geometry-exact-old-rule-equivalence','Passed',true);
for sm={'anchor','age'}
 s.screenMode=sm{1};s.maxEvaluations=2050;points=[];[B,T,I]=SAQ_CSO_Anchor(@objective,s,[],N,456);
 assert(size(points,1)==2050&&numel(T)==2050&&I.Evaluations==2050);
 assert(all(points>=lb&points<=ub,'all')&&I.MaxParentEvaluations<=2);
 assert(I.ProbeWritebacks==I.ProbeEvaluations);
 assert(strcmp(I.ScreenMode,sm{1}));
 assert(max(abs(sum(I.RealPopulation.^2,2)-I.Fitness))<1e-8);
 assert(max(abs(sum(I.PersonalBest.^2,2)-I.PersonalBestCost))<1e-8);
 checks{end+1}=struct('Check',['Mode-' sm{1} '-budget-bounds-parentcap-and-memory'],'Passed',true);
end
mode='flat';s.screenMode='anchor';s.maxEvaluations=1250;points=[];[B,T,I]=SAQ_CSO_Anchor(@objective,s,[],N,456);
assert(size(points,1)==1250&&all(T==1)&&B.Cost==1);
assert(I.ProbeWritebacks==I.ProbeEvaluations&&all(I.ProbeAfterVelocity==0,'all'));
assert(isequal(I.ProbePoints,I.ProbeAfterReal)&&isequal(I.ProbePoints,I.ProbeAfterPersonalBest));
checks{end+1}=struct('Check','Anchor-flat-probe-writeback-reset','Passed',true);
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
report=struct('AllPassed',true,'Checks',numel(checks),'EngineSHA256',sha(fullfile(root,'src','SAQ_CSO_Anchor.m')),...
 'ReferenceSHA256',sha(fullfile(root,'src','SAQ_CSO_EliteProbe.m')),'MATLABVersion',version);
f=fopen(fullfile(out,'validation.json'),'w');fprintf(f,'%s',jsonencode(report,PrettyPrint=true));fclose(f);
disp(struct2table([checks{:}]));disp('Anchor screening validation passed.');
 function value=objective(x)
  points(end+1,:)=x;
  if strcmp(mode,'flat'),value=1;else,value=sum(x.^2);end
 end
end
function d=sha(path)
f=fopen(path,'r');b=fread(f,inf,'*uint8');fclose(f);m=java.security.MessageDigest.getInstance('SHA-256');m.update(b);d=lower(reshape(dec2hex(typecast(m.digest(),'uint8'),2).',1,[]));
end
