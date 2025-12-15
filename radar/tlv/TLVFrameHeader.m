classdef TLVFrameHeader

    properties (Constant, Access = private)
        SIZE_IN_BYTES = 40; % 8 from magic word + 32 of the other stuff;
    end

    properties (SetAccess = immutable)
        % TODO: Parse the version field to extract the major, minor, bugfix, and build numbers.
        Version     % Version, MajorNum * 2^24 + MinorNum * 2^16 + BugfixNum * 2^8 + BuildNum 
        PacketLength % Total packet length including header in Bytes, uint32
        Platform  % platform type, uint32: 0xA1643 or 0xA1443 
        FrameNumber
        TimeCpuCycles  % Time in CPU cycles when the message was created. For XWR16xx/XWR18xx: DSP CPU cycles
        NumDetectedObj % Number of detected objects, uint32
        NumTLVs % Number of TLVs, uint32
        NumCurrentSubFrame % For Advanced Frame config, this is the sub-frame number in the range 0 to (number of subframes - 1). For frame config (not advanced), this is always set to 0. 
    end

    methods
        function obj = TLVFrameHeader(...
                version,...
                packetLength,...
                platform,...
                frameNumber,...
                timeCpuCycles,...
                numDetectedObj,...
                numTLVs,...
                numCurrentSubFrame...
            )
            if nargin > 0
                obj.Version=version;
                obj.PacketLength=packetLength;
                obj.Platform=platform;
                obj.FrameNumber=frameNumber;
                obj.TimeCpuCycles=timeCpuCycles;
                obj.NumDetectedObj=numDetectedObj;
                obj.NumTLVs=numTLVs;
                obj.NumCurrentSubFrame=numCurrentSubFrame;
            end
        end

        function result = getSize(obj)
            result = obj.SIZE_IN_BYTES;
        end
    end
end