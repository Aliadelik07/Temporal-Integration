function setparallelport(varargin)
% SETPARALLELPORT  Set parallel port for input or output.
%    SETPARALLELPORT IN  sets // port to receive data.
%
%    SETPARALLELPORT OUT  sets // port to send data.
%
%    SETPARALLELPORT(n,'IN'|'OUT')  sets LPTn.  Programmer note: Use always this syntax inside
%    a CosyGraphics function, to avoid 1) a bug if more than one port open and 2) unusefull displays.

% Execution time: 29 ms (Matlab 7.5, Athlon X2 4400+)

% Input args
nargchk(1,2,nargin);
Direction = varargin{end};

% Check 'Direction' validity. 
switch lower(Direction)
    case 'in',  Direction = 'In';   % (Object properties..
    case 'out', Direction = 'Out';  % ..are case sensitive.)
    otherwise   error('Invalid Direction argument.');
end
        
% Get dio
switch nargin
    case 1, [dio,s] = getparallelportobject;
    case 2, [dio,s] = getparallelportobject(varargin{1});
end

% Set dio
if ~isempty(dio)
%     for i = 1:8, s.Line(i).Direction = Direction; end
    warning('off','daq:daqmex:portNotLineConfigurable')
    dio.Line.Direction = Direction;
    warning('on','daq:daqmex:portNotLineConfigurable')
else
    error('No open port. Use OPENPARALLELPORT.');
end

% Command line use: display dio
if ~nargout && nargin < 2
    disp(dio)
end