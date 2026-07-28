function closeparallelport(PortNum)
% CLOSEPARALLELPORT  Close parallel port.
%    CLOSEPARALLELPORT  closes all open parallel ports.
%
%    CLOSEPARALLELPORT(n)  closes LPTn.
%
% Ben, Nov. 2007 v1.0

%      Jan. 2008 Suppress unusefull output arg.
%      Feb. 2009 v2.0 Rewrite.

global COSY_PARALLELPORT

if isempty(COSY_PARALLELPORT)
    return % !!!
end

if ~exist('PortNum','var')   %    CLOSEPARALLELPORT
    iPorts = 1 : length(COSY_PARALLELPORT.PortNum);
else                         %    CLOSEPARALLELPORT(n)
    iPorts = find(COSY_PARALLELPORT.PortNum == PortNum);
end

for i = iPorts
    stop(COSY_PARALLELPORT.PortObject{i})
	delete(COSY_PARALLELPORT.PortObject{i})
    COSY_PARALLELPORT.PortNum(i) = [];
    COSY_PARALLELPORT.PortObject(i) = [];
end

if isempty(COSY_PARALLELPORT.PortNum)
    COSY_PARALLELPORT = [];
end