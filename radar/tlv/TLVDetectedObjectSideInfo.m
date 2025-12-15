classdef TLVDetectedObjectSideInfo
    properties (SetAccess = immutable)
        Snr
        Noise
    end

    methods
        function obj = TLVDetectedObjectSideInfo(snr, noise)
            obj.Snr = snr;
            obj.Noise = noise;
        end
    end
end