classdef TLVFrame
    properties (SetAccess = immutable)
        Header TLVFrameHeader
        DetectedObjects TLVDetectedObject
        RangeProfile
        RangeDopplerProfile
        NoiseProfile
        Statistics TLVStatistics
        DetectedObjectsSideInfo
    end

    methods
        function obj = TLVFrame(...
            header,...
            rangeProfile,...
            noiseProfile,...
            detectedObjects,...
            rangeDopplerProfile,...
            statistics,...
            detectedObjectsSideInfo...
        )
            if nargin > 0
                obj.Header = header;
                obj.RangeProfile = rangeProfile;
                obj.NoiseProfile = noiseProfile;
                obj.DetectedObjects = detectedObjects;
                obj.RangeDopplerProfile = rangeDopplerProfile;
                obj.Statistics = statistics;
                obj.DetectedObjectsSideInfo = detectedObjectsSideInfo;
                return
            end

            obj.Header = TLVFrameHeader();
            obj.RangeProfile = [];
            obj.NoiseProfile = [];
            obj.DetectedObjects = TLVDetectedObject.empty(1,0);
            obj.RangeDopplerProfile = [];
            obj.Statistics = TLVStatistics();
            obj.DetectedObjectsSideInfo = TLVDetectedObjectSideInfo.empty(1, 0);
        end

        function bool = isValid(obj)
            bool = ~isempty(obj.Header);
        end
    end
end