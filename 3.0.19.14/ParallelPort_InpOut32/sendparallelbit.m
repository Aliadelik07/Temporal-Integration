function t = sendparallelbit(lines,bit,duration)
% SENDPARALLELBIT  Change state of parallel port's line(s).
%    t = SENDPARALLELBIT(lines,bit)  sets output line(s) value.  'lines' is a Matlab line
%    number between 1 and 8, or a vector of line numbers.  'bit' can be 0 or 1.

% Running time: 240 µsec on DARTAGNAN, on Matlab 7.5.

%% Global Vars
global COSY_PARALLELPORT

if isempty(COSY_PARALLELPORT)
    error('Parallel port not open. See OPENPARALLELPORT.')
end

%% Input Args
iPort = 1;

% <old code, before 2-beta51>
% if nargin == 2
%     iPort = 1;
% elseif nargin == 2
%     iPort = varargin{1};
% else
%     error('Wrong number of arguments.')
% end
% 
% lines = varargin{end-1};
% bit = varargin{end};

if any(lines < 1) || any(lines > 8)
    error('Invalid input argument. Line numbers must be integers between 1 and 8.')
end
if ~all(bit == 0 | bit == 1)
    error('Invalid input argument. Line values must be 0s or 1s.')
end

%% Put Value
% old = COSY_PARALLELPORT.CurrentByte;
% b = 2^(lines-1) .* bit;
% new = floor(old/2^lines)*2^lines + b + rem(old,2^(lines-1));

putvalue(COSY_PARALLELPORT.PortLine{iPort}(lines), bit);
t = time;

%% Print event in command window
if bit > 0
    helper_dispevent(mfilename, sprintf('Set parallel line(s) %s  to %d.',num2str(lines),bit), t);
end