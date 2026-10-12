function diagnose_CSO_Q_lower_init
root=fileparts(fileparts(mfilename('fullpath')));dirs=dir(fullfile(root,'results','cec','cso_q_initial_value_study_*'));assert(~isempty(dirs));[~,ix]=max([dirs.datenum]);dataDir=fullfile(dirs(ix).folder,dirs(ix).name);raw=readtable(fullfile(dataDir,'raw_runs.csv'),'TextType','string');raw=raw(raw.Condition=="LowerInit-effQ",:);out=fullfile(root,'results','cso_q_learning_20261012');if ~isfolder(out),mkdir(out);end
all=cell(height(raw),1); summaries=cell(height(raw),1);
for j=1:height(raw)
 r=raw(j,:);d=load(fullfile(dataDir,'runs',sprintf('job_%04d.mat',r.JobID)));L=d.I.DecisionLog;U=d.I.UpdateLog;Q=-10*ones(6,3);V=zeros(6,3);stream=RandStream('mt19937ar','Seed',r.SearchSeed+3000001);records=zeros(size(L,1),15);lastAction=zeros(6,1);lastReward=nan(6,1);
 for k=1:size(L,1)
  if k>1
   u=U(k-1,:);if u(8),s=u(1);a=u(2);Q(s,a)=Q(s,a)+.1*(u(3)+.9*max(Q(u(4),:))-Q(s,a));V(s,a)=V(s,a)+1;end
   lastReward(u(1))=u(3);
  end
  s=L(k,3);values=Q(s,:);visits=V(s,:);ordered=sort(values,'descend');winners=find(values==max(values));explore=rand(stream)<.1;
  if explore,selected=randi(stream,3);else,selected=winners(randi(stream,numel(winners)));end
  assert(selected==L(k,4),'Policy replay RNG/action mismatch.');
  changed=lastAction(s)>0&&lastAction(s)~=selected;least=visits(selected)==min(visits);optimistic=~explore&&visits(selected)==0&&any(values<0);
  records(k,:)=[r.FunctionID,r.Seed,k,s,L(k,6),selected,explore,numel(winners),ordered(1)-ordered(2),changed,least,optimistic,visits(selected),lastReward(s),L(k,10)];lastAction(s)=selected;
 end
 u=U(end,:);if u(8),s=u(1);a=u(2);Q(s,a)=Q(s,a)+.1*(u(3)-Q(s,a));V(s,a)=V(s,a)+1;end
 assert(isequal(Q,d.I.QTable)&&isequal(V,d.I.QVisits));
 all{j}=array2table(records,'VariableNames',{'FunctionID','Seed','Decision','State','Phase','Action','Exploration','TieCount','GreedyGap','SwitchedOnStateRevisit','ChosenLeastVisited','OptimisticUnvisited','ChosenVisits','PreviousStateReward','CurrentReward'});
 exploit=records(:,7)==0;summary=struct('FunctionID',r.FunctionID,'Seed',r.Seed,'ExploreRate',mean(~exploit),'ExploitSwitchRate',mean(records(exploit,10)),'MeanGreedyGap',mean(records(:,9)),'MedianGreedyGap',median(records(:,9)),'GapBelow01Rate',mean(records(:,9)<.1),'LeastVisitedOnExploitRate',mean(records(exploit,11)),'OptimisticUnvisitedCount',sum(records(:,12)),'PositiveRewardRate',mean(records(:,15)>0));summaries{j}=summary;
end
writetable(vertcat(all{:}),fullfile(out,'lower_init_choice_replay.csv'));writetable(struct2table([summaries{:}]),fullfile(out,'lower_init_learning_summary.csv'));
fid=fopen(fullfile(out,'lower_init_replay_checks.json'),'w');fprintf(fid,'%s',jsonencode(struct('Runs',height(raw),'Decisions',height(vertcat(all{:})),'ExactPolicyRNGReplay',true,'ExactQReplay',true),PrettyPrint=true));fclose(fid);fprintf('PASS learning replay %d runs\n',height(raw));
end
