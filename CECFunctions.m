function [f,lb,ub,name] = CECFunctions(id,D)
    switch id
        case 1
            name='Sphere';
            f=@(x)sum(x.^2);
            lb=-100*ones(1,D); ub=100*ones(1,D);
        case 2
            name='Rastrigin';
            f=@(x)10*D+sum(x.^2-10*cos(2*pi*x));
            lb=-5.12*ones(1,D); ub=5.12*ones(1,D);
        case 3
            name='Rosenbrock';
            f=@(x)sum(100*(x(2:end)-x(1:end-1).^2).^2+(x(1:end-1)-1).^2);
            lb=-30*ones(1,D); ub=30*ones(1,D);
        case 4
            name='Ackley';
            f=@(x)-20*exp(-0.2*sqrt(sum(x.^2)/D)) ...
                -exp(sum(cos(2*pi*x))/D)+20+exp(1);
            lb=-32.768*ones(1,D); ub=32.768*ones(1,D);
        case 5
            name='Griewank';
            f=@(x)sum(x.^2)/4000-prod(cos(x./sqrt(1:D)))+1;
            lb=-600*ones(1,D); ub=600*ones(1,D);
        case 6
            name='Elliptic';
            weights=(1e6).^((0:D-1)/max(1,D-1));
            f=@(x)sum(weights.*x.^2);
            lb=-100*ones(1,D); ub=100*ones(1,D);
        otherwise
            error('Unknown CEC function ID.');
    end
end
