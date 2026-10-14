function test_SAQ_CSO_EliteProbe
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));addpath(fullfile(root,'archive','legacy'));
out=fullfile(root,'work','saq_elite_probe_validation_20261014');if ~isfolder(out),mkdir(out);end
D=7;N=50;lb=-100*ones(1,D);ub=100*ones(1,D);rng(123,'twister');p0=lb+rand(N,D).*(ub-lb);
points=[];objectiveMode='sphere';checks=cell(0,1);
base=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',1250,...
 'policy','base','acceptance','replace','audit',true);
for b=[50 51 52 55 59 61 1250]
 s=base;s.maxEvaluations=b;points=[];
 [B,T,I]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);captured=points;
 assert(size(captured,1)==b && I.Evaluations==b && numel(T)==b && all(diff(T)<=0));
 r=s;r.modePolicy='fixed6';r.modeTraceQuota=6;r.auditSimplify=true;points=[];
 [BR,TR,IR]=ASE_CSO_QuotaQ_Compact(@objective,r,[],N,456);
 assert(isequal(captured,points) && isequal(T,TR) && isequal(B,BR));
 assert(isequal(I.EvaluationPoints,captured) && isequal(IR.EvalPoints,points));
 checks{end+1}=struct('Check',sprintf('Fixed6-pointwise-budget-%d',b),'Passed',true);
end
s=base;s.policy='q';s.progressWindowFE=1e9;points=[];
[~,Tq,Iq]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);pq=points;
s.policySeed=999;s.probeSeed=888;points=[];
[~,Tq2,Iq2]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
assert(isequal(points,pq) && isequal(Tq,Tq2) && Iq.ProbeEvaluations==0 && Iq.QUpdates==0 && Iq2.QUpdates==0);
assert(isequal(Tq,TR));checks{end+1}=struct('Check','Masked-Q-and-independent-policy-RNG','Passed',true);

% Controlled optimum: a failed, worse probe must still become a real anchor.
rng(11,'twister');controlled=1e-4*(2*rand(N,D)-1);controlled(1,:)=0;
s=base;s.initialPopulation=controlled;s.policy='rule';s.progressWindowFE=10;s.maxEvaluations=1250;
points=[];[B,T,I]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
assert(size(points,1)==1250 && I.ProbeEvaluations>0 && I.ProbeWritebacks==I.ProbeEvaluations);
assert(any(I.ProbeLog(:,7)>I.ProbeLog(:,6)) && all(T==0) && B.Cost==0 && all(B.Vector==0));
assert(isequal(I.ProbePoints,I.ProbeAfterReal) && isequal(I.ProbePoints,I.ProbeAfterPersonalBest));
assert(all(I.ProbeAfterVelocity==0,'all') && all(I.ProbeLog(:,7)==I.ProbeLog(:,14)) && all(I.ProbeLog(:,7)==I.ProbeLog(:,15)));
assert(max(abs(sum(I.RealPopulation.^2,2)-I.Fitness))<1e-9);
assert(max(abs(sum(I.PersonalBest.^2,2)-I.PersonalBestCost))<1e-9);
assert(all(I.EvaluationPoints>=lb & I.EvaluationPoints<=ub,'all') && I.MaxParentEvaluations<=2);
checks{end+1}=struct('Check','Failed-worse-probe-writes-real-pbest-and-resets-velocity','Passed',true);

s.acceptance='greedy';points=[];[~,~,IG]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
assert(IG.ProbeEvaluations>0 && IG.ProbeWritebacks==IG.ProbeParentSuccesses && IG.ProbeWritebacks<IG.ProbeEvaluations);
assert(isequal(IG.ProbePoints(1,:),I.ProbePoints(1,:)));
checks{end+1}=struct('Check','Greedy-control-rejects-failed-probes','Passed',true);

% Exact partial-round budgets with forced gate and constant objective.
objectiveMode='flat';tail=cell(0,1);
for b=[50 51 52 55 59 61 151 152 155 159 161]
 s=base;s.policy='rule';s.progressWindowFE=10;s.maxEvaluations=b;points=[];
 [B,T,I]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
 assert(size(points,1)==b && I.Evaluations==b && numel(T)==b && all(T==1) && B.Cost==1);
 tail{end+1}=struct('Budget',b,'ActualCalls',size(points,1),'ProbeCalls',I.ProbeEvaluations,'Passed',true);
