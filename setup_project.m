function root=setup_project(includeHistory)
% Configure the frozen implementation. Historical experiments are opt-in.
if nargin==0,includeHistory=false;end
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'tests'), ...
    fullfile(root,'data','cec2017'));
legacy=fullfile(root,'archive','legacy');
if includeHistory && isfolder(legacy),addpath(legacy,'-end');end
end
