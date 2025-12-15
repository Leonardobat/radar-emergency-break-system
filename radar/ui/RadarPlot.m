classdef (Abstract) RadarPlot < handle
    properties (Access = protected)
        figureHandle
    end

    methods (Abstract)
        % Abstract interface: Both classes must implement this, 
        % even if the 'data' type is different.
        updatePlot(obj, data)
    end

    methods
        function onClose(obj, callback)
            arguments (Input)
                obj RadarPlot
                callback
            end
            
            if isvalid(obj.figureHandle)
                addlistener(obj.figureHandle, 'ObjectBeingDestroyed', ...
                    @(~,~) callback());
            end
        end

        function delete(obj)
            % Common cleanup logic
            if ~isempty(obj.figureHandle) && isvalid(obj.figureHandle)
                delete(obj.figureHandle);
            end
        end
    end
end