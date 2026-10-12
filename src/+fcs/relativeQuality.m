function [signal,threshold]=relativeQuality(firstCost,anchorFitness,eliteCount)
% First REAL candidate versus the REAL accepted-fitness quantile; ties included.
assert(isscalar(firstCost) && isfinite(firstCost) && all(isfinite(anchorFitness)));
assert(eliteCount>=1 && eliteCount<=numel(anchorFitness) && eliteCount==floor(eliteCount));
ordered=sort(anchorFitness);threshold=ordered(eliteCount);signal=(firstCost<=threshold);
end
