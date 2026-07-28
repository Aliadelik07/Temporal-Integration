function dio = openparallelport(varargin)
% OPENPARALLELPORT  Open and initialize parallel port.
%    OPENPARALLELPORT OUT  if a standard // port (LPT1) exists and is not already open, opens  
%    it and initializes it to send data. If the port is already open, simply sets direction. 
%    Use SENDPARALLEBYTE to output a byte.
%
%    OPENPARALLELPORT IN  opens the // port and initializes it to receive data.
%    Use GETPARALLEBYTE to read the current port status.
%
%    OPENPARALLELPORT(PortAddress, 'in'|'out')  specifies port's memory address. This allows
%    to use non-stadard // port (port on PCI-Express cards). Note that Matlb's Daq toolbox doesn't
%    support non-standards ports, so in this case we'll use an independant library: InpOut32.dll.
%
%    dio = OPENPARALLELPORT('IN'|'OUT')  returns the port's digitalio object. (See Daq toolbox help.)
%
% Examples: 
%    openparallelport out       % opens LPT1 for output.
%    openparallelport in        % opens LPT1 for input.
%
% See also: SENDPARALLELBYTE, GETPARALLELBYTE, CLOSEPARALLELPORT.
%
% Ben,  Nov 2007  v1.0 
%       Feb 2009. v2.0

% Deprecated syntax: 
%    OPENPARALLELPORT  <Danger en cas de bricolages ==> Le port // est normalement initialisï¿½ 'in' par dï¿½faut>
%    OPENPARALLELPORT(Directions)  initializes the // port with directions given by the cell array
%    of strings Directions. This will work only if your port is line configurable. <Does it work on
%    any // port ???> <TODO: Test this.>

%_______________________________________________________________________________
%% <v2-beta9> Programmer Note: Optimization: 
% (source: http://psychtoolbox.org/wikka.php?wakka=FaqTTLTrigger)
% Cris Niell of Stryker lab found that matlab's public digitalio methods putvalue/getvalue can be 
% accelerated from ~1ms to ~20us by caching out the value of daqgetfield(dio,'uddobject'):
% 
% dio = digitalio('parallel')
% addline(dio,7,0,'out')   %pin 9
% putvalue(dio,1)          %~700 µs
% putvalue(dio.Line,1)    %~150 µs
% uddobj = daqgetfield(dio,'uddobject')
% putvalue(uddobj,1,1); %~20 µs (undocumented use demo in @dioline\putvalue.m and @digitalio\putvalue.m - args are: uddobj, vals [, lineInds])
% getvalue(uddobj,1);    %~20 µs (undocumented use demo in @dioline\getvalue.m and @digitalio\getvalue.m - args are: uddo
% <ben: Don't understand last input arg. Is not necessary.>

% Optimization level:
%                                                            6.5 (AthlonX2)  7.5 (AthlonX2)
% 0:   putvalue(getparallelportobject,value); <v2-beta8>             305 µs          1950 µs
% 0.5: putvalue(dio,value)                                     190 µs           425 µs
% 1:   putvalue(dio.Line,value)                                375 µs          1305 µs
% 1.5: putvalue(Line,value)                                    253 µs           470 µs
% 2:   putvalue(uddobj,value)                                  crash!           245 µs
%
% Conclusion: Best choices are:
% - Matlab 6.5:  COSY_PARALLELPORT.OptimizationMode = 0.5;
% - Matlab 7.5:  COSY_PARALLELPORT.OptimizationMode = 2;
%ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½

global COSY_PARALLELPORT

%% Check OS
if ~ispc
    if IsOSX, wrn = 'There is no parallel port on a Mac.  Calls to the // port will simply be ignored.';
    else      wrn = 'MATLAB supports the parallel port only on MS-Windows.  Calls to the // port will simply be ignored.';
    end
  %  dispinfo(mfilename,'warning',wrn); 
    warning('Cannot open parallel port.')
    return % <---!!!
end

%% Check dependency: daq toolbox required <v2-beta33>
%if isempty(which('digitalio'))
%    error('Data Acquisition Toolbox is not installed.  Without this toolbox you cannot access the parallel port.')
%end

%% Global var
try COSY_PARALLELPORT.PortNum; catch COSY_PARALLELPORT.PortNum = []; end
try COSY_PARALLELPORT.PortObject; catch COSY_PARALLELPORT.PortObject = {}; end

%% Input args
PortNum = 1;
PortName = 'LPT1';
Direction = 'out';
if nargin >= 1
    if isnumeric(varargin{1}), 
        PortNum = varargin{1};
        PortName = ['LPT' int2str(PortNum)];
    elseif ischar(varargin{1}) 
        if strncmpi(varargin{1},'LPT',3)
            PortName = varargin{1};
            PortNum = str2num(varargin{1}(4:end));
            varargin(1) = [];
        end
    else
        if isopen('cosygraphics'), stopcosy; end
        error('Invalid argument.')
    end
end
if ~isempty(varargin)
    if strcmpi(varargin{1},'IN') || strcmpi(varargin{1},'OUT')
        Direction = varargin{1}; 
    else
        if isopen('cosygraphics'), stopcosy; end
        error('Invalid argument.')  
    end
end
% if ischar(Direction), Direction = repmat({Direction},1,8); end  % <suppr.: // port not line configurable.>

%% Check already open port
iPort = find(COSY_PARALLELPORT.PortNum == PortNum);

if iPort % Port already open..
%     [dio,s] = getparallelportobject(PortNum);
    setparallelport(PortNum,Direction);
end

%% Open Port
if isempty(iPort) % Port not yet open, or just closed because directions change..
    iPort = length(COSY_PARALLELPORT.PortNum) + 1;

    disp(' ')
%    dispinfo(mfilename,'info',['Opening parallel port for ' Direction 'put...'])
    try
        dio = digitalio('parallel',PortName);
    catch
        COSY_PARALLELPORT = []; % <v2-beta9, TODO: check this !!!>
        disp(lasterr)
        warning('Cannot open parallel port. (Probably your computer doesn''t have one, or the port is used by another program.)')
        return % <===!!!
    end
    addline(dio,0:7,Direction);
    try sendparallelbyte(0); end % Set lines status to 0 and define COSY_PARALLELPORT.CurrentByte.
    COSY_PARALLELPORT.PortNum(iPort) = PortNum;
    COSY_PARALLELPORT.Direction{iPort} = lower(Direction);
    COSY_PARALLELPORT.PortObject{iPort} = dio;
    COSY_PARALLELPORT.PortLine{iPort} = dio.Line;
    v = version;
    try % Matlab 7.5
        COSY_PARALLELPORT.PortUddObject{iPort} = daqgetfield(dio,'uddobject'); % For optim. purpose, see "Programmer Note" above
        COSY_PARALLELPORT.OptimizationMode = 2;
    catch % Matlab 6.5
        COSY_PARALLELPORT.OptimizationMode = 0.5;
    end
end

%% Clear output if not requested
% digiltalio objects cause trouble with save() function.
if nargout == 0
    clear dio
end