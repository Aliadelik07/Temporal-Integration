function t = sendparallelbyte(value,dur)
% SENDPARALLELBYTE  Change parallel port state.
%    t = SENDPARALLELBYTE(n)  changes states of the parallelport, n is an integer in the range 0:255, 
%    and returns timestamp in milliseconds. 
%
%    t = SENDPARALLELBYTE(bits)  'bits' is a vector of binary values.
%
%    t = SENDPARALLELBYTE(n|bits, duration)  sends given byte, waits 'duration' in milliseconds,  
%    then resets the // port to 0.  This is a blocking function: it'll return after the reset.
%
% Examples:
%       openparallelport out;               % open the port for output (open the 8 lines)
%       t = sendparallelbyte(8)             % set port value to: 0 0 0 0 1 0 0 0
%       wait(1)                             % let line 3 stay high 1 ms
%       sendparallelbyte(0)                 % reset to 0 (all lines low)
%       t = sendparallelbyte([1 0 1])       % set port value to: 0 0 0 0 0 1 0 1
%       wait(1)                             % let lines 0 and 2 stay high 1 ms
%       sendparallelbyte([0 0 0 0 0 0 0 0]) % reset to 0 (all lines low)
%
% Ben,  Nov. 2007	v1.0
%       Dec         v1.3  Fix case when no // port
%       Feb. 2009   v2.0  Rewrite. Fix Matlab 7 critical performance issue.

% <TODO: vertical binvec ???>

% <TODO?? It's not supported by Matlab>
%    SENDPARALLELBYTE(n,...)  send bytes trough LPTn.  <DEPRECATED 19-jul-2011>

global COSY_PARALLELPORT
nargchk(1,2,nargin);

%% Check OS: // port supported only on Windows
if ~ispc
    t = NaN;
    return % <---!!!
end

%% Check that // port is open
if isempty(COSY_PARALLELPORT) % Port is not open.
    if isopen('cosygraphics') % CosyGraphics is running, maybe we are in real-time: impose use of openparallelport.
        dispinfo(mfilename,'warning','Parallel port not open. See OPENPARALLELPORT.')
        t = -1;
        return % <---!!!
    else % CosyGraphics is not running, I suppose that we are not in real-time: let's open the port implicitly.
        openparallelport out
    end
end

%% Input args
PortNum = 1;
% <old code, before 2-beta51>
% if nargin >= 2
%     PortNum = varargin{1};
% else
%     PortNum = COSY_PARALLELPORT.PortNum;
%     if length(PortNum) > 1
%         error(['More than one // port are open.' 10 ...
%             'You must give the port number as first argument to sendparallelbyte.'])
%     end
% end
% 
% value = varargin{end};

if value < 0
    error('SENDPARALLELBYTE: Invalid value. Value cannot be negative.')
elseif value > 255
    warning(sprintf('SENDPARALLELBYTE: Too high value: %d. Value has been clipped to 255.',value))
    value = 255;
end

%% Send byte!
if ~isempty(COSY_PARALLELPORT)
    t0 = time;
    switch getcosylib('ParallelPort')
        case 'DAQ'
            switch COSY_PARALLELPORT.OptimizationMode
                case 0,     putvalue(getparallelportobject(PortNum),value);
                case 0.5,   putvalue(COSY_PARALLELPORT.PortObject{PortNum},value);
                case 1,     putvalue(COSY_PARALLELPORT.PortObject{PortNum}.Line,value);
                case 1.5,   putvalue(COSY_PARALLELPORT.PortLine{PortNum},value);
                case 2,     putvalue(COSY_PARALLELPORT.PortUddObject{PortNum},value);
            end
        case 'InpOut32' % <v3-beta3>
            ParallelPort_InpOut32('output', value);
    end
    t = time;
    COSY_PARALLELPORT.dt = t - t0; % For debug purpose
    
else
    t = 0;
    
end

%% Print event in command window
if value > 0
    helper_dispevent(mfilename, sprintf('Sent parallel byte %s (%d).',dec2bin(value,8),value), t);
end

%% Reset port to 0
if nargin >= 2
    waituntil(t+dur);
    sendparallelbyte(0);  %             <===RECURSIVE-CALL===!!!
end