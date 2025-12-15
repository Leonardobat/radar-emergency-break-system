classdef TLVDetectedObject
    properties (SetAccess = immutable)
        coordinateX
        coordinateY
        coordinateZ
        relativeVelocity
    end

    methods
        function obj = TLVDetectedObject(coordinateX, coordinateY, coordinateZ, relativeVelocity)
            if nargin > 0
                obj.coordinateX = coordinateX;
                obj.coordinateY = coordinateY;
                obj.coordinateZ = coordinateZ;
                obj.relativeVelocity = relativeVelocity;
                return;
            end
        end
    end
end