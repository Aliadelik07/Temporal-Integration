function dio = openparallelport_inpout32(PortAddressDec)
% OPENPARALLELPORT_INPOUT32  Open parallel port, using InpOut32.dll. Non-standard ports supported.
%    OPENPARALLELPORT_INPOUT32(PortAddressDec)  opens port of given memory address. 'PortAddressDec' 
%    is a decimal (!) number (use hex2dec to convert from hexadecimal address).
%
%    Example 1: To open a mother board's standard parallel port (LPT1):
%       openparallelport_inpout32(hex2dec('378'));
%
%    Example 2: To open the parallel port of a Dell Precision T1600 (parallel port sold in option):
%       openparallelport_inpout32(hex2dec('2040'));
%
% See also: OPENPARALLELPORT.
%
% Ben,  Nov 2011.

global COSY_PARALLELPORT

dispinfo(mfilename,'info','Opening parallel port... InpOut32.dll is used instead of Matlab''s Daq toobx...')

%% Check OS
if ~ispc
    wrn = 'Operating system other than Windows are not supported.  Calls to the // port will simply be ignored.';
    dispinfo(mfilename,'warning',wrn);
    warning('Cannot open parallel port.')
    return % <---!!!
end

%% Global var
COSY_PARALLELPORT.PortNum = [];
COSY_PARALLELPORT.PortObject = {};
COSY_PARALLELPORT.Direction{1} = 'out'; %<v3-beta11 HACK! FIXME>

%% Input args
% if isopen('cosygraphics'); stopcosy; end  %<v3-beta18, What the fuck is this line !!!?????>
if ~isnumeric(PortAddressDec)
    error('Invalid argument. Input argument must be a decimal (!) number.')
end

%% Set Lib
setcosylib('ParallelPort','InpOut32')

%% Open Port
ParallelPort_InpOut32('init', whichdir('ParallelPort_InpOut32'), PortAddressDec);
ParallelPort_InpOut32('output', 0); % set to 0