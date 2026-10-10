function row=D3HierarchyPostTrace(row,context,pool,best,center,candidateSelector)
% Reference drift only: no hypothetical Seeking evaluations are performed.
    plan=cell(numel(pool),1); slots=context.Quota;
    for i=context.OldIds(:)'
        plan{i}=candidateSelector(pool{i},best,center,min(2,slots));
        slots=slots-numel(plan{i});
        if slots==0,break,end
    end
    hits=0;
    for i=1:numel(plan)
        hits=hits+numel(intersect(plan{i},context.OldPlan{i}));
    end
    row.TraceChangedBest=double(~isequal(best,context.OldBest));
    row.OldPostTraceOverlap=hits/context.Quota;
    row.ExplorerFarEvaluatedPostTrace= ...
        double(ismember(context.FarCandidate,plan{context.Explorer}));
end
