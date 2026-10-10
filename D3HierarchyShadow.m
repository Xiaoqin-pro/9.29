function [row,context]=D3HierarchyShadow(pool,ids,best,center,quota,selectors,stream)
% Compare selectors on one frozen pool. No fitness call or global RNG use.
    assert(quota==3 && numel(ids)>=2)
    n=numel(pool);
    near=zeros(numel(ids),1); far=near;
    allNear=[]; allFar=[];
    for q=1:numel(ids)
        points=pool{ids(q)}(2:end,:);
        a=sum((points-best).^2,2); b=sum((points-center).^2,2);
        near(q)=min(a); far(q)=max(b);
        allNear=[allNear;a]; allFar=[allFar;b]; %#ok<AGROW>
    end
    [~,nearOrder]=sort(near);
    [~,farOrder]=sort(far,'descend');
    oldIds=ids(selectors.Cats(near,far,2));
    oldIds=oldIds(randperm(stream,numel(oldIds)));
    oldPlan=SequentialPlan(pool,oldIds,best,center,quota,selectors.Candidate);
    joint2=selectors.Global(pool,oldIds,best,center,quota,2);
    k=min(8,numel(ids));
    wideIds=ids(selectors.Cats(near,far,k));
    joint8=selectors.Global(pool,wideIds,best,center,quota,2);
    globalPlan=selectors.Global(pool,ids,best,center,quota,2);
    pairs=PlanPairs(globalPlan);
    counts=cellfun(@numel,globalPlan);
    assert(sum(counts)==quota && max(counts)<=2)
    for plan={oldPlan,joint2,joint8}
        c=cellfun(@numel,plan{1});
        assert(sum(c)==quota && max(c)<=2)
    end
    explorer=ids(farOrder(1));
    developer=ids(nearOrder(1));
    [~,farCandidate]=max(sum((pool{explorer}(2:end,:)-center).^2,2));
    farCandidate=farCandidate+1;
    candidates=pool{explorer}(2:end,:);
    [~,nearCandidate]=min(sum((candidates-best).^2,2));
    row=struct('FE',0,'RoleParentOverlap',double(developer==explorer), ...
        'K2NumberFallback',2-numel(unique([developer;explorer])), ...
        'ExplorerSelected',double(any(oldIds==explorer)), ...
        'ExplorerFarEvaluatedFrozen',double(ismember(farCandidate,oldPlan{explorer})), ...
        'ExplorerNearFarSame',double(nearCandidate+1==farCandidate), ...
        'OldJoint2Overlap',Overlap(oldPlan,joint2,quota), ...
        'OldGlobalOverlap',Overlap(oldPlan,globalPlan,quota), ...
        'Joint2GlobalOverlap',Overlap(joint2,globalPlan,quota), ...
        'Joint8GlobalOverlap',Overlap(joint8,globalPlan,quota), ...
        'Joint8GlobalEqual',double(isequal(PlanPairs(joint8),pairs)), ...
        'AnyDistanceTie',double(numel(unique(allNear))<numel(allNear) || ...
            numel(unique(allFar))<numel(allFar)), ...
        'OldParentCoverage',nnz(cellfun(@numel,oldPlan)), ...
        'Joint2ParentCoverage',nnz(cellfun(@numel,joint2)), ...
        'Joint8ParentCoverage',nnz(cellfun(@numel,joint8)), ...
        'GlobalParentCoverage',nnz(counts), ...
        'OldConcentration',sum((cellfun(@numel,oldPlan)/quota).^2), ...
        'GlobalConcentration',sum((counts/quota).^2), ...
        'GlobalProductionEqual',0,'TraceChangedBest',0, ...
        'OldPostTraceOverlap',NaN,'ExplorerFarEvaluatedPostTrace',NaN, ...
        'ProductionPlanExecutedEqual',0);
    context=struct('OldIds',oldIds,'OldPlan',{oldPlan}, ...
        'Explorer',explorer,'FarCandidate',farCandidate, ...
        'GlobalPlan',{globalPlan},'OldBest',best,'Quota',quota,'Size',n);
end

function plan=SequentialPlan(pool,ids,best,center,quota,candidateSelector)
    plan=cell(numel(pool),1);
    for i=ids(:)'
        plan{i}=candidateSelector(pool{i},best,center,min(2,quota));
        quota=quota-numel(plan{i});
        if quota==0,break,end
    end
end

function pairs=PlanPairs(plan)
    pairs=zeros(sum(cellfun(@numel,plan)),2); cursor=0;
    for i=1:numel(plan)
        for j=plan{i}
            cursor=cursor+1; pairs(cursor,:)=[i j];
        end
    end
    pairs=sortrows(pairs);
end

function value=Overlap(a,b,quota)
    value=size(intersect(PlanPairs(a),PlanPairs(b),'rows'),1)/quota;
end
