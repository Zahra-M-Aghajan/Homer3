function [r, toolboxes] = checkToolboxes(appname, options)
% 
% Syntax:
%   [r, toolboxes] = checkToolboxes(appname)
%   [r, toolboxes] = checkToolboxes(appname, options)
%
% Description:
%   Checks if toolboxes required by application in the current
%   folder are installed. It returns 1 if all required toolboxes are
%   installed, 0 if some or all required toolboxes are not installed, and -1
%   if the operation to discover which toolboxes are needed and whether they are 
%   installed failed     

%   It first checks for the presense of the toolboxesRequired.txt file
%   for the list of required toolboxes to check for. If this file
%   does not exist, then it prompts the user to generate this file.
% 
%   NOTE: If generating toolboxesRequired.txt, make sure that this is done
%   with a full suite of Matlab toolboxes installed. This is because the discovery 
%   portion will NOT tell you that a toolbox is being used by your code 
%   UNLESS that toolbox is installed. Therefore there is no other way to tell
%   which toolboxes are required other than to first generate toolboxesRequired.txt 
%   in Matlab installation that has all toolboxes. 
%
%   The file toolboxesRequired.txt can be generated by calling checkToolboxes with 
%   the options argument set to 'regeneratelist'. 
%
% Examples:
%
%   [r, toolboxes] = checkToolboxes('Homer3')
%   [r, toolboxes] = checkToolboxes('AtlasViewerGUI','regeneratelist')
%
if nargin==0
    return;
end
if nargin==1
    options = '';
end

% User might want to regenrate list of toolboxes if new scripts were added
% which might require new toolboxes.
if optionExists(options, 'regeneratelist')
    if exist('./toolboxesRequired.txt', 'file')==2
        delete('./toolboxesRequired.txt');
    end
end

toolboxes = {};

header{1} = sprintf('==================================================\n');
header{2} = sprintf('List of required toolboxes for %s (v%s):\n', appname, version2string);
header{3} = sprintf('==================================================\n');

% Check for presence of file which already has all the toolboxes
if exist('./toolboxesRequired.txt', 'file')==2
    fid = fopen('./toolboxesRequired.txt');
    if(fid > 0)
        for ii=1:length(header)
            fprintf(header{ii});
        end
        kk=1;
        while 1
            line = fgetl(fid);
            if line==-1
                break;
            end
            toolboxes{kk,1} = line; %#ok<*AGROW>
            fprintf('%s\n', toolboxes{kk});
            kk=kk+1;
        end
        fclose(fid);
        fprintf('\n');
        r = toolboxesExist(toolboxes);
        return;
    end
end

if verLessThan('matlab','8.3')
    r = -1;
    return;
end

msg{1} = sprintf('Unable to find required toolbox list for the current Matlab release. ');
msg{2} = sprintf('Do you want to run toolbox discovery to determine which are required? ');
msg{3} = sprintf('(It takes 5-10 minutes).');
q = MenuBox([msg{:}], {'YES','NO'});
if q==2
    r = -1;
    return;
elseif q==1
    msg{1} = sprintf('NOTE: Generating a new list of required toolboxes will miss toolboxes that are ');
    msg{2} = sprintf('used by your code unless they are already installed on your computer. '); 
    msg{3} = sprintf('Please make sure that this operation is performed in a Matlab installation with '); 
    msg{4} = sprintf('a full suite (or at least nearly-full suite) of toolboxes. Do you want to proceed?\n');
    q = MenuBox([msg{:}], {'YES','NO'});
    if q==2
        r = -1;
        return;
    end
end

exclList = {};

% Change curr folder to application root folder
currdir = pwd;
cd(strcat(pwd,'\Utils'));
if ~exist('dirnameApp','var') || isempty(dirnameApp)
    dirnameApp = ffpath('setpaths.m');
end
if dirnameApp(length(dirnameApp))~='/' && dirnameApp(length(dirnameApp))~='\'
    dirnameApp(length(dirnameApp)+1)='/';
end
cd(dirnameApp);

% Find all the .m files for application
files = findDotMFiles('.', exclList);
nFiles = length(files);

hwait = waitbar(0, sprintf('Checking toolboxes for %d source files', nFiles));
for ii=1:nFiles
    fprintf('Checking ''%s'' for required toolboxes ...\n', files{ii});
    
    % Searching for application toolboxes takes a long time, so it was done
    % beforehand and is already included in toolboxes.
    [~,f,~] = fileparts(files{ii});
    if strcmp(f, appname)
        continue;
    end
    
    [~, q] = matlab.codetools.requiredFilesAndProducts(files{ii});
    for jj=1:length(q)
        if ~strcmpi(q(jj).Name, 'MATLAB')
            if ~strcellfind(toolboxes, q(jj).Name)
                fprintf('Adding ''%s'' to list of required toolboxes\n', q(jj).Name);
                toolboxes{end+1,1} = q(jj).Name;
            end
        end
    end
    waitbar(ii/length(files), hwait, sprintf('Checked %d of %d files', ii, nFiles));
end
close(hwait);
fprintf('\n');

cd(currdir);

fid = fopen('./toolboxesRequired.txt','wt');
for ii=1:length(header)
    fprintf(header{ii});
end
for jj=1:length(toolboxes)
    line = sprintf('%s\n', toolboxes{jj});
    fprintf(fid, line);
    fprintf(line);
end
fprintf('\n');
fclose(fid);

r = toolboxesExist(toolboxes);



% -------------------------------------------------------------------------
function r = toolboxesExist(toolboxes)
r = true;
missing = [];
kk = 1;
for ii=1:length(toolboxes)
    if ~isToolboxAvailable(toolboxes{ii})
        missing(kk) = ii;
        kk=kk+1;
    end
end
if ~isempty(missing)
    msg1 = sprintf('WARNING: The following matlab toolboxes have not been installed:\n');
    msg2 = sprintf('\n');
    msg3 = '';
    msg4 = sprintf('\n');
    msg5 = sprintf('SOME FUNCTIONS MAY NOT WORK PROPERLY.');
    for jj=1:length(missing)
        if isempty(msg3)
            msg3 = sprintf('%s\n', toolboxes{missing(jj)});
        else
            msg3 = sprintf('%s%s\n', msg3, toolboxes{missing(jj)});
        end
    end    
    msg = [msg1, msg2, msg3, msg4, msg5];
    menu(msg, 'OK');
    r = false;
end