end
writetable(struct2table([tail{:}]),fullfile(out,'budget_boundaries.csv'));
checks{end+1}=struct('Check','Forced-probe-partial-budget-boundaries','Passed',true);

s=base;s.policy='q';s.progressWindowFE=10;points=[];[~,~,IQ]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
assert(IQ.QUpdates>0 && sum(IQ.QVisits,'all')==IQ.QUpdates && all(isfinite(IQ.QTable),'all'));
assert(all(IQ.WindowLog(IQ.WindowLog(:,8)==0,10)==1));
assert(all(IQ.WindowLog(:,19)<=1) && IQ.ProbeEvaluations==sum(IQ.WindowLog(:,19)));
assert(IQ.UpdateLog(end,5)==1 && IQ.UpdateLog(end,4)==0);
for policy={'rule','random'}
 s.policy=policy{1};points=[];[~,~,IN]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);assert(IN.QUpdates==0);
end
checks{end+1}=struct('Check','Only-Q-learns-feasible-actions-terminal-bootstrap-zero','Passed',true);

% Additive shifts and positive scaling preserve the gate and actual points.
objectiveMode='sphere';s=base;s.policy='rule';s.progressWindowFE=10;s.progressThreshold=1e6;
points=[];[~,~,IA]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);pa=points;
objectiveMode='affine';points=[];[~,~,IB]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);
assert(isequal(pa,points) && isequal(IA.WindowLog(:,7:10),IB.WindowLog(:,7:10)));
checks{end+1}=struct('Check','Gate-invariant-to-objective-shift-and-positive-scale','Passed',true);

% Binary CEC objective: verify pointwise baseline equivalence on three IDs.
oldDir=pwd;cleanup=onCleanup(@()cd(oldDir));cd(fullfile(root,'data','cec2017')); %#ok<NASGU>
for fid=[1 6 9]
 objectiveMode='cec';cecID=fid;rng(101,'twister');p50=-100+200*rand(N,50);
 s=base;s.initialPopulation=p50;s.lowerBound=-100*ones(1,50);s.upperBound=100*ones(1,50);s.maxEvaluations=1050;
 s.policy='base';points=[];[B,T,I]=SAQ_CSO_EliteProbe(@objective,s,[],N,456);pE=points;
 s.modePolicy='fixed6';s.modeTraceQuota=6;points=[];[BR,TR,~]=ASE_CSO_QuotaQ_Compact(@objective,s,[],N,456);
 assert(isequal(pE,points) && isequal(T,TR) && isequal(B,BR) && size(pE,1)==1050 && I.Evaluations==1050);
 checks{end+1}=struct('Check',sprintf('CEC-F%d-D50-pointwise-Fixed6',fid),'Passed',true);
end
writetable(struct2table([checks{:}]),fullfile(out,'checks.csv'));
report=struct('Date','2026-10-14','AllPassed',true,'Checks',numel(checks),'CECChecks',3,'CECPerformanceRuns',0,...
 'EngineSHA256',validationSHA(fullfile(root,'src','SAQ_CSO_EliteProbe.m')),...
 'TestSHA256',validationSHA([mfilename('fullpath') '.m']),'MATLABVersion',version);
fidOut=fopen(fullfile(out,'validation.json'),'w');fprintf(fidOut,'%s',jsonencode(report,PrettyPrint=true));fclose(fidOut);
disp(struct2table([checks{:}]));disp('Elite-probe correctness validation passed.');
 function value=objective(x)
  points(end+1,:)=x;
  switch objectiveMode
   case 'sphere',value=sum(x.^2);
   case 'flat',value=1;
   case 'affine',value=13*sum(x.^2)+1000;
   case 'cec',value=CEC2017Function(x,cecID);
  end
 end
end

function digest=validationSHA(path)
f=fopen(path,'r');bytes=fread(f,inf,'*uint8');fclose(f);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
