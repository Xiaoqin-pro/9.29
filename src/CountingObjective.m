classdef CountingObjective < handle
    %COUNTINGOBJECTIVE Independent objective-call counter for baseline audits.
    properties
        Fun
        Calls = 0
    end
    methods
        function obj = CountingObjective(fun)
            obj.Fun = fun;
        end
        function value = evaluate(obj, position)
            obj.Calls = obj.Calls + 1;
            value = obj.Fun(position);
        end
    end
end
