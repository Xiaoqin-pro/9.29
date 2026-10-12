function [Q,target]=updateCredit(Q,state,action,reward,nextState,allowed,gamma,alpha,terminal)
% One recorded action reward; only executable next actions enter bootstrap.
if terminal,target=reward;
else,assert(any(allowed));target=reward+gamma*max(Q(nextState,logical(allowed)));end
Q(state,action)=Q(state,action)+alpha*(target-Q(state,action));
end
