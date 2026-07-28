function t0 = pollparallelport(varargin)
% STARTPARALLELPORTPOLLING  Parallel port polling using a Matlab timer object. <unfinished> <OBSOLETE?>
%    STARTPARALLELPORTPOLLING  starts polling of // port that has been open by OPENPARALLELPORT.
%    ...
%
%    STARTPARALLELPORTPOLLING(dt)  polls every dt milliseconds. Minimum dt value is 1, which is also
%    the default value.
%
%    STARTPARALLELPORTPOLLING(n,dt)  polls LPTn every dt milliseconds.

global COSY_PARALLELPORT 

% Direct call or Recursive call (callback) ?
if nargin && strcmp(varargin{1},'callback'), isRecursiveCall = 1;
else                                         isRecursiveCall = 0;
end

if ~isRecursiveCall % User call
    % Check that // port is open
    if isempty(COSY_PARALLELPORT) % Port is not open.
        error('Parallel port not open. See OPENPARALLELPORT.')
    end
    
    % Input args
    s = propinfo(getparallelportobject,'TimerPeriod');
    MinTimerPeriod = s.ConstraintValue(1);
    
    if nargin >= 1
        TimerPeriod = varargin{1} / 1000;
        if TimerPeriod < MinTimerPeriod
            error(['Minimum dt value = ' num2str(MinTimerPeriod*1000) '.']);
        end
    else
        TimerPeriod = MinTimerPeriod;
    end
    
    if nargin >= 2
        PortNum = varargin{1};
    else
        PortNum = COSY_PARALLELPORT.PortNum(end);
    end
    
    % Start Polling
    setparallelport in;

    dio = getparallelportobject(PortNum);

%     set(dio,'TimerFcn',{@pollparallelport,'callback'})
    set(dio,'TimerFcn',@getparallelbyte)
    set(dio,'TimerPeriod',TimerPeriod)
    
    if strcmp(get(getparallelportobject,'Running'),'Off')
        start(dio)
    end
    
else % Recursive call (Callback)
    disp('jhhj')

end