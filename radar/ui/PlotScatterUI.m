classdef PlotScatterUI < RadarPlot
    properties (Access = private)
        scatterHandle
        colorbarHandle
    end

    methods
        function obj = PlotScatterUI(radarConfig)
            arguments (Input)
                radarConfig RadarConfig
            end
            arguments (Output)
                obj PlotScatterUI
            end
            
            obj.figureHandle = figure('Name', 'Detected Objects');

            N = radarConfig.NumRangeBins;
            plotResolution = radarConfig.RangeIdxToMeters;
            maxRange = N*plotResolution;
            % Initialize scatter plot with empty data
            % scatter3(X, Y, Z, Size, Color, MarkerType)
            % We set Size to 36 and 'filled' for better visibility
            obj.scatterHandle = scatter3(NaN, NaN, NaN, 36, NaN, 'filled');
            
            % Formatting the plot
            xlabel("X (meters)");
            ylabel("Y (meters)");
            zlabel("Z (meters)");
            title("Detected Objects Scatter (Color = Velocity)");
            xlim([-maxRange/2 maxRange/2]);
            ylim([0 maxRange]);
            zlim([-maxRange/4 maxRange/4]);
            grid on;
            view(3); % Set default 3D view
            axis equal; % Keep aspect ratio consistent
            
            % Setup Colorbar for Velocity
            obj.colorbarHandle = colorbar;
            obj.colorbarHandle.Label.String = 'Relative Velocity (m/s)';
            colormap jet; % 'jet' or 'parula' provides good contrast for velocity

            % Fix the data aspect ratio to prevent auto-scaling
            daspect([1 1 1]);
        end

        function updatePlot(obj, tlvFrame)
            arguments
                obj PlotScatterUI
                tlvFrame
            end

            % If the list is empty, clear the plot and return
            if isempty(tlvFrame) || isempty(tlvFrame.DetectedObjects)
                set(obj.scatterHandle, 'XData', [], 'YData', [], 'ZData', [], 'CData', []);
                return;
            end
            
            detectedObjects = tlvFrame.DetectedObjects;
            % Vectorized extraction of properties from the object array
            % This assumes detectedObjects is an array of TLVDetectedObject
            xData = [detectedObjects.coordinateX];
            yData = [detectedObjects.coordinateY];
            zData = [detectedObjects.coordinateZ];
            vData = [detectedObjects.relativeVelocity];

            % Update the scatter plot properties
            % CData controls the color based on the colormap and velocity values
            set(obj.scatterHandle, ...
                'XData', xData, ...
                'YData', yData, ...
                'ZData', zData, ...
                'CData', vData);

            % Optional: Dynamic scaling of color limits to fit current velocity range
            % This helps visualize contrast if velocity changes dynamically
            %if max(vData) ~= min(vData)
            %    caxis([min(vData) max(vData)]);
            %end

            drawnow('limitrate');
        end
    end
end