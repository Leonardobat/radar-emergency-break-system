classdef TLVStatistics
    properties (SetAccess = immutable)
        InterframeProcessTime
        TransmitOutputTime
        InterframeProcessMargin
        InterchirpProcessMargin
        ActiveFrameCpuLoad
        InterframeCpuLoad
    end

    methods
        function obj = TLVStatistics(...
            interframeProcessTime,...
            transmitOutputTime,...
            interframeProcessMargin,...
            interchirpProcessMargin,...
            activeFrameCpuLoad,...
            interframeCpuLoad...
        )
            if nargin > 0
                obj.InterframeProcessTime = interframeProcessTime;
                obj.TransmitOutputTime = transmitOutputTime;
                obj.InterframeProcessMargin = interframeProcessMargin;
                obj.InterchirpProcessMargin = interchirpProcessMargin;
                obj.ActiveFrameCpuLoad = activeFrameCpuLoad;
                obj.InterframeCpuLoad = interframeCpuLoad;
                return;
            end
        end

        function isEmpty = isEmpty(obj)
            isEmpty = isempty(obj.InterframeProcessTime);
        end
    end

end