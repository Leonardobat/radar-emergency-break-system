classdef PlotRangeCFARUI < RadarPlot
    properties (Access = private)
        plotHandle
        numVirtAnt
        numRangeBins
        rangeAxis
    end

    methods
        function obj = PlotRangeCFARUI(radarConfig)
            arguments (Input)
                radarConfig RadarConfig
            end
            arguments (Output)
                obj PlotRangeCFARUI
            end
            obj.numVirtAnt = radarConfig.NumVirtAnt;
            obj.numRangeBins = radarConfig.NumRangeBins;

            N = radarConfig.NumRangeBins;
            plotResolution = radarConfig.RangeIdxToMeters;
            obj.rangeAxis = 0:plotResolution:(N*plotResolution)-plotResolution;
            maxRange = N*plotResolution;

            % Create figure and axes
            obj.figureHandle = figure('Name', 'Range Profile');
            ax = axes(obj.figureHandle);
            hold(ax, 'on');
            obj.plotHandle = gobjects(1,3);
            
            % Handle 1: The Signal Profile (Blue)
            obj.plotHandle(1) = plot(ax, obj.rangeAxis, zeros(1, N), ...
                'b', 'DisplayName', 'Signal');
            
            % Handle 2: The CFAR Threshold (Red)
            obj.plotHandle(2) = plot(ax, obj.rangeAxis, zeros(1, N), ...
                'r--', 'DisplayName', 'CFAR Threshold');
            
            % Handle 3: Detection Markers (Green dots)
            obj.plotHandle(3) = scatter(ax, NaN, NaN, 40, ...
                'g', 'filled', 'DisplayName', 'Detections');
            
            xlim(ax, [0 maxRange])
            xlabel(ax, "Range (meters)");
            ylabel(ax, "Magnitude (dB)");
            title(ax, "Realtime Range & Noise");
            legend(ax, 'Location', 'northeast');
            grid(ax, 'on');
        end

        function updatePlot(obj, data)
            arguments
                obj PlotRangeCFARUI
                data
            end
            if nargin < 2 || isempty(data); return; end
            rangeProfile = data{1};
            thresholdLine = data{2};
            detections = data{3};

            dbProfile = 20 * log10(rangeProfile + eps); 
            dbThreshold = 20 * log10(thresholdLine + eps);

            % Update plot
            obj.plotHandle(1).YData = dbProfile;
            obj.plotHandle(2).YData = dbThreshold;

            % Update Detection Scatter Points
            if any(detections)
                obj.plotHandle(3).XData = obj.rangeAxis(detections);
                obj.plotHandle(3).YData = dbProfile(detections);
            else
                obj.plotHandle(3).XData = NaN;
                obj.plotHandle(3).YData = NaN;
            end

            drawnow('limitrate');
        end
    end
end