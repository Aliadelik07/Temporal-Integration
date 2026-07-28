% ParallelPort_Inpout32  Parallel port interface, using Inpout32.dll.
%    ParallelPort_Inpout32('INIT', PathToDLL, PortAddressDec)  initializes the port (for both input
%    and output uses). 'PathToDLL' is the path to Inpout32.dll. 'PortAddressDec' is the port's 
%    memory address, in decimal (!) number.
%
%       Example: Opening Eyelab PC's parallel port:
%           ParallelPort_Inpout32('init', whichdir('ParallelPort_Inpout32'), hex2dec('2040'))
%
%    ParallelPort_Inpout32('OUTPUT', byte)  sets port lines values to 'byte'. 'byte'
%    is a number between 0 and 255.
%
%    byte = ParallelPort_Inpout32('INPUT')  returns port's current state.
%
% Andrea Conte, Nov. 2011.