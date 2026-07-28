function [n,t,bits] = getparallelbyte(PortNum)
% GETPARALLELBYTE  Get parallel port current value.
%    GETPARALLELBYTE  by itself, displays current parallel port value in Command Window.
%
%    [n,t] = GETPARALLELBYTE  returns parallel port current value as an integer n (0 <= n <= 255) 
%    and the the timestamps t.
%
%    [n,t,bits] = GETPARALLELBYTE  returns also current port value as a as a logical vector of bit 
%    values.

%% Global Var
global COSY_PARALLELPORT

if isempty(COSY_PARALLELPORT)
    error('Parallel port not open. See openparallelport.')
end

%% Input Arg
if ~nargin
    PortNum = 1;
end

%% Get Value
t0 = time;

switch getcosylib('ParallelPort')
    case 'DAQ'
        switch COSY_PARALLELPORT.OptimizationMode
            case 0,     binvec = getvalue(getparallelportobject);
            case 1,     binvec = getvalue(COSY_PARALLELPORT.PortObject{PortNum}.Line);
            case 2,     binvec = getvalue(COSY_PARALLELPORT.PortUddObject{PortNum});
        end
        t = time;
        
        %% binvec -> bits
        % 'binvec' element order are inverted: "A binvec
        %      value is a binary vector which is written with the least significant
        %      bit (LSB) as the leftmost vector element and the most significant
        %      bit (MSB) as the rightmost vector element." (from "help getvalue", DAQ toolbox)
        % We want something more intuitive (even if less pratical), so let's inverted it again:
        bits = binvec(end:-1:1);

        %% bits -> n
        v = [128 64 32 16 8 4 2 1];
        n = sum(v(bits));

    case 'InpOut32' % <v3-beta3>
        n = ParallelPort_InpOut32('input');
        t = time;
        
        if ~nargout || nargin >= 3
           bits = dec2bin(n,8) - 48;
        end
end

COSY_PARALLELPORT.dt = t - t0; % For debug purpose

%% Command line use
if ~nargout
    disp(' ')
    disp([num2str(bits) '     (' num2str(n) ')'])
    disp(' ')
    clear n
end