function test_CSO_quota_candidate
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_project(true);
old=cd(fullfile(root,'data','cec2017'));cleanup=onCleanup(@()cd(old));D=50;lb=-100*ones(1,D);ub=100*ones(1,D);pairs=0;
for seed=[2201,2202]
 rng(21701012+seed);p0=lb+rand(50,D).*(ub-lb);
 for budget=[50,51,151,1151,6000]
  for fid=[1,6,13,30]
   state=struct('initialPopulation',p0,'lowerBound',lb,'upperBound',ub,'maxEvaluations',budget,'modePolicy','gateq','modeState','stagnation','stagnationThreshold',1000,'episodeFE',100,'rewardBonus',10,'logTrajectory',true);
   f=@(x)CEC2017Function(x,fid);[B0,T0,I0]=ASE_CSO_ModeQ_EpisodeBonus(f,state,[],50,seed+1000000);R0=rng;
   [B,T,I]=ASE_CSO_QuotaQ_Candidate(f,state,[],50,seed+1000000);
   assert(isequal(B0,B)&&isequal(T0,T)&&isequal(R0,rng)&&isequal(I0.QTable([2,4,6],:),I.QTable)&&isequal(I0.QVisits([2,4,6],:),I.QVisits)&&isequal(I0.DecisionLog(:,[1,2,4:14]),I.DecisionLog(:,[1,2,4:14]))&&isequal(size(I.QTable),[3,3]));pairs=pairs+1;
  end
 end
end
out=fullfile(root,'work','quota_q_compact_20261012');fid=fopen(fullfile(out,'candidate_entry_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('CandidateExactPairs',pairs,'QShape',[3,3],'Passed',true),PrettyPrint=true));fclose(fid);fprintf('PASS pinned candidate exact%d%c',pairs,10);
end
