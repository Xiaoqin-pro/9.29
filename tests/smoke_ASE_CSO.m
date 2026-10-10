function smoke_ASE_CSO
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root); setup_project(true);
for D=[30 100]
    for budget=[50 51 53 600]
        compare_frozen_pair(D,0,41,budget,false);
    end
end
disp('Frozen implementation smoke regression: all cases passed.');
end
