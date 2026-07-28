function [dio,s] = getparallelportobject(Port)
% GETPARALLELPORTOBJECT  Get parallel port digital I/O object. (Don't use directly.)
%    GETPARALLELPORTOBJECT  displays infos on all open // port.
%
%    DIO = GETPARALLELPORTOBJECT  returns the digitalio object (see DAQ toolbox documentation) of port
%    open with OPENPARALLELPORT. (If there is more than one, selects last open port.)
%
%    [DIO,S] = GETPARALLELPORTOBJECT  returns object's properties in structure S. Same as S=get(DIO); 
%   
%    Programmer note: Don't use GETPARALLELPORTOBJECT syntax inside a function. Use GETPARALLELPORTOBJECT(n) to
%    avoid unsusefull displays.
%
% See also: OPENPARALLELPORT, DIGITALIO.

% Obsolete syntax:
%    DIO = GETPARALLELPORTOBJECT('LPT#')  selects LPTn.       <DAQ toolbox does not support ports other than LPT1>

global COSY_PARALLELPORT

%% Input Args
if nargin
    if ischar(Port)
        PortName = Port;
        PortNum = str2double(PortName(end));
    elseif isnumeric(Port)
        PortName = ['LPT' int2str(Port)];
        PortNum = Port;
    end
    
else
    PortName = 'LPT1';
    PortNum  = 1;
end

%% Init Output Args
dio = [];
s = [];

%% Get DIO
if isopen('parallelport')  % If // port open..
    iPort = find(COSY_PARALLELPORT.PortNum == PortNum);
    
    if length(iPort) > 1 && ~nargout
        for n = COSY_PARALLELPORT.PortNum(1:end-1)
            getparallelportobject(n)
        end

    elseif iPort % If requested // port open..
        dio = COSY_PARALLELPORT.PortObject{iPort};
        s = get(dio);
    end

end

%% Command Line Output
if ~nargin && ~nargout % Command line use..
    if isopen('parallelport')
        disp([10 PortName ':' 10])
        disp(s)
    else
        clear dio
        disp('No parallel port open.')
    end
end